part of flutterflashcard_main;

extension FlashCardsPageStatePart01Split02 on _FlashCardsPageState {
  Future<void> refreshRealtimeRows(RealtimeDataChange change) async {
    final selectedId = selectedCourseId;
    if (selectedId == null || !mounted) return;

    if (change.tables.contains('topics') ||
        change.tables.contains('courses') ||
        change.tables.contains('cards')) {
      await this._loadAllCourses();
    }

    if (change.tables.contains('courses') &&
        change.courseIds.contains(selectedId)) {
      final db = await AppDatabase.instance.database;
      final courseRows = await db.query(
        'courses',
        columns: ['languageCode'],
        where: 'id = ? AND deletedAt IS NULL',
        whereArgs: [selectedId],
        limit: 1,
      );
      if (mounted && courseRows.isNotEmpty) {
        setState(() {
          _languageCode =
              courseRows.first['languageCode']?.toString() ?? _languageCode;
        });
      }
    }

    final cardRowsChanged = change.tables.contains('cards');
    final dueStateChanged =
        widget.dueOnly && change.tables.contains('review_states');
    if ((!cardRowsChanged && !dueStateChanged) || change.cardIds.isEmpty) {
      return;
    }

    final db = await AppDatabase.instance.database;
    final oldCardId = currentCard?.id;
    final oldVisibleCardIds = visibleOrder
        .where((index) => index >= 0 && index < allCards.length)
        .map((index) => allCards[index].id)
        .toList(growable: false);
    final replacements = <int, StudyCardItem>{};
    final tomorrow = DateTime.now();
    final tomorrowStart = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    ).add(const Duration(days: 1));

    for (final cardId in change.cardIds) {
      List<Map<String, Object?>> rows;
      if (widget.dueOnly) {
        rows = await db.rawQuery(
          '''
          SELECT ca.*
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          INNER JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.id = ?
            AND ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND COALESCE(rs.repetitionCount, 0) > 0
            AND rs.nextReviewAt IS NOT NULL
            AND rs.nextReviewAt < ?
          LIMIT 1
          ''',
          [cardId, tomorrowStart.toIso8601String()],
        );
      } else {
        rows = await db.query(
          'cards',
          where: 'id = ? AND courseId = ? AND deletedAt IS NULL '
              'AND isHidden = 0',
          whereArgs: [cardId, selectedId],
          limit: 1,
        );
      }
      if (rows.isNotEmpty &&
          (widget.cardIds == null || widget.cardIds!.contains(cardId))) {
        replacements[cardId] = StudyCardItem.fromMap(rows.first);
      }
    }

