part of flutterflashcard_main;

extension ReviewPracticePageStatePart04 on _ReviewPracticePageState {
  Future<void> _showWrongReviewSheet({int initialIndex = 0}) async {
    final wrongCards = _wrongReviewCards;
    if (wrongCards.isEmpty) return;

    var reviewIndex = initialIndex.clamp(0, wrongCards.length - 1).toInt();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final wrongCard = wrongCards[reviewIndex];
            final realIndex = _quizCards.indexWhere(
              (e) => e.id == wrongCard.id,
            );
            final yourAnswer = (_selectedAnswerMap[wrongCard.id] ?? '').trim();
            final promptText = _listening
                ? wrongCard.term.trim()
                : this._promptOf(wrongCard).trim();
            final correctAnswer =
                (_listening ? wrongCard.definition : this._answerOf(wrongCard))
                    .trim();
            final geminiFeedback =
                _geminiTextFeedbackMap[wrongCard.id]?.trim() ?? '';
            final promptTitle = _listening
                ? 'Âm thanh đã phát'
                : (_sentenceMode
                      ? (_answerByDefinition
                            ? 'Câu ngoại ngữ'
                            : 'Câu tiếng Việt')
                      : (_answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa'));

            void moveReview(int delta) {
              final nextIndex = (reviewIndex + delta)
                  .clamp(0, wrongCards.length - 1)
                  .toInt();
              if (nextIndex == reviewIndex) return;

              setSheetState(() {
                reviewIndex = nextIndex;
              });

              final nextCard = wrongCards[nextIndex];
              final nextRealIndex = _quizCards.indexWhere(
                (e) => e.id == nextCard.id,
              );
              if ((_essay || _listening || _sentenceMode) &&
                  !_multipleChoice &&
                  nextRealIndex >= 0) {
                setState(() {
                  _currentEssayIndex = nextRealIndex;
                  _selectedListeningAnswer = null;
                  _essayController.clear();
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 760),
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: Color(0xff0b0c10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xff242832)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 12),
                        blurRadius: 24,
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Câu sai ${reviewIndex + 1}/${wrongCards.length}',
                                    style: TextStyle(
                                      color: Color(0xff9aa4b8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    realIndex >= 0
                                        ? 'Câu ${realIndex + 1}/$_total'
                                        : 'Xem lại câu sai',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (geminiFeedback.isNotEmpty) ...[
                              SizedBox(width: 8),
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 22,
                                color: Color(0xff4257ff),
                              ),
                            ],
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        Text(
                          promptTitle,
                          style: TextStyle(
                            color: Color(0xff9aa4b8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xff242832)),
                            ),
                          ),
                          child: Text(
                            promptText.isEmpty
                                ? 'Không có nội dung'
                                : promptText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: promptText.length > 22 ? 24 : 30,
                              fontWeight: FontWeight.w400,
                              height: 1.15,
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Bạn trả lời',
                          style: TextStyle(
                            color: Color(0xff9aa4b8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        this._reviewAnswerBox(
                          text: yourAnswer.isEmpty ? 'Đã bỏ qua' : yourAnswer,
                          icon: yourAnswer.isEmpty
                              ? Icons.skip_next_rounded
                              : Icons.close_rounded,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Đáp án đúng',
                          style: TextStyle(
                            color: Color(0xff9aa4b8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        this._reviewAnswerBox(
                          text: correctAnswer.isEmpty
                              ? 'Chưa có đáp án'
                              : correctAnswer,
                          icon: Icons.check_rounded,
                        ),
                        if (geminiFeedback.isNotEmpty) ...[
                          SizedBox(height: 12),
                          this._geminiReviewBox(geminiFeedback),
                        ],
                        SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 54,
                              child: this._outlineButton(
                                text: '',
                                icon: Icons.chevron_left_rounded,
                                onTap: reviewIndex <= 0
                                    ? () {}
                                    : () => moveReview(-1),
                              ),
                            ),
                            Spacer(),
                            this._statChip(
                              text: '${reviewIndex + 1}/${wrongCards.length}',
                            ),
                            Spacer(),
                            SizedBox(
                              width: 54,
                              child: this._solidButton(
                                text: '',
                                icon: Icons.chevron_right_rounded,
                                color: Color(0xff4257ff),
                                onTap: reviewIndex >= wrongCards.length - 1
                                    ? () {}
                                    : () => moveReview(1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _scrollToQuestion(int cardId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _questionKeys[cardId]?.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }


  Future<void> _submitMultipleChoice() async {
    if (_quizCards.isEmpty) return;

    final skippedCards = <StudyCardItem>[];

    setState(() {
      for (final card in _quizCards) {
        if (!_answeredCards.contains(card.id)) {
          skippedCards.add(card);
          _answeredCards.add(card.id);
          _correctMap[card.id] = false;
          _selectedAnswerMap[card.id] = '';
        }
      }
      _finished = true;
    });

    for (final card in skippedCards) {
      await this._recordStudyResult(card: card, answerText: '', isCorrect: false);
    }

    await this._finishStudySession();
    this._scrollToFirstWrong();
  }


  void _moveEssayPrevious() {
    if (_currentEssayIndex <= 0 || _finished) return;

    final previousIndex = _currentEssayIndex - 1;
    final previousCard = _quizCards[previousIndex];

    setState(() {
      _currentEssayIndex = previousIndex;
      _essayController.text = _selectedAnswerMap[previousCard.id] ?? '';
      _essayQuestionStartedAt = DateTime.now();
    });
  }


  Future<void> _submitEssay({bool allowEmptyAsSkip = false}) async {
    if (_quizCards.isEmpty || _finished || _isGeminiTextGrading) return;
    final card = _quizCards[_currentEssayIndex];
    final typed = _essayController.text.trim();

    if (typed.isEmpty && !allowEmptyAsSkip) {
      this._showMessage('Nhập câu trả lời trước');
      return;
    }

    final ok = this._isEssayAnswerCorrect(card, typed);
    final wasLast = _currentEssayIndex + 1 >= _quizCards.length;

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = ok;
      _selectedAnswerMap[card.id] = typed;

      if (wasLast) {
        _finished = true;
        _essayController.clear();
      } else {
        _currentEssayIndex++;
        final nextCard = _quizCards[_currentEssayIndex];
        _essayController.text = _selectedAnswerMap[nextCard.id] ?? '';
        _essayQuestionStartedAt = DateTime.now();
      }
    });

    if (!_usesGeminiTextGrading) {
      await this._recordStudyResult(card: card, answerText: typed, isCorrect: ok);
    }

    if (_finished) {
      if (_usesGeminiTextGrading) {
        await this._finalizeTextModeWithGemini();
      } else {
        await this._finishStudySession();
        this._showResultSheet();
      }
    } else {
      final isNextListening = _listening || (_sentenceMode && _currentEssayIndex % 3 == 2);
      if (isNextListening) {
        Future.delayed(Duration(milliseconds: 260), () {
          if (mounted) this._playListeningAudio();
        });
      }
    }
  }


  List<String> _buildListeningChoices(StudyCardItem target) {
    final correctOptions = this._splitListeningChoiceParts(target.definition);
    final correctKeys = correctOptions
        .map(_normalizeAnswer)
        .where((e) => e.isNotEmpty)
        .toSet();
    final seenWrongKeys = <String>{};

    final wrongPool = _cards
        .where((e) => e.id != target.id)
        .expand((e) => this._splitListeningChoiceParts(e.definition))
        .where((e) {
          final key = this._normalizeAnswer(e);
          if (key.isEmpty ||
              correctKeys.contains(key) ||
              seenWrongKeys.contains(key))
            return false;
          seenWrongKeys.add(key);
          return true;
        })
        .toList();

    wrongPool.shuffle(_random);
    final targetCount = correctOptions.length >= 6
        ? correctOptions.length + 2
        : 6;
    final options = <String>[
      ...correctOptions.where((e) => e.trim().isNotEmpty),
      ...wrongPool.take(targetCount - correctOptions.length),
    ];

    while (options.length < 4) {
      options.add('Lựa chọn ${options.length + 1}');
    }

    options.shuffle(_random);
    return options;
  }


  Future<void> _playListeningAudio() async {
    if (_quizCards.isEmpty || _finished || _isPlayingListeningAudio) return;

    final card = _quizCards[_currentEssayIndex];
    setState(() => _isPlayingListeningAudio = true);

    try {
      await TtsAudioCache.instance.playText(
        text: card.term,
        languageCode: widget.courseLanguageCode.isNotEmpty
            ? widget.courseLanguageCode
            : 'zh-TW',
        courseId: widget.courseId,
      );
    } catch (e) {
      this._showMessage('Không phát được âm thanh');
      debugPrint('PLAY LISTENING TTS ERROR: $e');
    } finally {
      if (mounted) setState(() => _isPlayingListeningAudio = false);
    }
  }


  Future<void> _submitListeningAnswer() async {
    if (_quizCards.isEmpty || _finished) return;

    final selected = (_selectedListeningAnswer ?? '').trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (selected.isEmpty) {
      this._showMessage('Hãy chọn đáp án trước');
      return;
    }

    final card = _quizCards[_currentEssayIndex];
    final ok = this._acceptedListeningAnswersOf(
      card,
    ).contains(this._normalizeAnswer(selected));
    final wasLast = _currentEssayIndex + 1 >= _quizCards.length;

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = ok;
      _selectedAnswerMap[card.id] = selected;
      _finished = wasLast;
      if (!wasLast) {
        _currentEssayIndex++;
        _selectedListeningAnswer = null;
        _essayQuestionStartedAt = DateTime.now();
        _cardStartedAtMap[_quizCards[_currentEssayIndex].id] =
            _essayQuestionStartedAt;
      }
    });

    await this._recordStudyResult(card: card, answerText: selected, isCorrect: ok);

    if (_finished) {
      await this._finishStudySession();
      this._showResultSheet();
    } else {
      final isNextListening = _listening || (_sentenceMode && _currentEssayIndex % 3 == 2);
      Future.delayed(Duration(milliseconds: 220), () {
        if (mounted && isNextListening) this._playListeningAudio();
      });
    }
  }

}
