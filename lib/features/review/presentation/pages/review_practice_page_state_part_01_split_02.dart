part of flutterflashcard_main;

extension ReviewPracticePageStatePart01Split02 on _ReviewPracticePageState {
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
      if (SupabaseConfig.isLoggedIn) {
        await SupabaseSyncService.instance.syncReviewStatesAfterStudy();
      }
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
