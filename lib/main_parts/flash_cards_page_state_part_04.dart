part of flutterflashcard_main;

extension FlashCardsPageStatePart04 on _FlashCardsPageState {
  Future<void> openGeminiExampleDialog() async {
    final card = currentCard;
    if (card == null) return;

    String selectedLevel = this._defaultGeminiLevel(_languageCode);
    String generatedText = '';
    String? errorText;
    bool isGenerating = false;

    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'card_examples',
        where: 'cardId = ?',
        whereArgs: [card.id],
      );
      if (rows.isNotEmpty) {
        final sb = StringBuffer();
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          final exText = row['exampleText'] as String? ?? '';
          final mean = row['meaning'] as String? ?? '';
          if (exText.isNotEmpty) {
            sb.writeln('Ví dụ ${i + 1}: $exText');
            if (mean.isNotEmpty) {
              sb.writeln('Dịch ${i + 1}: $mean');
            }
            sb.writeln();
          }
        }
        generatedText = sb.toString().trim();
      }
    } catch (e) {
      debugPrint('LOAD CACHED EXAMPLES ERROR: $e');
    }











    Future<void> generate(StateSetter setDialogState) async {
      setDialogState(() {
        isGenerating = true;
        errorText = null;
        generatedText = '';
      });

      final prompt =
          '''
Bạn là trợ lý tạo ví dụ flashcard cho người Việt học ngoại ngữ.
Ngôn ngữ thẻ: $_languageCode
Cấp độ/band: $selectedLevel
Từ vựng trên card: ${card.term}
Nghĩa hiện tại nếu có: ${card.definition}
Phiên âm nếu có: ${card.pronunciation}

Yêu cầu:
- Chỉ tạo ví dụ, không tạo lại nghĩa.
- Ưu tiên câu giao tiếp hằng ngày, tự nhiên, ngắn, dễ nhớ.
- Ví dụ phải dùng đúng từ vựng trên card.
- Nếu là tiếng Trung/Nhật/Hàn/Đức/Anh, giữ đúng ngôn ngữ gốc trong câu ví dụ.
- Trả về đúng format:
Ví dụ 1: ...
Dịch 1: ...
Ví dụ 2: ...
Dịch 2: ...
Gợi ý dùng: ...
''';

      try {
        final text = await GeminiFlashLiteClient.generateText(prompt);
        if (!mounted) return;
        setDialogState(() => generatedText = text.trim());
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => errorText =
              'Gemini lỗi: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      } finally {
        if (mounted) setDialogState(() => isGenerating = false);
      }
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.48),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final levels = this._geminiLevelsForLanguage(_languageCode);

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxWidth: 560),
                padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: Color(0xfff6f1fb),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border,
                      offset: Offset(0, 7),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x26000000),
                      offset: Offset(0, 18),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 42,
                            height: 42,
                            child: Center(child: geminiColorIcon(size: 34)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gemini tạo ví dụ',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  card.term,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.border,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Chọn cấp độ',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: levels.map((level) {
                          final active = selectedLevel == level;
                          return GestureDetector(
                            onTap: isGenerating
                                ? null
                                : () => setDialogState(
                                    () => selectedLevel = level,
                                  ),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 160),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: active ? AppColors.green : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.border,
                                    offset: Offset(0, active ? 4 : 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                level,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 14),
                      GestureDetector(
                        onTap: isGenerating
                            ? null
                            : () => generate(setDialogState),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isGenerating
                                ? AppColors.muted.withOpacity(0.35)
                                : AppColors.yellow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.border,
                                offset: Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: isGenerating
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.border,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppColors.border,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tạo ví dụ giao tiếp',
                                      style: TextStyle(
                                        color: AppColors.border,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (errorText != null) ...[
                        SizedBox(height: 12),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Color(0xffb3261e),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (generatedText.trim().isNotEmpty) ...[
                        SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.25,
                            ),
                          ),
                          child: SelectableText(
                            generatedText,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: this._outlineFlashDialogButton(
                                text: 'Copy',
                                icon: Icons.copy_rounded,
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: generatedText),
                                  );
                                  this.showFlashMessage('Đã copy nội dung Gemini');
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: this._solidFlashDialogButton(
                                text: 'Lưu ví dụ',
                                icon: Icons.save_rounded,
                                color: AppColors.green,
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  await this._saveCurrentCardExamples(generatedText);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  List<String> _geminiLevelsForLanguage(String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('zh'))
      return ['TOCFL Band A', 'TOCFL Band B', 'TOCFL Band C'];
    if (code.startsWith('en')) return ['A1', 'A2', 'B1', 'B2'];
    if (code.startsWith('de')) return ['A1', 'A2', 'B1', 'B2'];
    if (code.startsWith('ja')) return ['N5', 'N4', 'N3', 'N2'];
    if (code.startsWith('ko')) return ['TOPIK 1', 'TOPIK 2', 'TOPIK 3'];
    return ['Cơ bản', 'Trung bình', 'Nâng cao'];
  }


  String _defaultGeminiLevel(String languageCode) {
    final levels = this._geminiLevelsForLanguage(languageCode);
    return levels.isEmpty ? 'Cơ bản' : levels.first;
  }


  Widget _outlineFlashDialogButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, style: TextStyle(fontWeight: FontWeight.w900)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.buttonInk,
        padding: EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: AppColors.border, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }


  Widget _solidFlashDialogButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, style: TextStyle(fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.buttonInk,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1.3),
        ),
      ),
    );
  }


  List<Map<String, String>> _parseGeminiExamples(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final examples = <Map<String, String>>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final exampleMatch = RegExp(
        r'^Ví dụ\s*\d*\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (exampleMatch == null) continue;

      final example = exampleMatch.group(1)?.trim() ?? '';
      var meaning = '';
      if (i + 1 < lines.length) {
        final meaningMatch = RegExp(
          r'^Dịch\s*\d*\s*:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(lines[i + 1]);
        meaning = meaningMatch?.group(1)?.trim() ?? '';
      }

      if (example.isNotEmpty) {
        examples.add({'exampleText': example, 'meaning': meaning});
      }
    }

    if (examples.isEmpty && text.trim().isNotEmpty) {
      examples.add({'exampleText': text.trim(), 'meaning': ''});
    }

    return examples;
  }

}