    if (!mounted) return;
    setState(() {
      allCards.removeWhere((card) => change.cardIds.contains(card.id));
      allCards.addAll(replacements.values);
      allCards.sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
      });
      final indexByCardId = <int, int>{
        for (var i = 0; i < allCards.length; i++) allCards[i].id: i,
      };
      final eligibleIds = allCards
          .where((card) => !starredOnly || card.isFavorite)
          .map((card) => card.id)
          .toSet();
      final orderedIds = oldVisibleCardIds
          .where(eligibleIds.contains)
          .toList(growable: true);
      orderedIds.addAll(
        allCards
            .map((card) => card.id)
            .where((id) => eligibleIds.contains(id) && !orderedIds.contains(id)),
      );
      visibleOrder = orderedIds
          .map((id) => indexByCardId[id])
          .whereType<int>()
          .toList(growable: false);
      final preservedPosition = oldCardId == null
          ? -1
          : orderedIds.indexOf(oldCardId);
      currentPos = visibleOrder.isEmpty
          ? 0
          : (preservedPosition >= 0
              ? preservedPosition
              : currentPos.clamp(0, visibleOrder.length - 1));
      if (oldCardId != null && currentCard?.id != oldCardId) {
        isFlipped = false;
      }
      if (visibleOrder.isEmpty) showCompletion = false;
    });
  }

  Future<void> loadCardsForCourse(int? courseId) async {
    if (courseId == null) {
      if (!mounted) return;
      setState(() {
        allCards = [];
        visibleOrder = [];
        currentPos = 0;
        isLoading = false;
        showCompletion = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      showCompletion = false;
    });

    try {
      final db = await AppDatabase.instance.database;

      List<Map<String, Object?>> rows;
      String langCode;
      int? dueSessionCourseId;

      if (widget.cardIds != null && widget.cardIds!.isNotEmpty) {
        final placeholders = List.filled(widget.cardIds!.length, '?').join(',');
        rows = await db.rawQuery(
          '''
          SELECT * FROM cards
          WHERE courseId = ?
            AND deletedAt IS NULL
            AND isHidden = 0
            AND id IN ($placeholders)
          ORDER BY position ASC, id ASC
          ''',
          [courseId, ...widget.cardIds!],
        );
        final courseRows = await db.query(
          'courses',
          columns: ['languageCode'],
          where: 'id = ?',
          whereArgs: [courseId],
          limit: 1,
        );
        langCode = courseRows.isNotEmpty
            ? (courseRows.first['languageCode']?.toString() ?? 'zh-TW')
            : 'zh-TW';
      } else if (widget.dueOnly) {
        // Load due cards across all courses
        final now = DateTime.now();
        final tomorrowStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: 1));
        rows = await db.rawQuery(
          '''
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
        ''',
          [tomorrowStart.toIso8601String()],
        );

        // Get language from first due card's course
        if (rows.isNotEmpty) {
          final firstCourseId = rows.first['courseId'];
          dueSessionCourseId = _dbInt(firstCourseId);
          final courseRows = await db.query(
            'courses',
            columns: ['languageCode'],
            where: 'id = ?',
            whereArgs: [firstCourseId],
            limit: 1,
          );
          langCode = courseRows.isNotEmpty
              ? (courseRows.first['languageCode']?.toString() ?? 'zh-TW')
              : 'zh-TW';
        } else {
          langCode = 'zh-TW';
        }
      } else {
        rows = await db.query(
          'cards',
          where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
          whereArgs: [courseId],
          orderBy: 'position ASC, id ASC',
        );

        // Load languageCode from course
        final courseRows = await db.query(
          'courses',
          columns: ['languageCode'],
          where: 'id = ?',
          whereArgs: [courseId],
          limit: 1,
        );
        langCode = courseRows.isNotEmpty
            ? (courseRows.first['languageCode']?.toString() ?? 'zh-TW')
            : 'zh-TW';
      }

      if (!mounted) return;

      setState(() {
        allCards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        selectedCourseId = widget.dueOnly
            ? (dueSessionCourseId ?? courseId)
            : courseId;
        _languageCode = langCode;
        currentPos = 0;
        isFlipped = false;
        progressKnownCount = 0;
        progressUnknownCount = 0;
        _progressHistory.clear();
        _sessionUnknownCardIds.clear();
        this.rebuildVisibleOrder(resetPosition: true);
        isLoading = false;
      });

      await this._startStudySessionIfNeeded();
      this._playAutoAudioIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      this.showFlashMessage("Không tải được thẻ");
      debugPrint("LOAD FLASHCARDS ERROR: $e");
    }
  }

  void rebuildVisibleOrder({
    bool resetPosition = false,
    int? preserveCardId,
  }) {
    final oldCardId = preserveCardId ?? currentCard?.id;

    final indices = <int>[];
    for (int i = 0; i < allCards.length; i++) {
      if (!starredOnly || allCards[i].isFavorite) {
        indices.add(i);
      }
    }

    if (shuffleEnabled) {
      indices.shuffle();
    }

    int nextPos = 0;
    if (!resetPosition && oldCardId != null) {
      final found = indices.indexWhere((i) => allCards[i].id == oldCardId);
      if (found >= 0) nextPos = found;
    }

    visibleOrder = indices;
    currentPos = indices.isEmpty ? 0 : nextPos.clamp(0, indices.length - 1);
  }

  void resetFlip() {
    isFlipped = false;
  }

  void toggleFlip() {
    if (currentCard == null) return;

    setState(() {
      isFlipped = !isFlipped;
    });
  }

  Future<void> moveCard(
    int delta, {
    bool playSwipeEffect = true,
    bool resetSwipeState = false,
  }) async {
    if (currentCard == null) return;

    if (progressTracking) {
      await this.answerProgress(
        known: delta > 0,
        playSwipeEffect: playSwipeEffect,
        resetSwipeState: resetSwipeState,
      );
      return;
    }

    final nextPos = currentPos + delta;

    if (nextPos < 0) {
      if (resetSwipeState) {
        setState(() {
          isDraggingCard = false;
          cardDragDx = 0;
          cardDragDy = 0;
        });
      }
      this.showFlashMessage("Đang ở thẻ đầu tiên");
      return;
    }

    if (nextPos >= visibleOrder.length) {
      setState(() {
        showCompletion = true;
        if (resetSwipeState) {
          isDraggingCard = false;
          cardDragDx = 0;
          cardDragDy = 0;
        }
      });
      return;
    }

    setState(() {
      currentPos = nextPos;
      isFlipped = false;
      showCompletion = false;
      if (resetSwipeState) {
        isDraggingCard = false;
        cardDragDx = 0;
        cardDragDy = 0;
      }
    });

    this._playAutoAudioIfNeeded();
  }

  Future<void> answerProgress({
    required bool known,
    bool playSwipeEffect = true,
    bool resetSwipeState = false,
  }) async {
    final card = currentCard;
    if (card == null) return;

    final previousPos = currentPos;
    final previousCompletion = showCompletion;
    final recorded = await this.recordCurrentCardProgress(known);
    if (recorded == null) {
      this.showFlashMessage('Không lưu được tiến độ của thẻ');
      return;
    }
    final previousReviewState = recorded.previousReviewState;
    final studyResultId = recorded.studyResultId;
    final nextPos = currentPos + 1;
    final isDone = nextPos >= visibleOrder.length;

    setState(() {
      _progressHistory.add(
        ProgressUndoItem(
          cardId: card.id,
          previousPos: previousPos,
          previousCompletion: previousCompletion,
          known: known,
          previousReviewState: previousReviewState,
          studyResultId: studyResultId,
        ),
      );

      if (known) {
        progressKnownCount++;
      } else {
        progressUnknownCount++;
        _sessionUnknownCardIds.add(card.id);
      }

      isFlipped = false;

      if (isDone) {
        showCompletion = true;
      } else {
        currentPos = nextPos;
        showCompletion = false;
      }

      if (resetSwipeState) {
        isDraggingCard = false;
        cardDragDx = 0;
        cardDragDy = 0;
      }
    });

    if (isDone) {
      await this._finishStudySession();
    } else {
      this._playAutoAudioIfNeeded();
    }
  }

  void playGhost(bool reverse) {}

  Future<void> toggleStar() async {
    final card = currentCard;
    if (card == null) return;

    final nextValue = !card.isFavorite;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'cards',
        {
          'isFavorite': nextValue ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [card.id],
      );
      if (SupabaseConfig.isLoggedIn) {
        unawaited(SupabaseSyncService.instance.syncPendingChanges());
      }

      if (!mounted) return;

      setState(() {
        final index = allCards.indexWhere((e) => e.id == card.id);
        if (index >= 0) {
          allCards[index] = allCards[index].copyWith(isFavorite: nextValue);
        }
        this.rebuildVisibleOrder();
      });

      this.showFlashMessage(nextValue ? "Đã gắn sao" : "Đã bỏ sao");
    } catch (e) {
      this.showFlashMessage("Không cập nhật được sao");
      debugPrint("TOGGLE STAR ERROR: $e");
    }
  }
}
