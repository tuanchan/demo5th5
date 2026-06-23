part of flutterflashcard_main;

extension ReviewPracticePageStatePart03 on _ReviewPracticePageState {
  Future<void> _saveSentenceQuestions(
    List<StudyCardItem> sourceCards,
    List<_GeneratedSentenceQuestion> questions,
  ) async {
    if (questions.isEmpty) return;

    final db = await AppDatabase.instance.database;
    final cardsById = {for (final card in sourceCards) card.id: card};
    final now = DateTime.now().toIso8601String();

    for (final item in questions) {
      final card = cardsById[item.cardId];
      if (card == null) continue;

      await db.insert('review_sentence_questions', {
        'courseId': widget.courseId,
        'cardId': card.id,
        'languageCode': widget.courseLanguageCode,
        'direction': this._sentenceDirectionKey(),
        'sourceTerm': card.term,
        'sourceDefinition': card.definition,
        'question': item.question,
        'answer': item.answer,
        'createdAt': now,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<StudyCardItem>> _selectSentenceSourceCards({
    required List<StudyCardItem> shuffled,
    required int limit,
  }) async {
    final cachedById = await this._loadCachedSentenceQuestions(_cards);
    final cachedIds = cachedById.keys.toSet();
    final selected = <StudyCardItem>[];
    final selectedIds = <int>{};

    for (final card in shuffled) {
      if (!cachedIds.contains(card.id)) continue;
      selected.add(card);
      selectedIds.add(card.id);
      if (selected.length >= limit) return selected;
    }

    for (final card in shuffled) {
      if (selectedIds.contains(card.id)) continue;
      selected.add(card);
      selectedIds.add(card.id);
      if (selected.length >= limit) break;
    }

    return selected;
  }

  Future<List<StudyCardItem>> _buildSentenceQuizCards(
    List<StudyCardItem> selected,
  ) async {
    if (selected.isEmpty) return selected;

    final fallback = this._fallbackSentenceCards(selected);
    final fallbackById = {for (final card in fallback) card.id: card};
    final cachedById = await this._loadCachedSentenceQuestions(selected);
    final missing = selected
        .where((card) => !cachedById.containsKey(card.id))
        .toList();
    final generatedById = Map<int, _GeneratedSentenceQuestion>.from(cachedById);

    List<StudyCardItem> buildCardsFromAvailable() {
      return selected.map((card) {
        final item = generatedById[card.id];
        if (item == null) return fallbackById[card.id] ?? card;
        return card.copyWith(term: item.question, definition: item.answer);
      }).toList();
    }

    if (missing.isEmpty) {
      return buildCardsFromAvailable();
    }

    final cardsJson = jsonEncode(
      missing.map((card) {
        return {
          'cardId': card.id,
          'term': card.term,
          'definition': card.definition,
        };
      }).toList(),
    );
    final direction = _answerByDefinition
        ? 'question la cau trong ngon ngu hoc phan co dung tu vung; answer la ban dich tieng Viet.'
        : 'question la cau tieng Viet; answer la cau trong ngon ngu hoc phan co dung tu vung.';

    final prompt =
        '''
Ban la tro ly tao de kiem tra dat cau cho nguoi Viet hoc ngoai ngu.
Ngon ngu hoc phan: ${widget.courseLanguageCode} (${this._reviewLanguageNameFromCode(widget.courseLanguageCode)})
So cau can tao: ${missing.length}
Huong cau hoi: $direction

Yeu cau:
- Tao dung ${missing.length} cau, moi cardId dung 1 cau.
- Tra ve day du moi cardId trong du lieu the, khong duoc bo sot.
- Uu tien cau giao tiep doi thuong, tu nhien, co the dung trong hoi thoai hang ngay.
- Khong tao cau hoc thuat, khong cau may moc, khong qua dai.
- Cau trong ngon ngu hoc phan phai dung dung term cua card tuong ung.
- Khong them giai thich, khong markdown.
- Chi tra ve JSON array hop le theo mau:
[{"cardId":1,"question":"...","answer":"..."}]

Du lieu the:
$cardsJson
''';

    try {
      final text = await GeminiFlashLiteClient.generateText(
        prompt,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
      );
      final generated = this._parseGeneratedSentenceQuestions(text);
      if (generated.isEmpty) {
        throw FormatException('Gemini did not return sentence items');
      }
      await this._saveSentenceQuestions(missing, generated);
      for (final item in generated) {
        generatedById[item.cardId] = item;
      }

      return buildCardsFromAvailable();
    } catch (e) {
      debugPrint('GENERATE SENTENCE REVIEW ERROR: $e');
      if (mounted) {
        this._showMessage(
          cachedById.isEmpty
              ? 'Gemini lỗi hoặc hết quota, dùng tạm dữ liệu thẻ'
              : 'Thiếu một số câu mới, dùng câu đã lưu trước',
        );
      }
      return buildCardsFromAvailable();
    }
  }

  Future<void> _startQuiz() async {
    if (_cards.isEmpty) return;

    final copied = List<StudyCardItem>.from(_cards)..shuffle(_random);
    final limit = _questionLimit.clamp(1, _cards.length).toInt();
    var selected = copied.take(limit).toList();
    final now = DateTime.now();

    setState(() {
      _quizCards = selected;
      _choiceMap = {
        for (var i = 0; i < selected.length; i++)
          selected[i].id: _listening
              ? this._buildListeningChoices(selected[i])
              : (_sentenceMode
                    ? (i % 3 == 0
                          ? this._buildChoices(selected[i])
                          : (i % 3 == 2
                                ? this._buildListeningChoices(selected[i])
                                : <String>[]))
                    : ((_matchingPairs)
                          ? <String>[]
                          : this._buildChoices(selected[i]))),
      };
      _questionKeys
        ..clear()
        ..addEntries(selected.map((card) => MapEntry(card.id, GlobalKey())));
      _answeredCards.clear();
      _correctMap.clear();
      _selectedAnswerMap.clear();
      _geminiTextFeedbackMap.clear();
      if (_matchingPairs) {
        this._setupMatchingTilesForPage(0);
      } else {
        _matchPairTiles = [];
      }
      _selectedMatchPairTileId = null;
      _matchedPairCardIds.clear();
      _wrongMatchPairTileIds.clear();
      _correctMatchPairTileIds.clear();
      _geminiTextResultScript = '';
      _isGeminiTextGrading = false;
      _selectedListeningAnswer = null;
      _recordedResultCardIds.clear();
      _cardStartedAtMap
        ..clear()
        ..addEntries(selected.map((card) => MapEntry(card.id, now)));
      _finished = false;
      _isGeneratingSentenceQuiz = false;
      _showSetup = false;
      _currentEssayIndex = 0;
      _essayQuestionStartedAt = now;
      _essayController.clear();
    });

    await this._startStudySession(
      mode: _listening
          ? 'review_listening'
          : (_matchingPairs
                ? 'review_matching_pairs'
                : (_sentenceMode
                ? 'review_mixed'
                : (_multipleChoice
                      ? 'review_multiple_choice'
                          : 'review_essay'))),
      totalCards: selected.length,
    );

    final isFirstListening = _listening || (_sentenceMode && _currentEssayIndex % 3 == 2);
    if (isFirstListening) {
      Future.delayed(Duration(milliseconds: 260), () {
        if (mounted) this._playListeningAudio();
      });
    }
  }

  Future<void> _startWrongEssayReview() async {
    final wrongCards = _wrongReviewCards;
    if (wrongCards.isEmpty) {
      this._showMessage('Không có câu sai để ôn lại');
      return;
    }

    await this._finishStudySession();

    final selected = List<StudyCardItem>.from(wrongCards);
    final now = DateTime.now();

    setState(() {
      _quizCards = selected;
      _choiceMap = {
        for (final card in selected) card.id: <String>[],
      };
      _questionKeys
        ..clear()
        ..addEntries(selected.map((card) => MapEntry(card.id, GlobalKey())));
      _answeredCards.clear();
      _correctMap.clear();
      _selectedAnswerMap.clear();
      _geminiTextFeedbackMap.clear();
      _matchPairTiles = [];
      _selectedMatchPairTileId = null;
      _matchedPairCardIds.clear();
      _wrongMatchPairTileIds.clear();
      _correctMatchPairTileIds.clear();
      _geminiTextResultScript = '';
      _isGeminiTextGrading = false;
      _selectedListeningAnswer = null;
      _recordedResultCardIds.clear();
      _cardStartedAtMap
        ..clear()
        ..addEntries(selected.map((card) => MapEntry(card.id, now)));
      _finished = false;
      _isGeneratingSentenceQuiz = false;
      _showSetup = false;
      _currentEssayIndex = 0;
      _essayQuestionStartedAt = now;
      _essayController.clear();
    });

    await this._startStudySession(
      mode: 'review_essay_wrong',
      totalCards: selected.length,
    );
  }

  Future<void> _restart() async {
    await this._finishStudySession();
    setState(() {
      _showSetup = true;
      _isGeneratingSentenceQuiz = false;
      _isGeminiTextGrading = false;
      _finished = false;
    });
    this._openSetupSheet();
  }

  Future<void> _answerCard(StudyCardItem card, String selected) async {
    if (_answeredCards.contains(card.id) || _finished) return;

    final correctText = this._optionLabelOf(card);
    final isCorrect =
        this._normalizeAnswer(selected) == this._normalizeAnswer(correctText);

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = isCorrect;
      _selectedAnswerMap[card.id] = selected;
    });

    await this._recordStudyResult(
      card: card,
      answerText: selected,
      isCorrect: isCorrect,
    );

    if (_sentenceMode) {
      final wasLast = _currentEssayIndex + 1 >= _quizCards.length;
      Future.delayed(Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          if (wasLast) {
            _finished = true;
          } else {
            _currentEssayIndex++;
            _selectedListeningAnswer = null;
            _essayController.clear();
            _essayQuestionStartedAt = DateTime.now();
            _cardStartedAtMap[_quizCards[_currentEssayIndex].id] =
                _essayQuestionStartedAt;
          }
        });
        if (_finished) {
          this._finishStudySession();
          this._showResultSheet();
        } else {
          if (_currentEssayIndex % 3 == 2) {
            this._playListeningAudio();
          }
        }
      });
    } else {
      this._scrollToNextUnanswered(card);
    }
  }

  Future<void> _skipCard(StudyCardItem card) async {
    await this._answerCard(card, '');
  }

  void _scrollToNextUnanswered(StudyCardItem currentCard) {
    final currentIndex = _quizCards.indexWhere((e) => e.id == currentCard.id);
    if (currentIndex < 0) return;

    final nextIndex = _quizCards.indexWhere(
      (e) => !_answeredCards.contains(e.id),
      currentIndex + 1,
    );

    if (nextIndex < 0) return;
    this._scrollToQuestion(_quizCards[nextIndex].id);
  }

  void _scrollToFirstWrong() {
    StudyCardItem? wrongCard;

    for (final card in _quizCards) {
      if (_correctMap[card.id] != true) {
        wrongCard = card;
        break;
      }
    }

    if (wrongCard == null) return;
    this._scrollToQuestion(wrongCard.id);
  }

  void _openWrongReviewFromResult() {
    final wrongCards = _wrongReviewCards;
    if (wrongCards.isEmpty) {
      this._showMessage('Không có câu sai để xem lại');
      return;
    }

    Navigator.pop(context);
    final firstWrong = wrongCards.first;
    final firstWrongIndex = _quizCards.indexWhere((e) => e.id == firstWrong.id);

    setState(() {
      if ((_essay || _listening || _sentenceMode) &&
          !_multipleChoice &&
          firstWrongIndex >= 0) {
        _currentEssayIndex = firstWrongIndex;
        _selectedListeningAnswer = null;
        _essayController.clear();
      }
    });

    this._showWrongReviewSheet(initialIndex: 0);
  }
}
