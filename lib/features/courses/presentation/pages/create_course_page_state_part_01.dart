part of flutterflashcard_main;

extension CreateCoursePageStatePart01 on _CreateCoursePageState {
  Widget _buildCreateCoursePagePage(BuildContext context) {
    const background = Color(0xff05070b);
    const panel = Color(0xff0b0d12);
    const border = Color(0xff242a36);
    const text = Color(0xfff8fbff);
    const muted = Color(0xffa8b6d6);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Color(0xff090b0f),
                border: Border(
                  bottom: BorderSide(color: border),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text('Trang chủ'),
                      style: TextButton.styleFrom(
                        foregroundColor: text,
                        textStyle: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Text(
                    'Tạo học phần',
                    style: TextStyle(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final compact = viewport.maxWidth < 720;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 24,
                      20,
                      compact ? 14 : 24,
                      32,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (compact) ...[
                              this._buildCourseTitleField(),
                              SizedBox(height: 12),
                              this._buildCreateCourseActions(compact: true),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: this._buildCourseTitleField()),
                                  SizedBox(width: 12),
                                  this._buildCreateCourseActions(compact: false),
                                ],
                              ),
                            SizedBox(height: 22),
                            Text(
                              'NHẬP DỮ LIỆU (COPY PASTE TỪ WORD/EXCEL/GOOGLE DOCS...)',
                              style: TextStyle(
                                color: text,
                                fontSize: 13,
                                letterSpacing: 0.35,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 9),
                            Container(
                              height: compact ? 310 : 360,
                              decoration: BoxDecoration(
                                color: panel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: TextField(
                                controller: dataController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 15,
                                  height: 1.6,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  hintText:
                                      'Từ 1\tĐịnh nghĩa 1\nTừ 2\tĐịnh nghĩa 2\nTừ 3\tĐịnh nghĩa 3',
                                  hintStyle: TextStyle(
                                    color: muted.withOpacity(0.66),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, options) {
                                final columns = options.maxWidth >= 980
                                    ? 3
                                    : options.maxWidth >= 620
                                        ? 2
                                        : 1;
                                final cardWidth =
                                    (options.maxWidth - ((columns - 1) * 14)) /
                                        columns;
                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: this._buildTermSeparatorOption(),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: this._buildCardSeparatorOption(),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: this._buildLanguageOption(),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: this._buildTopicOption(),
                                    ),
                                  ],
                                );
                              },
                            ),
                            SizedBox(height: 22),
                            Row(
                              children: [
                                Text(
                                  'XEM TRƯỚC',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '${previewItems.length} thẻ',
                                  style: TextStyle(
                                    color: muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 9),
                            this.buildPreviewBox(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseTitleField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Color(0xff0b0d12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xff242a36)),
      ),
      child: TextField(
        controller: titleController,
        maxLength: 80,
        style: TextStyle(
          color: Color(0xfff8fbff),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintText: 'Tên học phần (ví dụ: TOCFL A2 - Week 1)',
          hintStyle: TextStyle(
            color: Color(0xff6f7d99),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateCourseActions({required bool compact}) {
    final buttons = <Widget>[
      this._buildCreateCourseAction(
        label: 'Nhập bảng',
        icon: Icons.grid_on_rounded,
        onTap: this.openManualTableDialog,
      ),
      this._buildCreateCourseAction(
        label: 'Import TXT',
        icon: Icons.file_open_rounded,
        onTap: this.importTxtFiles,
      ),
      this._buildCreateCourseAction(
        label: 'Xem trước',
        icon: Icons.visibility_outlined,
        onTap: this.updatePreview,
      ),
      this._buildCreateCourseAction(
        label: 'Lưu',
        icon: Icons.save_outlined,
        primary: true,
        onTap: this.saveCourse,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: buttons,
    );
  }

  Widget _buildCreateCourseAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              primary ? Color(0xff4268ff) : Color(0xff0b0d12),
          foregroundColor: Color(0xfff8fbff),
          side: primary ? BorderSide.none : BorderSide(color: Color(0xff242a36)),
          padding: EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildCreateOptionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: 132),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xff0b0d12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xff242a36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Color(0xfff8fbff),
              fontSize: 12,
              letterSpacing: 0.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTermSeparatorOption() {
    return this._buildCreateOptionCard(
      title: 'GIỮA THUẬT NGỮ VÀ ĐỊNH NGHĨA',
      child: Column(
        children: [
          this._buildSeparatorChoice(
            label: 'Tab',
            selected: termSeparatorType == 'tab',
            onTap: () {
              setState(() => termSeparatorType = 'tab');
              this.saveCreateCourseSettings();
            },
          ),
          this._buildSeparatorChoice(
            label: 'Gạch dưới _',
            selected: termSeparatorType == 'underscore',
            onTap: () {
              setState(() => termSeparatorType = 'underscore');
              this.saveCreateCourseSettings();
            },
          ),
          this._buildSeparatorChoice(
            label: 'Tùy chỉnh',
            selected: termSeparatorType == 'custom',
            onTap: () {
              setState(() => termSeparatorType = 'custom');
              this.saveCreateCourseSettings();
            },
            controller: customTermSepController,
          ),
        ],
      ),
    );
  }

  Widget _buildCardSeparatorOption() {
    return this._buildCreateOptionCard(
      title: 'GIỮA CÁC THẺ',
      child: Column(
        children: [
          this._buildSeparatorChoice(
            label: 'Dòng mới',
            selected: cardSeparatorType == 'newline',
            onTap: () {
              setState(() => cardSeparatorType = 'newline');
              this.saveCreateCourseSettings();
            },
          ),
          this._buildSeparatorChoice(
            label: 'Chấm phẩy ;',
            selected: cardSeparatorType == 'semicolon',
            onTap: () {
              setState(() => cardSeparatorType = 'semicolon');
              this.saveCreateCourseSettings();
            },
          ),
          this._buildSeparatorChoice(
            label: 'Tùy chỉnh',
            selected: cardSeparatorType == 'custom',
            onTap: () {
              setState(() => cardSeparatorType = 'custom');
              this.saveCreateCourseSettings();
            },
            controller: customCardSepController,
          ),
        ],
      ),
    );
  }

  Widget _buildSeparatorChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    TextEditingController? controller,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? Color(0xff5a80e9) : Color(0xff6f7d99),
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Color(0xffeaf1ff),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (controller != null)
              SizedBox(
                width: 70,
                height: 34,
                child: TextField(
                  controller: controller,
                  enabled: selected,
                  onTap: onTap,
                  onChanged: (_) => this.saveCreateCourseSettings(),
                  style: TextStyle(
                    color: Color(0xfff8fbff),
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xff080a0f),
                    contentPadding: EdgeInsets.symmetric(horizontal: 9),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xff303849)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xff1b202a)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xff5a80e9)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption() {
    const languages = <String>[
      'Tiếng Trung Phồn thể (Traditional Chinese)',
      'Tiếng Trung Giản thể (Simplified Chinese)',
      'Tiếng Anh (English)',
      'Tiếng Đức (German)',
      'Tiếng Nhật (Japanese)',
      'Tiếng Hàn (Korean)',
      'Tiếng Việt (Vietnamese)',
    ];
    return this._buildCreateOptionCard(
      title: 'NGÔN NGỮ HỌC PHẦN',
      child: this._buildCreateDropdown<String>(
        value: selectedLanguage,
        items: languages,
        labelOf: (value) => value,
        onChanged: (value) {
          if (value == null) return;
          setState(() => selectedLanguage = value);
          this.saveCreateCourseSettings();
        },
      ),
    );
  }

  Widget _buildTopicOption() {
    return this._buildCreateOptionCard(
      title: 'CHỦ ĐỀ HỌC PHẦN',
      child: availableTopics.isEmpty
          ? Text(
              'Chưa có chủ đề. Khi lưu sẽ tự tạo theo tên học phần.',
              style: TextStyle(
                color: Color(0xffa8b6d6),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          : this._buildCreateDropdown<int>(
              value: selectedTopicId,
              hint: 'Chọn chủ đề...',
              items: availableTopics.map((topic) => topic.id).toList(),
              labelOf: (id) => availableTopics
                  .firstWhere((topic) => topic.id == id)
                  .name,
              onChanged: (value) => setState(() => selectedTopicId = value),
            ),
    );
  }

  Widget _buildCreateDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T value) labelOf,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Color(0xff080a0f),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xff303849)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint == null
              ? null
              : Text(hint, style: TextStyle(color: Color(0xff6f7d99))),
          isExpanded: true,
          dropdownColor: Color(0xff121828),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xffa8b6d6),
          ),
          style: TextStyle(
            color: Color(0xfff8fbff),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
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
      HAVING COUNT(DISTINCT c.id) > 0
        OR lower(trim(t.name)) NOT IN ('chủ đề khác', 'toeic', 'tiếng trung b1')
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
        if (topicId != null) {
          final activeTopic = await txn.query(
            'topics',
            columns: ['id'],
            where: 'id = ? AND deletedAt IS NULL',
            whereArgs: [topicId],
            limit: 1,
          );
          if (activeTopic.isEmpty) topicId = null;
        }
        if (topicId == null) {
          topicId = await AppDatabase.instance.ensureActiveTopicByName(
            txn,
            name: title,
            now: now,
          );
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

      if (SupabaseConfig.isLoggedIn) {
        unawaited(SupabaseSyncService.instance.syncPendingChanges());
      }

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
