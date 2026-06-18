part of flutterflashcard_main;

extension ReviewPracticePageStatePart01 on _ReviewPracticePageState {
  Widget _buildReviewPracticePagePage(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.buttonInk,
          title: Text('Ôn tập'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Học phần này chưa có thẻ để ôn tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withOpacity(0.12),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SmallIcon3DButton(
                        icon: Icons.arrow_back_rounded,
                        color: Colors.white,
                        onTap: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$_done / $_displayTotal',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                            ),
                            Text(
                              widget.courseTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      SmallIcon3DButton(
                        icon: Icons.tune_rounded,
                        color: AppColors.yellow,
                        onTap: this._openSetupSheet,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isGeneratingSentenceQuiz
                      ? this._buildSentenceGeneratingMode()
                      : (_isGeminiTextGrading
                            ? this._buildGeminiTextGradingMode()
                            : (_showSetup || _quizCards.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(22),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: 460,
                                          ),
                                          padding: EdgeInsets.all(22),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.border,
                                                offset: Offset(0, 7),
                                                blurRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.school_outlined,
                                                color: AppColors.border,
                                                size: 56,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'Sẵn sàng ôn tập',
                                                style: TextStyle(
                                                  color: AppColors.text,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Có ${_cards.length} thẻ. Chọn kiểu câu hỏi rồi bắt đầu.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: AppColors.muted,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.35,
                                                ),
                                              ),
                                              SizedBox(height: 20),
                                              this._solidButton(
                                                text: 'Thiết lập ôn tập',
                                                icon: Icons.tune_rounded,
                                                color: AppColors.green,
                                                onTap: this._openSetupSheet,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : _listening
                                  ? this._buildListeningMode()
                                  : ((_essay || _sentenceMode) &&
                                            !_multipleChoice
                                        ? this._buildEssayMode()
                                        : this._buildMultipleChoiceMode()))),
                ),
              ],
            ),
            if (!_showSetup && _quizCards.isNotEmpty && _multipleChoice)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!_finished)
                        this._statChip(
                          text: 'Đã chọn $_done/$_total',
                          color: AppColors.blue,
                        ),
                      Spacer(),
                      this._solidButton(
                        text: _finished ? 'Xem kết quả' : 'Nộp bài',
                        icon: Icons.flag_rounded,
                        color: AppColors.yellow,
                        onTap: _finished
                            ? _showResultSheet
                            : this._submitMultipleChoice,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// ─── Pronunciation helpers ────────────────────────────────────────────────────


  Future<void> _loadCards() async {
    try {
      await this._loadReviewSettings();
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'cards',
        where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
        whereArgs: [widget.courseId],
        orderBy: 'position ASC, id ASC',
      );

      if (!mounted) return;

      setState(() {
        _cards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        _questionLimit = _cards.isEmpty
            ? 0
            : (_questionLimit <= 0
                  ? _cards.length
                  : _questionLimit.clamp(1, _cards.length).toInt());
        _isLoading = false;
      });

      if (_cards.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) this._openSetupSheet();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      this._showMessage('Không tải được thẻ ôn tập');
      debugPrint('LOAD REVIEW CARDS ERROR: $e');
    }
  }


  Future<void> _loadReviewSettings() async {
    final savedMultipleChoice = await AppSettingsStore.getBool(
      'review.multipleChoice',
    );
    final savedEssay = await AppSettingsStore.getBool('review.essay');
    final savedListening = await AppSettingsStore.getBool('review.listening');
    final savedSentenceMode = await AppSettingsStore.getBool(
      'review.sentenceMode',
    );
    final savedAnswerByDefinition = await AppSettingsStore.getBool(
      'review.answerByDefinition',
    );
    final savedQuestionLimit = await AppSettingsStore.getInt(
      'review.questionLimit',
    );

    if (!mounted) return;

    setState(() {
      _multipleChoice = savedMultipleChoice ?? _multipleChoice;
      _essay = savedEssay ?? _essay;
      _listening = savedListening ?? _listening;
      _sentenceMode = savedSentenceMode ?? _sentenceMode;

      final activeModes = [
        _multipleChoice,
        _essay,
        _listening,
        _sentenceMode,
      ].where((e) => e).length;
      if (activeModes == 0) {
        _multipleChoice = true;
      }
      if (activeModes > 1) {
        _essay = false;
        _listening = false;
        _sentenceMode = false;
        _multipleChoice = true;
      }

      _answerByDefinition = savedAnswerByDefinition ?? _answerByDefinition;
      if (savedQuestionLimit != null && savedQuestionLimit > 0) {
        _questionLimit = savedQuestionLimit;
      }
    });
  }


