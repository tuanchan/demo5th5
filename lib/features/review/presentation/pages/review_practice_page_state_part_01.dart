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
          backgroundColor: AppColors.activeIsDark ? AppColors.bg : Colors.white,
          foregroundColor: AppColors.text,
          title: Text('Ôn tập'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              widget.dueOnly
                  ? 'Hôm nay chưa có thẻ đến hạn để ôn tập'
                  : 'Học phần này chưa có thẻ để ôn tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w400,
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
                this._buildReviewStandardHeader(context),
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
                                            color: AppColors.activeIsDark ? AppColors.panel : Colors.white,
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
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Có ${_cards.length} thẻ. Chọn kiểu câu hỏi rồi bắt đầu.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: AppColors.muted,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.35,
                                                ),
                                              ),
                                              SizedBox(height: 20),
                                              this._solidButton(
                                                text: 'Thiết lập ôn tập',
                                                icon: Icons.tune_rounded,
                                                color: Color(0xff4257ff),
                                                onTap: this._openSetupSheet,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : _listening
                                  ? this._buildListeningMode()
                                  : _matchingPairs
                                  ? this._buildMatchingPairsMode()
                                  : _sentenceMode
                                  ? (_currentEssayIndex % 3 == 0
                                        ? this._buildSingleCardMultipleChoiceMode()
                                        : (_currentEssayIndex % 3 == 1
                                              ? this._buildEssayMode()
                                              : this._buildListeningMode()))
                                  : ((_essay || _sentenceMode) &&
                                            !_multipleChoice
                                        ? this._buildEssayMode()
                                        : this._buildMultipleChoiceMode()))),
                ),
              ],
            ),
            if (!_showSetup &&
                _quizCards.isNotEmpty &&
                _matchingPairs &&
                _finished)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xf20b0c10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xff242832)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: this._outlineButton(
                          text: 'Thoát',
                          icon: Icons.logout_rounded,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: this._solidButton(
                          text: 'Ôn lại',
                          icon: Icons.refresh_rounded,
                          color: Color(0xff4257ff),
                          onTap: this._restart,
                        ),
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

      List<Map<String, Object?>> rows;

      if (widget.dueOnly) {
        // Load due cards across all courses
        final now = DateTime.now();
        final tomorrowStart = DateTime(now.year, now.month, now.day).add(Duration(days: 1));
        rows = await db.rawQuery('''
          SELECT ca.* FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          INNER JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND COALESCE(rs.repetitionCount, 0) > 0
            AND rs.nextReviewAt IS NOT NULL
            AND rs.nextReviewAt < ?
          ORDER BY rs.nextReviewAt ASC, ca.position ASC, ca.id ASC
        ''', [tomorrowStart.toIso8601String()]);
      } else {
        rows = await db.query(
          'cards',
          where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
          whereArgs: [widget.courseId],
          orderBy: 'position ASC, id ASC',
        );
      }

      if (!mounted) return;

      // Apply presetMode if specified
      if (widget.presetMode != null) {
        setState(() {
          _multipleChoice = widget.presetMode == 'multipleChoice';
          _essay = widget.presetMode == 'essay';
          _listening = widget.presetMode == 'listening';
          _matchingPairs = widget.presetMode == 'matchingPairs';
          _sentenceMode = widget.presetMode == 'sentence';
          if (!_multipleChoice &&
              !_essay &&
              !_listening &&
              !_matchingPairs &&
              !_sentenceMode) {
            _multipleChoice = true;
          }
        });
      }

      setState(() {
        _cards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        _questionLimit = _cards.isEmpty
            ? 0
            : (widget.dueOnly && widget.presetMode != null
                  ? _cards.length
                  : (_questionLimit <= 0
                        ? _cards.length
                        : _questionLimit.clamp(1, _cards.length).toInt()));
        _isLoading = false;
      });

      if (_cards.isNotEmpty) {
        if (widget.presetMode != null) {
          // Auto-start quiz with preset mode
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) this._startQuiz();
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) this._openSetupSheet();
          });
        }
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
    final savedMatchingPairs = await AppSettingsStore.getBool(
      'review.matchingPairs',
    );
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
      _matchingPairs = savedMatchingPairs ?? _matchingPairs;
      _sentenceMode = savedSentenceMode ?? _sentenceMode;

      final activeModes = [
        _multipleChoice,
        _essay,
        _listening,
        _matchingPairs,
        _sentenceMode,
      ].where((e) => e).length;
      if (activeModes == 0) {
        _multipleChoice = true;
      }
      if (activeModes > 1) {
        _essay = false;
        _listening = false;
        _matchingPairs = false;
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
      AppSettingsStore.setBool('review.matchingPairs', _matchingPairs),
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


}
