part of flutterflashcard_main;

extension CreateCoursePageStatePart01 on _CreateCoursePageState {
  Widget _buildCreateCoursePagePage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            this.buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SectionTitle("NHẬP DỮ LIỆU"),
                        Spacer(),
                        _ImportActionChip(
                          icon: Icons.grid_on_rounded,
                          label: "Tạo thủ công",
                          color: AppColors.yellow,
                          onTap: this.openManualTableDialog,
                        ),
                        SizedBox(width: 8),
                        _ImportActionChip(
                          icon: Icons.file_open_rounded,
                          label: "Import TXT",
                          color: AppColors.green,
                          onTap: this.importTxtFiles,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    this.buildDataInput(),

                    if (showPreview) ...[
                      SizedBox(height: 16),
                      this.buildPreviewTitle(),
                      SizedBox(height: 8),
                      this.buildPreviewBox(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }





  Future<void> loadCreateCourseSettings() async {
    final savedTermSep = await AppSettingsStore.getString(
      'create.termSeparatorType',
    );
    final savedCardSep = await AppSettingsStore.getString(
      'create.cardSeparatorType',
    );
    final savedCustomTermSep = await AppSettingsStore.getString(
      'create.customTermSeparator',
    );
    final savedCustomCardSep = await AppSettingsStore.getString(
      'create.customCardSeparator',
    );
    final savedLanguage = await AppSettingsStore.getString(
      'create.selectedLanguage',
    );

    if (!mounted) return;

    setState(() {
      if (savedTermSep != null && savedTermSep.isNotEmpty) {
        termSeparatorType = savedTermSep == 'comma'
            ? 'underscore'
            : savedTermSep;
      }
      if (savedCardSep != null && savedCardSep.isNotEmpty) {
        cardSeparatorType = savedCardSep;
      }
      if (savedCustomTermSep != null) {
        customTermSepController.text = savedCustomTermSep;
      }
      if (savedCustomCardSep != null) {
        customCardSepController.text = savedCustomCardSep;
      }
      if (savedLanguage != null && savedLanguage.isNotEmpty) {
        selectedLanguage = this.normalizeLanguageName(savedLanguage);
      }
    });

    await this.loadAvailableTopics();
  }


  Future<void> loadAvailableTopics() async {
    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        t.id,
        t.name,
        COUNT(DISTINCT c.id) AS courseCount,
        COUNT(cards.id) AS cardCount
      FROM topics t
      LEFT JOIN courses c
        ON c.topicId = t.id
        AND c.deletedAt IS NULL
      LEFT JOIN cards
        ON cards.courseId = c.id
        AND cards.deletedAt IS NULL
        AND cards.isHidden = 0
      WHERE t.deletedAt IS NULL
      GROUP BY t.id, t.name
      ORDER BY lower(t.name) ASC
    ''');

    if (!mounted) return;

    setState(() {
      availableTopics = rows.map((e) => CourseTopicItem.fromMap(e)).toList();
      if (selectedTopicId != null &&
          !availableTopics.any((topic) => topic.id == selectedTopicId)) {
        selectedTopicId = null;
      }
    });
  }


  Future<void> saveCreateCourseSettings() async {
    await Future.wait([
      AppSettingsStore.setString('create.termSeparatorType', termSeparatorType),
      AppSettingsStore.setString('create.cardSeparatorType', cardSeparatorType),
      AppSettingsStore.setString(
        'create.customTermSeparator',
        customTermSepController.text,
      ),
      AppSettingsStore.setString(
        'create.customCardSeparator',
        customCardSepController.text,
      ),
      AppSettingsStore.setString('create.selectedLanguage', selectedLanguage),
    ]);
  }


  String normalizeLanguageName(String value) {
    if (value.contains("Giản thể") || value.contains("Giáº£n thá»ƒ")) {
      return "Tiếng Trung Giản thể (Simplified Chinese)";
    }
    if (value.contains("Anh")) return "Tiếng Anh (English)";
    if (value.contains("Đức") || value.contains("Äá»©c")) {
      return "Tiếng Đức (German)";
    }
    if (value.contains("Nhật") || value.contains("Nháº­t")) {
      return "Tiếng Nhật (Japanese)";
    }
    if (value.contains("Hàn") || value.contains("HÃ n")) {
      return "Tiếng Hàn (Korean)";
    }
    if (value.contains("Việt") || value.contains("Viá»‡t")) {
      return "Tiếng Việt (Vietnamese)";
    }
    return "Tiếng Trung Phồn thể (Traditional Chinese)";
  }


  String getTermSeparator() {
    if (termSeparatorType == "tab") return "\t";
    if (termSeparatorType == "underscore") return "_";
    return customTermSepController.text;
  }


  String getCardSeparator() {
    if (cardSeparatorType == "newline") return "\n";
    if (cardSeparatorType == "semicolon") return ";";
    return customCardSepController.text;
  }


  String getLanguageCode() {
    if (selectedLanguage.contains("Giản thể")) return "zh-CN";
    if (selectedLanguage.contains("Anh")) return "en-US";
    if (selectedLanguage.contains("Đức")) return "de-DE";
    if (selectedLanguage.contains("Nhật")) return "ja-JP";
    if (selectedLanguage.contains("Hàn")) return "ko-KR";
    if (selectedLanguage.contains("Việt")) return "vi-VN";

    return "zh-TW";
  }


  List<FlashCardItem> parseCards() {
    final text = dataController.text.trim();
    final termSep = this.getTermSeparator();
    final cardSep = this.getCardSeparator();

    if (text.isEmpty || termSep.isEmpty || cardSep.isEmpty) {
      return [];
    }

    final rawCards = text
        .split(cardSep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final List<FlashCardItem> result = [];

    for (final raw in rawCards) {
      final parts = raw.split(termSep).map((e) => e.trim()).toList();

      if (parts.length >= 3) {
        result.add(
          FlashCardItem(
            term: parts[0].isEmpty ? "Chưa có thuật ngữ" : parts[0],
            pronunciation: parts[1],
            definition: parts.sublist(2).join(" "),
          ),
        );
        continue;
      }

      if (parts.length == 2) {
        final parsed = this.parseDefinitionAndPronunciation(parts[1]);

        result.add(
          FlashCardItem(
            term: parts[0].isEmpty ? "Chưa có thuật ngữ" : parts[0],
            definition: parsed.definition,
            pronunciation: parsed.pronunciation,
          ),
        );
        continue;
      }

      result.add(
        FlashCardItem(
          term: raw,
          definition: "Chưa có định nghĩa",
          pronunciation: "",
        ),
      );
    }

    return result;
  }


  ParsedDefinition parseDefinitionAndPronunciation(String raw) {
    final text = raw.trim();

    // Nhận phiên âm đặt trong ngoặc cuối dòng.
    // Fix IPA có ngoặc con như: [ˈɑːftə(r)]
    final regex = RegExp(r'^(.*?)\s*\((.*)\)\s*$');
    final match = regex.firstMatch(text);

    if (match == null) {
      return ParsedDefinition(definition: text, pronunciation: '');
    }

    final definition = match.group(1)?.trim() ?? '';
    final pronunciation = match.group(2)?.trim() ?? '';

    if (definition.isEmpty || pronunciation.isEmpty) {
      return ParsedDefinition(definition: text, pronunciation: '');
    }

    return ParsedDefinition(
      definition: definition,
      pronunciation: pronunciation,
    );
  }


  void updatePreview() {
    setState(() {
      previewItems = this.parseCards();
      showPreview = true;
    });
  }


  Future<void> saveCourse() async {
    final title = titleController.text.trim();
    final rawText = dataController.text.trim();

    // 1. Validate tên học phần
    if (title.isEmpty) {
      this.showMessage("Vui lòng nhập tên học phần");
      return;
    }

    if (title.length < 2) {
      this.showMessage("Tên học phần phải có ít nhất 2 ký tự");
      return;
    }

    if (title.length > 80) {
      this.showMessage("Tên học phần không được quá 80 ký tự");
      return;
    }

    // 2. Validate dữ liệu nhập
    if (rawText.isEmpty) {
      this.showMessage("Vui lòng nhập dữ liệu thẻ");
      return;
    }

    // 3. Validate dấu phân cách
    if (this.getTermSeparator().isEmpty) {
      this.showMessage("Dấu phân cách thuật ngữ và định nghĩa không được rỗng");
      return;
    }

    if (this.getCardSeparator().isEmpty) {
      this.showMessage("Dấu phân cách giữa các thẻ không được rỗng");
      return;
    }

    final items = this.parseCards();

    // 4. Validate danh sách thẻ
    if (items.isEmpty) {
      this.showMessage("Chưa có thẻ nào để lưu");
      return;
    }

    // 5. Không cho lưu thẻ bị thiếu thuật ngữ / định nghĩa
    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      if (item.term.trim().isEmpty || item.term == "Chưa có thuật ngữ") {
        this.showMessage("Thẻ số ${i + 1} bị thiếu thuật ngữ");
        return;
      }

      if (item.definition.trim().isEmpty ||
          item.definition == "Chưa có định nghĩa") {
        this.showMessage("Thẻ số ${i + 1} bị thiếu định nghĩa");
        return;
      }
    }

    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final hasExistingTopics = availableTopics.isNotEmpty;

    if (hasExistingTopics && selectedTopicId == null) {
      this.showMessage("Vui lòng chọn chủ đề");
      return;
    }

    final normalizedTitle = title.trim().toLowerCase();

    // 7. Check trùng tên học phần
    final existed = await db.query(
      'courses',
      columns: ['id'],
      where: 'lower(trim(title)) = ? AND deletedAt IS NULL',
      whereArgs: [normalizedTitle],
      limit: 1,
    );

    if (existed.isNotEmpty) {
      this.showMessage("Tên học phần đã tồn tại, vui lòng nhập tên khác");
      return;
    }

    int? savedCourseId;

    try {
      await db.transaction((txn) async {
        var topicId = selectedTopicId;
        if (topicId == null) {
          topicId = await txn.insert('topics', {
            'name': title,
            'createdAt': now,
            'updatedAt': now,
          });
        }

        final courseId = await txn.insert('courses', {
          'topicId': topicId,
          'title': title,
          'description': '',
          'languageName': selectedLanguage,
          'languageCode': this.getLanguageCode(),
          'cardCount': items.length,
          'isFavorite': 0,
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
        });

        savedCourseId = courseId;

        for (int i = 0; i < items.length; i++) {
          final item = items[i];

          await txn.insert('cards', {
            'courseId': courseId,
            'term': item.term.trim(),
            'definition': item.definition.trim(),
            'pronunciation': item.pronunciation.trim(),
            'rawText':
                '${item.term}\t${item.definition} (${item.pronunciation})',
            'inputFormat': 'auto',
            'position': i,
            'isFavorite': 0,
            'isHidden': 0,
            'createdAt': now,
            'updatedAt': now,
          });
        }

        debugPrint("ĐÃ LƯU DB: courseId=$courseId");
        debugPrint("TỔNG THẺ VỪA LƯU: ${items.length}");
      });

      final courseId = savedCourseId;
      if (courseId != null) {
        if (mounted) {
          this.showMessage("Đang tạo âm thanh cho ${items.length} thẻ...");
        }

        await TtsAudioCache.instance.prepareCourseAudio(
          items: items,
          languageCode: this.getLanguageCode(),
          courseId: courseId,
        );
      }

      if (!mounted) return;

      this.showMessage("Đã lưu học phần: $title (${items.length} thẻ)");

      // Lưu xong tự quay về Home
      Navigator.pop(context, true);
    } catch (e) {
      this.showMessage("Lưu thất bại, vui lòng thử lại");
      debugPrint("SAVE COURSE ERROR: $e");
    }
  }


  void showMessage(String text) {
    showAppToast(context, text);
  }

}
