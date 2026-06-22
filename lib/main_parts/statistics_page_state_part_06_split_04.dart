part of flutterflashcard_main;

extension StatisticsPageStatePart06Split04 on _StatisticsPageState {
  Future<String> _importSrsJsonText(String raw) async {
    var text = raw.trim();
    if (text.isEmpty) {
      throw FormatException('JSON đang trống');
    }

    final startIdx = text.indexOf('{');
    final endIdx = text.lastIndexOf('}');
    if (startIdx >= 0 && endIdx > startIdx) {
      text = text.substring(startIdx, endIdx + 1);
    }

    final decoded = jsonDecode(text);
    final items = this._extractSrsImportItems(decoded);
    if (items.isEmpty) {
      throw FormatException('Không tìm thấy items SRS');
    }

    final db = await AppDatabase.instance.database;
    var imported = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      for (final item in items) {
        final cardId = await this._findSrsImportCardId(txn, item);
        if (cardId == null) {
          skipped++;
          continue;
        }

        final now = DateTime.now();
        final level = _dbInt(item['level']).clamp(0, 8).toInt();
        final interval = math.max(0, _dbInt(item['intervalDays']));
        final nextReviewAt =
            DateTime.tryParse(item['nextReviewAt']?.toString() ?? '') ??
            DateTime(now.year, now.month, now.day).add(
              getDuration(days: interval),
            );

        await this._upsertSrsStateOn(
          txn,
          cardId: cardId,
          level: level,
          easeFactor: _dbDouble(item['easeFactor'], 2.5),
          intervalDays: interval,
          repetitionCount: _dbInt(item['repetitionCount']),
          correctCount: _dbInt(item['correctCount']),
          wrongCount: _dbInt(item['wrongCount']),
          lastReviewedAt: item['lastReviewedAt']?.toString(),
          nextReviewAt: nextReviewAt,
        );
        imported++;
      }

      await txn.insert('import_exports', {
        'type': 'import',
        'fileName': 'srs_json_clipboard',
        'filePath': null,
        'format': 'json',
        'courseId': null,
        'status': skipped == 0 ? 'success' : 'partial',
        'message': 'Import SRS JSON: $imported ok, $skipped bỏ qua',
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    return 'Đã import $imported SRS, bỏ qua $skipped thẻ không khớp';
  }

}
