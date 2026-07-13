part of flutterflashcard_main;

extension FlashCardsPageStatePart04 on _FlashCardsPageState {
  Future<void> openGeminiExampleDialog() async {
    final card = currentCard;
    if (card == null) return;

    final questionController = TextEditingController();
    final geminiScrollController = ScrollController();
    var examples = <Map<String, String>>[];
    var memoryHint = '';
    var statusText = 'Đang lấy ví dụ...';
    String? errorText;
    String? questionErrorText;
    var questionAnswer = '';
    var isGenerating = false;
    var isAsking = false;
    var autoGenerationStarted = false;
    var dialogAlive = true;

    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'card_examples',
        where: 'cardId = ?',
        whereArgs: [card.id],
        orderBy: 'id ASC',
      );
      examples = rows.map((row) {
        return <String, String>{
          'exampleText': row['exampleText'] as String? ?? '',
          'meaning': row['meaning'] as String? ?? '',
          'note': row['pronunciation'] as String? ?? '',
        };
      }).where((example) => example['exampleText']!.trim().isNotEmpty).toList();
      if (examples.isNotEmpty) {
        statusText = 'Đã tải ví dụ đã lưu.';
      }
    } catch (e) {
      debugPrint('LOAD CACHED EXAMPLES ERROR: $e');
    }

    String readMemoryHint(String text) {
      final match = RegExp(
        r'^Gợi ý(?: nhớ nhanh| dùng)?\s*:\s*(.+)$',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(text);
      return match?.group(1)?.trim() ?? '';
    }

    Future<void> generateExamples(StateSetter setDialogState) async {
      if (isGenerating) return;
      setDialogState(() {
        isGenerating = true;
        errorText = null;
        statusText = 'Gemini đang tạo ví dụ mới...';
      });

      final level = this._defaultGeminiLevel(_languageCode);
      final prompt = '''
Bạn là trợ lý tạo ví dụ flashcard cho người Việt học ngoại ngữ.
Ngôn ngữ thẻ: $_languageCode
Cấp độ/band: $level
Từ vựng trên card: ${card.term}
Nghĩa hiện tại nếu có: ${card.definition}
Phiên âm nếu có: ${card.pronunciation}

Yêu cầu:
- Tạo đúng 3 ví dụ giao tiếp hằng ngày, tự nhiên, ngắn và dễ nhớ.
- Mỗi ví dụ phải dùng đúng từ vựng trên card.
- Giữ đúng ngôn ngữ gốc trong câu ví dụ và dịch sang tiếng Việt.
- Thêm một ghi chú ngắn về ngữ cảnh sử dụng cho từng ví dụ.
- Trả về đúng format, không thêm tiêu đề hoặc markdown:
Ví dụ 1: ...
Dịch 1: ...
Ghi chú 1: ...
Ví dụ 2: ...
Dịch 2: ...
Ghi chú 2: ...
Ví dụ 3: ...
Dịch 3: ...
Ghi chú 3: ...
Gợi ý nhớ nhanh: ...
''';

      try {
        final text = await GeminiFlashLiteClient.generateText(prompt);
        final parsed = this._parseGeminiExamples(text.trim());
        final saved = await this._saveCurrentCardExamples(
          text.trim(),
          showMessage: false,
        );
        if (!mounted || !dialogAlive) return;
        setDialogState(() {
          examples = parsed;
          memoryHint = readMemoryHint(text);
          statusText = saved
              ? 'Đã tạo và tự động lưu ví dụ mới.'
              : 'Đã tạo ví dụ nhưng chưa thể lưu vào dữ liệu.';
        });
      } catch (e) {
        if (!mounted || !dialogAlive) return;
        setDialogState(() {
          errorText =
              'Gemini lỗi: ${e.toString().replaceFirst('Exception: ', '')}';
          statusText = 'Không thể tạo ví dụ.';
        });
      } finally {
        if (mounted && dialogAlive) {
          setDialogState(() => isGenerating = false);
        }
      }
    }

    Future<void> askGemini(StateSetter setDialogState) async {
      final question = questionController.text.trim();
      if (question.isEmpty || isAsking) return;
      setDialogState(() {
        isAsking = true;
        questionAnswer = '';
        questionErrorText = null;
      });

      void scrollToAnswer() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!dialogAlive || !geminiScrollController.hasClients) return;
          geminiScrollController.animateTo(
            geminiScrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        });
      }

      scrollToAnswer();

      final prompt = '''
Bạn là trợ lý học ngoại ngữ cho người Việt.
Hãy trả lời trực tiếp, rõ ràng và ngắn gọn câu hỏi về flashcard sau.
Ngôn ngữ: $_languageCode
Từ vựng: ${card.term}
Định nghĩa: ${card.definition}
Phiên âm: ${card.pronunciation}
Câu hỏi của người dùng: $question
''';

      try {
        final answer = await GeminiFlashLiteClient.generateText(prompt);
        if (!mounted || !dialogAlive) return;
        final normalizedAnswer = answer
            .trim()
            .replaceAll(RegExp(r'\n{3,}'), '\n\n');
        setDialogState(() {
          questionAnswer = normalizedAnswer.isEmpty
              ? 'Gemini không trả về nội dung.'
              : normalizedAnswer;
        });
        scrollToAnswer();
      } catch (e) {
        if (!mounted || !dialogAlive) return;
        setDialogState(() {
          questionErrorText =
              'Gemini lỗi: ${e.toString().replaceFirst('Exception: ', '')}';
        });
        scrollToAnswer();
      } finally {
        if (mounted && dialogAlive) {
          setDialogState(() => isAsking = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.68),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (examples.isEmpty && !autoGenerationStarted) {
              autoGenerationStarted = true;
              Future<void>.microtask(
                () => generateExamples(setDialogState),
              );
            }

            Widget actionButton({
              required String text,
              required VoidCallback? onPressed,
              bool primary = false,
            }) {
              return ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      primary ? Color(0xff3e5cff) : Color(0xff191a20),
                  foregroundColor: onPressed == null
                      ? Color(0xff666873)
                      : Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Color(0xff292b32)),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              );
            }

            Widget accentPanel({
              required Widget child,
              double radius = 12,
              double minHeight = 0,
              EdgeInsets margin = EdgeInsets.zero,
            }) {
              return Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: minHeight),
                margin: margin,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Color(0xff111529),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: Color(0xff292b32)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: Color(0xff3e5cff)),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final screenSize = MediaQuery.sizeOf(context);
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1040,
                  maxHeight: screenSize.height * 0.86,
                ),
                child: Container(
                  padding: EdgeInsets.all(screenSize.width < 600 ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Color(0xff0b0c0f),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Color(0xff292b32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 60,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          geminiColorIcon(size: 22),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Ví dụ với Gemini',
                              style: TextStyle(
                                color: Color(0xffeef0f7),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.pop(dialogContext),
                            style: IconButton.styleFrom(
                              backgroundColor: Color(0xff202126),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Color(0xffeef0f7),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Color(0xffa8b0c5),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (errorText != null) ...[
                        SizedBox(height: 6),
                        SelectableText(
                          errorText!,
                          style: TextStyle(
                            color: Color(0xffff6b7a),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          controller: geminiScrollController,
                          padding: EdgeInsets.only(right: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isGenerating && examples.isEmpty)
                                ...List.generate(
                                  3,
                                  (index) => Container(
                                    height: 96,
                                    margin: EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Color(0xff15161a),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Color(0xff292b32),
                                      ),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xff6477ff),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...examples.map((example) {
                                  return Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.only(bottom: 10),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xff15161a),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Color(0xff292b32),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(
                                          example['exampleText'] ?? '',
                                          style: TextStyle(
                                            color: Color(0xffeef0f7),
                                            fontSize: 18,
                                            height: 1.4,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if ((example['meaning'] ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          SizedBox(height: 5),
                                          SelectableText(
                                            example['meaning']!,
                                            style: TextStyle(
                                              color: Color(0xffcfd6ff),
                                              fontSize: 13,
                                              height: 1.45,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                        if ((example['note'] ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          SelectableText(
                                            example['note']!,
                                            style: TextStyle(
                                              color: Color(0xff8f95b8),
                                              fontSize: 12,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              if (memoryHint.isNotEmpty)
                                accentPanel(
                                  radius: 10,
                                  margin: EdgeInsets.only(top: 2, bottom: 12),
                                  child: SelectableText(
                                    'Gợi ý nhớ nhanh: $memoryHint',
                                    style: TextStyle(
                                      color: Color(0xffeef0f7),
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              TextField(
                                controller: questionController,
                                enabled: !isAsking,
                                minLines: 3,
                                maxLines: 5,
                                style: TextStyle(
                                  color: Color(0xffeef0f7),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Đặt câu hỏi riêng về thẻ này...',
                                  hintStyle: TextStyle(
                                    color: Color(0xff8f95b8),
                                  ),
                                  filled: true,
                                  fillColor: Color(0xff090a0d),
                                  contentPadding: EdgeInsets.all(12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xff292b32),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xff3e5cff),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  actionButton(
                                    text: isAsking ? 'Đang hỏi...' : 'Hỏi',
                                    primary: true,
                                    onPressed: isAsking
                                        ? null
                                        : () => askGemini(setDialogState),
                                  ),
                                  SizedBox(width: 8),
                                  actionButton(
                                    text: 'Copy',
                                    onPressed: questionAnswer.isEmpty || isAsking
                                        ? null
                                        : () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: questionAnswer,
                                              ),
                                            );
                                            this.showFlashMessage(
                                              'Đã copy câu trả lời Gemini',
                                            );
                                          },
                                  ),
                                ],
                              ),
                              if (isAsking ||
                                  questionAnswer.isNotEmpty ||
                                  questionErrorText != null) ...[
                                SizedBox(height: 10),
                                accentPanel(
                                  minHeight: 64,
                                  child: isAsking
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xff7c8cff),
                                              ),
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'Gemini đang trả lời...',
                                              style: TextStyle(
                                                color: Color(0xffcfd6ff),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        )
                                      : questionErrorText != null
                                      ? SelectionArea(
                                          child: Text(
                                            questionErrorText!,
                                            style: TextStyle(
                                              color: Color(0xffff7183),
                                              fontSize: 13,
                                              height: 1.6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : SelectionArea(
                                          child: Text(
                                            questionAnswer,
                                            style: TextStyle(
                                              color: Color(0xffeef1ff),
                                              fontSize: 13,
                                              height: 1.6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          actionButton(
                            text: 'Đóng',
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                          SizedBox(width: 10),
                          actionButton(
                            text: isGenerating ? 'Đang tạo...' : 'Tạo mới',
                            primary: true,
                            onPressed: isGenerating
                                ? null
                                : () => generateExamples(setDialogState),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    dialogAlive = false;
    geminiScrollController.dispose();
    questionController.dispose();
  }

  List<String> _geminiLevelsForLanguage(String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('zh')) {
      return ['TOCFL Band A', 'TOCFL Band B', 'TOCFL Band C'];
    }
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
}
