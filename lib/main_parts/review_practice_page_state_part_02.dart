part of flutterflashcard_main;

extension ReviewPracticePageStatePart02 on _ReviewPracticePageState {
  void _showMessage(String text) {
    showAppToast(context, text);
  }


  String _promptOf(StudyCardItem card) {
    if (_sentenceMode) return card.term;
    return _answerByDefinition ? card.term : card.definition;
  }


  String _subPromptOf(StudyCardItem card) {
    // Ôn tập/kiểm tra không hiện phiên âm trong câu hỏi.
    return '';
  }


  String _answerOf(StudyCardItem card) {
    if (_sentenceMode) return card.definition;
    return _answerByDefinition ? card.definition : card.term;
  }


  String _optionLabelOf(StudyCardItem card) {
    // Đáp án trắc nghiệm chỉ hiện nội dung đáp án, không kèm phiên âm.
    return this._answerOf(card);
  }


  String _normalizeAnswer(String value) {
    return normalizeText(value)
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


  List<String> _splitAnswerParts(String rawAnswer) {
    final seen = <String>{};
    final parts = <String>[];

    // Tách từng nghĩa riêng để chip không bị dính kiểu:
    // "chẳng bao lâu nữa, chẳng mấy chốc, sắp; ngay".
    // Không tách dấu cách thường, vì cụm từ như "xin chào" phải giữ nguyên.
    final cleaned = rawAnswer.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final separators = RegExp(r'[,/;；、，|\n\r]+');

    for (final item in cleaned.split(separators)) {
      final text = item.trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = this._normalizeAnswer(text);
      if (text.isEmpty || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      parts.add(text);
    }

    return parts;
  }


  List<String> _acceptedEssayAnswersOf(StudyCardItem card) {
    final rawAnswer = this._answerOf(card);
    final parts = this._splitAnswerParts(
      rawAnswer,
    ).map(_normalizeAnswer).where((e) => e.isNotEmpty).toSet().toList();

    final fullAnswer = this._normalizeAnswer(rawAnswer);
    if (fullAnswer.isNotEmpty && !parts.contains(fullAnswer)) {
      parts.add(fullAnswer);
    }

    return parts;
  }


  List<String> _acceptedListeningAnswersOf(StudyCardItem card) {
    final parts = this._splitAnswerParts(
      card.definition,
    ).map(_normalizeAnswer).where((e) => e.isNotEmpty).toSet().toList();

    final fallback = this._normalizeAnswer(card.definition);
    return parts.isNotEmpty
        ? parts
        : (fallback.isEmpty ? <String>[] : <String>[fallback]);
  }


  List<String> _splitListeningChoiceParts(String rawAnswer) {
    final seen = <String>{};
    final chips = <String>[];

    // Riêng chế độ nghe: tách thêm dấu cách để người dùng ghép nhiều chip
    // thành cụm nghĩa, ví dụ: "xin chào" -> "xin" + "chào".
    final meanings = this._splitAnswerParts(rawAnswer);
    final sourceParts = meanings.isNotEmpty ? meanings : [rawAnswer.trim()];

    for (final meaning in sourceParts) {
      for (final item in meaning.split(RegExp(r'\s+'))) {
        final text = item.trim();
        final key = this._normalizeAnswer(text);
        if (text.isEmpty || key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        chips.add(text);
      }
    }

    return chips;
  }


  bool _isEssayAnswerCorrect(StudyCardItem card, String typed) {
    final answer = this._normalizeAnswer(typed);
    if (answer.isEmpty) return false;
    return this._acceptedEssayAnswersOf(card).contains(answer);
  }


  bool _isSentenceAnswerCorrect(StudyCardItem card, String typed) {
    final answer = this._normalizeAnswer(typed);
    final expected = this._normalizeAnswer(this._answerOf(card));
    if (answer.isEmpty || expected.isEmpty) return false;
    if (answer == expected) return true;
    if (answer.contains(expected)) return true;
    if (calcSimilarity(answer, expected) >= 0.82) return true;
    return false;
  }


  String _extractJsonObject(String raw) {
    final text = raw.trim();
    final first = text.indexOf('{');
    final last = text.lastIndexOf('}');
    if (first >= 0 && last > first) {
      return text.substring(first, last + 1);
    }
    return text;
  }


  bool _boolFromGeminiValue(Object? value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'đúng';
  }


  Future<List<_GeminiTextGradeItem>> _gradeTextAnswersWithGemini() async {
    final payload = _quizCards.map((card) {
      return {
        'cardId': card.id,
        'question': this._promptOf(card),
        'expectedAnswer': this._answerOf(card),
        'studentAnswer': _selectedAnswerMap[card.id] ?? '',
        'answerDirection': _answerByDefinition
            ? 'vi'
            : widget.courseLanguageCode,
        'localExactCorrect': _correctMap[card.id] == true,
      };
    }).toList();

    final prompt =
        '''
Bạn là giám khảo chấm bài tự luận flashcard cho người Việt học ngoại ngữ.
Chế độ: ${_sentenceMode ? 'kiểm tra đặt câu' : 'tự luận'}
Ngôn ngữ học phần: ${widget.courseLanguageCode}
Hướng trả lời: ${_answerByDefinition ? 'người học trả lời bằng tiếng Việt hoặc nghĩa tiếng Việt' : 'người học trả lời bằng từ/câu của ngôn ngữ học phần'}

Tiêu chí chấm:
- Chấm ĐÚNG nếu câu trả lời cùng nghĩa hoặc tương đương nghĩa với expectedAnswer, dù khác chữ.
- Với kiểm tra đặt câu, chấp nhận câu khác nếu diễn đạt cùng ý giao tiếp với expectedAnswer.
- Chấm SAI nếu câu trả lời rỗng, sai trọng tâm, sai ngôn ngữ cần trả lời, hoặc quá xa nghĩa expectedAnswer.
- Nếu vừa sai cấu trúc/câu vừa quá xa nghĩa thì chắc chắn SAI.
- Không chấm quá khắt khe lỗi dấu câu, hoa thường, hoặc khác biệt nhỏ không đổi nghĩa.

Chỉ trả về JSON object hợp lệ, không markdown:
{
  "script": "nhận xét ngắn bằng tiếng Việt về kết quả chung",
  "items": [
    {"cardId": 1, "isCorrect": true, "feedback": "nhận xét ngắn"}
  ]
}

Dữ liệu bài làm:
${jsonEncode(payload)}
''';

    final text = await GeminiFlashLiteClient.generateText(
      prompt,
      maxOutputTokens: 8192,
      responseMimeType: 'application/json',
    );
    final decoded = jsonDecode(this._extractJsonObject(text));
    if (decoded is! Map) {
      throw FormatException('Gemini grading response is not an object');
    }

    final script = decoded['script']?.toString().trim() ?? '';
    final items = decoded['items'];
    if (items is! List) {
      throw FormatException('Gemini grading response has no items');
    }

    final results = <_GeminiTextGradeItem>[];
    for (final item in items) {
      if (item is! Map) continue;
      final cardId = int.tryParse(item['cardId']?.toString() ?? '');
      if (cardId == null) continue;

      final isCorrect = this._boolFromGeminiValue(item['isCorrect']);
      final feedback = item['feedback']?.toString().trim() ?? '';
      results.add(
        _GeminiTextGradeItem(
          cardId: cardId,
          isCorrect: isCorrect,
          feedback: feedback.isEmpty
              ? (isCorrect
                    ? 'Gemini chấp nhận vì câu trả lời tương đồng nghĩa.'
                    : 'Gemini đánh dấu sai vì câu trả lời chưa đủ gần nghĩa đáp án.')
              : feedback,
        ),
      );
    }

    if (results.isEmpty) {
      throw FormatException('Gemini grading response returned no valid items');
    }

    _geminiTextResultScript = script.isEmpty
        ? 'Gemini đã chấm theo mức độ tương đồng nghĩa của toàn bộ câu trả lời.'
        : script;
    return results;
  }


  Future<void> _recordFinalTextResults() async {
    for (final card in _quizCards) {
      await this._recordStudyResult(
        card: card,
        answerText: _selectedAnswerMap[card.id] ?? '',
        isCorrect: _correctMap[card.id] == true,
      );
    }
  }


  Future<void> _finalizeTextModeWithGemini() async {
    if (_isGeminiTextGrading) return;

    setState(() => _isGeminiTextGrading = true);

    try {
      final grades = await this._gradeTextAnswersWithGemini();
      if (!mounted) return;
      setState(() {
        for (final grade in grades) {
          _correctMap[grade.cardId] = grade.isCorrect;
          if (grade.feedback.trim().isNotEmpty) {
            _geminiTextFeedbackMap[grade.cardId] = grade.feedback;
          }
        }
      });
    } catch (e) {
      debugPrint('GEMINI TEXT GRADING ERROR: $e');
      if (mounted) {
        setState(() {
          _geminiTextResultScript =
              'Gemini không chấm được lần này, app dùng kết quả chấm nhanh tại máy.';
        });
        this._showMessage('Gemini chấm tự luận lỗi, dùng kết quả tạm');
      }
    } finally {
      if (mounted) setState(() => _isGeminiTextGrading = false);
    }

    await this._recordFinalTextResults();
    await this._finishStudySession();
    if (mounted) this._showResultSheet();
  }


  List<String> _buildChoices(StudyCardItem target) {
    final correct = this._optionLabelOf(target);
    final wrongPool = _cards
        .where((e) => e.id != target.id)
        .map(_optionLabelOf)
        .where((e) => e.trim().isNotEmpty && e.trim() != correct.trim())
        .toSet()
        .toList();

    wrongPool.shuffle(_random);
    final options = <String>[correct, ...wrongPool.take(3)];

    while (options.length < 4) {
      options.add('Đáp án ${options.length + 1}');
    }

    options.shuffle(_random);
    return options;
  }


  String _extractJsonArray(String raw) {
    final text = raw.trim();
    final first = text.indexOf('[');
    final last = text.lastIndexOf(']');
    if (first >= 0 && last > first) {
      return text.substring(first, last + 1);
    }
    return text;
  }


  String _cleanGeneratedSentence(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'^\s*[-*\d.)]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }


  List<_GeneratedSentenceQuestion> _parseGeneratedSentenceQuestions(
    String raw,
  ) {
    final decoded = jsonDecode(this._extractJsonArray(raw));
    if (decoded is! List) {
      throw FormatException('Gemini sentence response is not a list');
    }

    final questions = <_GeneratedSentenceQuestion>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final cardId = int.tryParse(item['cardId']?.toString() ?? '');
      final question = this._cleanGeneratedSentence(
        item['question']?.toString() ?? '',
      );
      final answer = this._cleanGeneratedSentence(item['answer']?.toString() ?? '');
      if (cardId == null || question.isEmpty || answer.isEmpty) continue;

      questions.add(
        _GeneratedSentenceQuestion(
          cardId: cardId,
          question: question,
          answer: answer,
        ),
      );
    }

    return questions;
  }


  List<StudyCardItem> _fallbackSentenceCards(List<StudyCardItem> selected) {
    return selected.map((card) {
      return card.copyWith(
        term: _answerByDefinition ? card.term : card.definition,
        definition: _answerByDefinition ? card.definition : card.term,
      );
    }).toList();
  }


  String _reviewLanguageNameFromCode(String code) {
    switch (code) {
      case 'zh-CN':
        return 'Tiếng Trung Giản thể';
      case 'zh-TW':
        return 'Tiếng Trung Phồn thể';
      case 'en-US':
        return 'Tiếng Anh';
      case 'de-DE':
        return 'Tiếng Đức';
      case 'ja-JP':
        return 'Tiếng Nhật';
      case 'ko-KR':
        return 'Tiếng Hàn';
      case 'vi-VN':
        return 'Tiếng Việt';
      default:
        return code.isEmpty ? 'Ngoại ngữ' : code;
    }
  }


  String _sentenceDirectionKey() {
    return _answerByDefinition ? 'foreign_to_vi' : 'vi_to_foreign';
  }


  Future<Map<int, _GeneratedSentenceQuestion>> _loadCachedSentenceQuestions(
    List<StudyCardItem> selected,
  ) async {
    if (selected.isEmpty) return {};

    final ids = selected.map((card) => card.id).toList();
    final cardsById = {for (final card in selected) card.id: card};
    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'review_sentence_questions',
      where:
          'courseId = ? AND languageCode = ? AND direction = ? AND cardId IN ($placeholders)',
      whereArgs: [
        widget.courseId,
        widget.courseLanguageCode,
        this._sentenceDirectionKey(),
        ...ids,
      ],
    );

    final cached = <int, _GeneratedSentenceQuestion>{};
    for (final row in rows) {
      final cardId = row['cardId'] as int?;
      if (cardId == null) continue;

      final card = cardsById[cardId];
      if (card == null) continue;
      if ((row['sourceTerm']?.toString() ?? '') != card.term) continue;
      if ((row['sourceDefinition']?.toString() ?? '') != card.definition)
        continue;

      final question = row['question']?.toString() ?? '';
      final answer = row['answer']?.toString() ?? '';
      if (question.trim().isEmpty || answer.trim().isEmpty) continue;

      cached[cardId] = _GeneratedSentenceQuestion(
        cardId: cardId,
        question: question,
        answer: answer,
      );
    }

    return cached;
  }

}