  Future<void> _saveReviewSettings() async {
    await Future.wait([
      AppSettingsStore.setBool('review.multipleChoice', _multipleChoice),
      AppSettingsStore.setBool('review.essay', _essay),
      AppSettingsStore.setBool('review.listening', _listening),
      AppSettingsStore.setBool('review.sentenceMode', _sentenceMode),
      AppSettingsStore.setBool(
        'review.answerByDefinition',
        _answerByDefinition,
      ),
      AppSettingsStore.setInt('review.questionLimit', _questionLimit),
    ]);
  }


  Future<void> _startStudySession({
    required String mode,
    required int totalCards,
  }) async {
    await this._finishStudySession();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    _sessionStartedAt = now;

    _studySessionId = await db.insert('study_sessions', {
      'courseId': widget.courseId,
      'mode': mode,
      'totalCards': totalCards,
      'correctCount': 0,
      'wrongCount': 0,
      'startedAt': now.toIso8601String(),
      'endedAt': null,
    });

    _studySessionFinished = false;
    _recordedResultCardIds.clear();
    _cardStartedAtMap
      ..clear()
      ..addEntries(_quizCards.map((card) => MapEntry(card.id, now)));
  }


  Future<void> _finishStudySession() async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'study_sessions',
        {
          'correctCount': _correct,
          'wrongCount': _wrong,
          'endedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      _studySessionFinished = true;
    } catch (e) {
      debugPrint('FINISH REVIEW SESSION ERROR: $e');
    }
  }


  Future<void> _markReviewStateForCard({
    required int cardId,
    required bool isCorrect,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    final rows = await db.query(
      'review_states',
      where: 'cardId = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    final previousState = rows.isEmpty
        ? null
        : Map<String, Object?>.from(rows.first);
    final nextState = ReviewScheduler.nextState(
      cardId: cardId,
      previous: previousState,
      isCorrect: isCorrect,
      now: now,
    );

    if (rows.isEmpty) {
      await db.insert('review_states', nextState);
      return;
    }

    await db.update(
      'review_states',
      nextState,
      where: 'cardId = ?',
      whereArgs: [cardId],
    );
  }


  Future<void> _recordStudyResult({
    required StudyCardItem card,
    required String answerText,
    required bool isCorrect,
  }) async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;
    if (_recordedResultCardIds.contains(card.id)) return;

    final now = DateTime.now();
    final startedAt = _cardStartedAtMap[card.id] ?? _essayQuestionStartedAt;
    final responseMs = now
        .difference(startedAt)
        .inMilliseconds
        .clamp(0, 2147483647);

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('study_results', {
        'sessionId': sessionId,
        'cardId': card.id,
        'answerText': answerText,
        'isCorrect': isCorrect ? 1 : 0,
        'responseTimeMs': responseMs,
        'reviewedAt': now.toIso8601String(),
      });

      await this._markReviewStateForCard(cardId: card.id, isCorrect: isCorrect);

      _recordedResultCardIds.add(card.id);

      await db.update(
        'study_sessions',
        {
          'correctCount': _correctMap.values.where((e) => e).length,
          'wrongCount':
              _answeredCards.length - _correctMap.values.where((e) => e).length,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('INSERT REVIEW RESULT ERROR: $e');
    }
  }

}
