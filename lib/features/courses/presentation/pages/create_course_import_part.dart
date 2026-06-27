part of flutterflashcard_main;

// ─── Extension: Import Features ───────────────────────────────────────────────
// 1. Tạo thủ công (Manual table entry)
// 2. Import TXT files (multiple file selection)
// ──────────────────────────────────────────────────────────────────────────────

extension CreateCourseImportPart on _CreateCoursePageState {

  // ─── 1. Manual Table Entry Dialog ──────────────────────────────────────────

  Future<void> openManualTableDialog() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return _ManualTableDialog(
          onSave: (List<FlashCardItem> items) async {
            if (items.isEmpty) {
              this.showMessage("Chưa có thẻ nào để thêm");
              return;
            }

            // Append to current data controller using the current separator settings
            final termSep = this.getTermSeparator();
            final cardSep = this.getCardSeparator();

            final lines = items.map((item) {
              if (item.pronunciation.trim().isNotEmpty) {
                return '${item.term}${termSep}${item.definition} (${item.pronunciation})';
              }
              return '${item.term}${termSep}${item.definition}';
            }).toList();

            final existing = dataController.text.trim();
            if (existing.isNotEmpty) {
              dataController.text = '$existing$cardSep${lines.join(cardSep)}';
            } else {
              dataController.text = lines.join(cardSep);
            }

            if (showPreview) {
              this.updatePreview();
            } else {
              setState(() {});
            }

            this.showMessage("Đã thêm ${items.length} thẻ từ bảng");
          },
        );
      },
    );
  }


  // ─── 2. Import TXT Files ──────────────────────────────────────────────────

  Future<void> importTxtFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      int totalImported = 0;
      int totalSkipped = 0;

      for (final file in result.files) {
        final fileName = file.name;
        final courseName = fileName.endsWith('.txt')
            ? fileName.substring(0, fileName.length - 4)
            : fileName;

        if (courseName.trim().isEmpty) {
          totalSkipped++;
          continue;
        }

        String? content;
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            content = await ioFile.readAsString();
          }
        }

        if (content == null || content.trim().isEmpty) {
          totalSkipped++;
          continue;
        }

        // Parse cards using the same format settings
        final items = _parseTxtContent(content);

        if (items.isEmpty) {
          totalSkipped++;
          continue;
        }

        // Check duplicate course name
        final db = await AppDatabase.instance.database;
        final existed = await db.query(
          'courses',
          columns: ['id'],
          where: 'lower(trim(title)) = ? AND deletedAt IS NULL',
          whereArgs: [courseName.trim().toLowerCase()],
          limit: 1,
        );

        if (existed.isNotEmpty) {
          totalSkipped++;
          this.showMessage("\"$courseName\" đã tồn tại, bỏ qua");
          continue;
        }

        // Save course to DB
        await _saveTxtCourse(courseName: courseName, items: items);
        totalImported++;
      }

      if (!mounted) return;

      if (totalImported > 0) {
        this.showMessage(
          "Đã import $totalImported file${totalSkipped > 0 ? ' (bỏ qua $totalSkipped)' : ''}",
        );
        // Go back to home and refresh
        Navigator.pop(context, true);
      } else if (totalSkipped > 0) {
        this.showMessage("Không có file nào import được ($totalSkipped bỏ qua)");
      }
    } catch (e) {
      this.showMessage("Import thất bại: $e");
      debugPrint("IMPORT TXT ERROR: $e");
    }
  }


  List<FlashCardItem> _parseTxtContent(String content) {
    final text = content.trim();
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


  Future<void> _saveTxtCourse({
    required String courseName,
    required List<FlashCardItem> items,
  }) async {
    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Create or find topic
      var topicId = selectedTopicId;
      if (topicId == null) {
        topicId = await txn.insert('topics', {
          'name': courseName,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      final courseId = await txn.insert('courses', {
        'topicId': topicId,
        'title': courseName,
        'description': '',
        'languageName': selectedLanguage,
        'languageCode': this.getLanguageCode(),
        'cardCount': items.length,
        'isFavorite': 0,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });

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

      debugPrint("IMPORT TXT: saved courseId=$courseId title=$courseName cards=${items.length}");

      // Prepare TTS audio
      await TtsAudioCache.instance.prepareCourseAudio(
        items: items,
        languageCode: this.getLanguageCode(),
        courseId: courseId,
      );
    });
  }
}


// ─── Manual Table Dialog Widget ──────────────────────────────────────────────

class _ManualTableDialog extends StatefulWidget {
  final Future<void> Function(List<FlashCardItem> items) onSave;

  _ManualTableDialog({required this.onSave});

  @override
  State<_ManualTableDialog> createState() => _ManualTableDialogState();
}


class _ManualTableDialogState extends State<_ManualTableDialog> {
  final List<_ManualTableRow> _rows = [];
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Start with 4 empty rows
    for (int i = 0; i < 4; i++) {
      _rows.add(_ManualTableRow());
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_ManualTableRow());
    });
    // Scroll to bottom after adding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _save() async {
    final items = <FlashCardItem>[];

    for (final row in _rows) {
      final term = row.termController.text.trim();
      final definition = row.definitionController.text.trim();
      final pronunciation = row.pronunciationController.text.trim();

      if (term.isEmpty && definition.isEmpty) continue;

      items.add(FlashCardItem(
        term: term.isEmpty ? "Chưa có thuật ngữ" : term,
        definition: definition.isEmpty ? "Chưa có định nghĩa" : definition,
        pronunciation: pronunciation,
      ));
    }

    setState(() => _isSaving = true);
    await widget.onSave(items);
    setState(() => _isSaving = false);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 7),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0x22000000),
              offset: Offset(0, 20),
              blurRadius: 26,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Flexible(child: _buildTable()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Tạo thủ công",
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          _AddRowButton(onTap: _addRow),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(Icons.close, color: AppColors.onIconButton, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.activeIsDark ? AppColors.panel2 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                _tableHeaderCell("", width: 48),
                _tableHeaderCell("Từ mới", flex: 3),
                _tableHeaderCell("Định nghĩa", flex: 5),
                _tableHeaderCell("Phiên âm", flex: 3),
                SizedBox(width: 40),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.border,
          ),
          // Table rows
          Flexible(
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _rows.length,
              separatorBuilder: (_, __) => Container(
                height: 1,
                color: AppColors.border.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                return _buildTableRow(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String label, {int flex = 1, double? width}) {
    final child = Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }

  Widget _buildTableRow(int index) {
    final row = _rows[index];

    return Container(
      color: index % 2 == 1
          ? AppColors.panel2.withOpacity(0.3)
          : Colors.transparent,
      child: Row(
        children: [
          // Row number
          SizedBox(
            width: 48,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          // Term
          Expanded(
            flex: 3,
            child: _tableCellInput(row.termController),
          ),
          // Definition
          Expanded(
            flex: 5,
            child: _tableCellInput(row.definitionController),
          ),
          // Pronunciation
          Expanded(
            flex: 3,
            child: _tableCellInput(row.pronunciationController),
          ),
          // Delete button
          SizedBox(
            width: 40,
            child: _rows.length > 1
                ? IconButton(
                    onPressed: () => _removeRow(index),
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.red,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                  )
                : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _tableCellInput(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.border.withOpacity(0.15)),
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _SaveButton(
            isSaving: _isSaving,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}


class _ManualTableRow {
  final TextEditingController termController = TextEditingController();
  final TextEditingController definitionController = TextEditingController();
  final TextEditingController pronunciationController = TextEditingController();

  void dispose() {
    termController.dispose();
    definitionController.dispose();
    pronunciationController.dispose();
  }
}


// ─── Add Row Button (+) ─────────────────────────────────────────────────────

class _AddRowButton extends StatefulWidget {
  final VoidCallback onTap;
  _AddRowButton({required this.onTap});

  @override
  State<_AddRowButton> createState() => _AddRowButtonState();
}

class _AddRowButtonState extends State<_AddRowButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _isPressed ? 3 : 0, 0),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, _isPressed ? 1 : 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(Icons.add, color: AppColors.onIconButton, size: 22),
      ),
    );
  }
}


// ─── Save Button ─────────────────────────────────────────────────────────────

class _SaveButton extends StatefulWidget {
  final bool isSaving;
  final VoidCallback onTap;

  _SaveButton({required this.isSaving, required this.onTap});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isSaving ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isSaving ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isSaving ? null : widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, _isPressed ? 1 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onSolidButton,
                ),
              )
            : Text(
                "Lưu",
                style: TextStyle(
                  color: AppColors.onSolidButton,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}


// ─── Import Action Chip ─────────────────────────────────────────────────────

class _ImportActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _ImportActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ImportActionChip> createState() => _ImportActionChipState();
}

class _ImportActionChipState extends State<_ImportActionChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _isPressed ? 3 : 0, 0),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, _isPressed ? 1 : 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: AppColors.onIconButton, size: 16),
            SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: AppColors.onSolidButton,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

