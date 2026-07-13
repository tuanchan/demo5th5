part of flutterflashcard_main;

class BuiltInVocabularyImporter {
  BuiltInVocabularyImporter._();

  static const List<String> _assetRoots = ['assets/TOEIC/', 'assets/TOCFL/'];

  static Future<void> removeBundledDefaults() async {
    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      // Bundled vocabulary is reference data shipped with the app, not user
      // data. Delete it physically so it cannot create hundreds of sync
      // tombstones. The sync service independently removes old cloud copies.
      await txn.rawDelete(
        '''
        DELETE FROM cards
        WHERE courseId IN (
            SELECT id FROM courses
            WHERE description LIKE ? OR description LIKE ?
          )
        ''',
        ['%assets/TOEIC/%', '%assets/TOCFL/%'],
      );
      await txn.rawDelete(
        '''
        DELETE FROM courses
        WHERE description LIKE ? OR description LIKE ?
        ''',
        ['%assets/TOEIC/%', '%assets/TOCFL/%'],
      );
      await txn.rawDelete(
        '''
        DELETE FROM topics
        WHERE lower(trim(name)) IN (?, ?, ?)
          AND NOT EXISTS (
            SELECT 1
            FROM courses c
            WHERE c.topicId = topics.id
          )
        ''',
        ['chủ đề khác', 'toeic', 'tiếng trung b1'],
      );
      await txn.delete(
        'import_exports',
        where: 'filePath LIKE ? OR filePath LIKE ?',
        whereArgs: ['assets/TOEIC/%', 'assets/TOCFL/%'],
      );
    });
  }

  static Future<BuiltInVocabularyImportResult> importMissing() async {
    final assetPaths = await _loadVocabularyAssetPaths();
    if (assetPaths.isEmpty) {
      return BuiltInVocabularyImportResult(
        importedCourses: 0,
        importedCards: 0,
      );
    }

    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    var importedCourses = 0;
    var importedCards = 0;

    await db.transaction((txn) async {
      for (final assetPath in assetPaths) {
        final title = _titleFromAssetPath(assetPath);
        if (title.trim().isEmpty) continue;

        final existed = await txn.query(
          'courses',
          columns: ['id'],
          where: 'lower(trim(title)) = ? AND deletedAt IS NULL',
          whereArgs: [title.trim().toLowerCase()],
          limit: 1,
        );

        if (existed.isNotEmpty) continue;

        final text = await rootBundle.loadString(assetPath, cache: false);
        final items = _parseVocabularyText(assetPath: assetPath, text: text);
        if (items.isEmpty) continue;

        final languageCode = _languageCodeForAsset(assetPath);
        final createdAt = now
            .add(Duration(milliseconds: importedCourses))
            .toIso8601String();
        final topicId = await _ensureTopicForAsset(
          txn: txn,
          assetPath: assetPath,
          nowIso: createdAt,
        );
        final courseId = await txn.insert('courses', {
          'topicId': topicId,
          'title': title,
          'description': 'Built-in vocabulary from $assetPath',
          'languageName': _languageNameForAsset(languageCode),
          'languageCode': languageCode,
          'cardCount': items.length,
          'isFavorite': 0,
          'isArchived': 0,
          'createdAt': createdAt,
          'updatedAt': createdAt,
        });

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final pronunciation = item.pronunciation.trim();

          await txn.insert('cards', {
            'courseId': courseId,
            'term': item.term.trim(),
            'definition': item.definition.trim(),
            'pronunciation': pronunciation,
            'rawText': pronunciation.isEmpty
                ? '${item.term}\t${item.definition}'
                : '${item.term}\t${item.definition} ($pronunciation)',
            'inputFormat': 'asset_txt',
            'position': i,
            'isFavorite': 0,
            'isHidden': 0,
            'createdAt': createdAt,
            'updatedAt': createdAt,
          });
        }

        await txn.insert('import_exports', {
          'type': 'import',
          'fileName': '${_fileNameFromAssetPath(assetPath)}',
          'filePath': assetPath,
          'format': 'asset_txt',
          'courseId': courseId,
          'status': 'success',
          'message': 'Imported built-in vocabulary asset',
          'createdAt': createdAt,
        });

        importedCourses++;
        importedCards += items.length;
      }
    });

    return BuiltInVocabularyImportResult(
      importedCourses: importedCourses,
      importedCards: importedCards,
    );
  }

  static Future<List<String>> _loadVocabularyAssetPaths() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      final paths = assets.where(_isVocabularyTxtAsset).toList();
      paths.sort(_compareVocabularyAssetPaths);
      return paths;
    } catch (e) {
      debugPrint('LOAD ASSET MANIFEST API ERROR: $e');
    }

    try {
      final manifestText = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
      final paths = manifest.keys.where(_isVocabularyTxtAsset).toList();
      paths.sort(_compareVocabularyAssetPaths);
      return paths;
    } catch (e) {
      debugPrint('LOAD ASSET MANIFEST JSON ERROR: $e');
      return [];
    }
  }

  static bool _isVocabularyTxtAsset(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.toLowerCase().endsWith('.txt') &&
        _assetRoots.any((root) => normalized.startsWith(root));
  }

  static int _compareVocabularyAssetPaths(String a, String b) {
    final folderCompare = _assetFolder(a).compareTo(_assetFolder(b));
    if (folderCompare != 0) return folderCompare;

    final dayCompare = _dayNumber(a).compareTo(_dayNumber(b));
    if (dayCompare != 0) return dayCompare;

    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static String _assetFolder(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.contains('/TOCFL/')) return 'TOCFL';
    if (normalized.contains('/TOEIC/')) return 'TOEIC';
    return '';
  }

  static int _dayNumber(String path) {
    final match = RegExp(r'day\s*(\d+)', caseSensitive: false).firstMatch(path);
    return match == null ? 9999 : int.tryParse(match.group(1) ?? '') ?? 9999;
  }

  static String _fileNameFromAssetPath(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  static String _titleFromAssetPath(String assetPath) {
    return _fileNameFromAssetPath(
      assetPath,
    ).replaceFirst(RegExp(r'\.txt$', caseSensitive: false), '').trim();
  }

  static String _languageCodeForAsset(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/');
    if (normalized.contains('/TOEIC/')) return 'en-US';
    return 'zh-TW';
  }

  static String _languageNameForAsset(String languageCode) {
    if (languageCode == 'en-US') return 'Tiếng Anh (English)';
    return 'Tiếng Trung Phồn thể (Traditional Chinese)';
  }

  static Future<int> _ensureTopicForAsset({
    required Transaction txn,
    required String assetPath,
    required String nowIso,
  }) async {
    final topicName = _assetFolder(assetPath) == 'TOEIC'
        ? 'TOEIC'
        : 'Tiếng Trung B1';

    return AppDatabase.instance.ensureActiveTopicByName(
      txn,
      name: topicName,
      now: nowIso,
    );
  }

  static List<FlashCardItem> _parseVocabularyText({
    required String assetPath,
    required String text,
  }) {
    final items = <FlashCardItem>[];

    for (final rawLine in LineSplitter.split(text)) {
      final item = _parseVocabularyLine(assetPath: assetPath, rawLine: rawLine);
      if (item != null) items.add(item);
    }

    return items;
  }

  static FlashCardItem? _parseVocabularyLine({
    required String assetPath,
    required String rawLine,
  }) {
    final line = rawLine.replaceFirst('\ufeff', '').trim();
    if (line.isEmpty) return null;

    final separator = assetPath.replaceAll('\\', '/').contains('/TOCFL/')
        ? ':'
        : '_';
    final separatorIndex = line.indexOf(separator);
    if (separatorIndex <= 0 || separatorIndex >= line.length - 1) return null;

    final term = line.substring(0, separatorIndex).trim();
    final rawDefinition = line.substring(separatorIndex + 1).trim();
    final parsed = parseDefinitionAndPronunciationText(rawDefinition);

    if (term.isEmpty || parsed.definition.trim().isEmpty) return null;

    return FlashCardItem(
      term: term,
      definition: parsed.definition,
      pronunciation: parsed.pronunciation,
    );
  }
}
