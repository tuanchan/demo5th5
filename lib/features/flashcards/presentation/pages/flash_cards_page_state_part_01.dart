part of flutterflashcard_main;

extension FlashCardsPageStatePart01 on _FlashCardsPageState {
  Widget _buildFlashCardsPagePage(BuildContext context) {
    final card = currentCard;

    return Scaffold(
      backgroundColor: Color(0xff000000),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                this.buildTopBar(),
                Expanded(
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.border,
                          ),
                        )
                      : flashcardTableVisible
                      ? this.buildVocabularyTableView()
                      : allCards.isEmpty
                      ? this.buildEmptyState(
                          title: "Học phần chưa có thẻ",
                          message:
                              "Hãy thêm thuật ngữ và định nghĩa cho học phần.",
                        )
                      : visibleOrder.isEmpty
                      ? Column(
                          children: [
                            Expanded(
                              child: this.buildEmptyState(
                                title: widget.dueOnly
                                    ? "Không có thẻ đến hạn"
                                    : "Không có thẻ phù hợp",
                                message: widget.dueOnly
                                    ? "Hôm nay chưa có thẻ đến hạn để học."
                                    : "Tắt chế độ chỉ học thẻ gắn sao hoặc gắn sao thêm thẻ.",
                              ),
                            ),
                            this.buildBottomBar(),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 700;
                                  return Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      compact ? 12 : 60,
                                      compact ? 12 : 36,
                                      compact ? 12 : 60,
                                      compact ? 8 : 16,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 840,
                                          maxHeight: double.infinity,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            this.buildPeekCard(),
                                            this.buildFlashCard(card!),
                                            if (showCompletion)
                                              this.buildCompletionOverlay(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            this.buildBottomBar(),
                          ],
                        ),
                ),
              ],
            ),
            if (courseDropdownOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      courseDropdownOpen = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.12),
                  ),
                ),
              ),
            if (courseDropdownOpen)
              Positioned(
                top: 70, // right under the top bar
                left: 14,
                right: 14,
                child: Container(
                  constraints: BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: courseList.length,
                      itemBuilder: (context, index) {
                        final course = courseList[index];
                        final isSelected = course.id == selectedCourseId;
                        return InkWell(
                          onTap: () async {
                            setState(() {
                              selectedCourseId = course.id;
                              courseDropdownOpen = false;
                            });
                            await this.loadCardsForCourse(course.id);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            color: isSelected
                                ? AppColors.blue.withOpacity(0.24)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    course.title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.text
                                          : AppColors.muted,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.border,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }





  Future<void> loadInitialData() async {
    await this.loadFlashSettings();
    setState(() {
      isLoading = true;
      selectedCourseId = widget.courseId;
    });

    await this._loadAllCourses();
    await this.loadCardsForCourse(widget.courseId);
  }





  Future<void> _loadAllCourses() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery('''
        SELECT 
          c.id,
          c.topicId,
          COALESCE(t.name, 'Chủ đề khác') AS topicName,
          c.title,
          c.languageCode,
          COUNT(cards.id) AS cardCount
        FROM courses c
        LEFT JOIN topics t
          ON t.id = c.topicId
          AND t.deletedAt IS NULL
        LEFT JOIN cards 
          ON cards.courseId = c.id 
          AND cards.deletedAt IS NULL
          AND cards.isHidden = 0
        WHERE c.deletedAt IS NULL
        GROUP BY c.id, c.topicId, t.name, c.title, c.languageCode
        ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
      ''');

      final loadedCourses = rows
          .map((e) => CourseListItem.fromMap(e))
          .toList();

      final savedSort = await AppSettingsStore.getString('home.courseSortType') ?? 'updatedDesc';
      final savedLanguage = await AppSettingsStore.getString('home.courseLanguageFilter') ?? 'all';

      var filtered = loadedCourses;
      if (savedLanguage.trim().toLowerCase() != 'all') {
        filtered = loadedCourses.where((course) {
          return course.languageCode.trim().toLowerCase() == savedLanguage.trim().toLowerCase();
        }).toList();
      }

      switch (savedSort) {
        case "az":
          filtered.sort(
            (a, b) => _naturalCompareText(a.title, b.title),
          );
          break;
        case "za":
          filtered.sort(
            (a, b) => _naturalCompareText(b.title, a.title),
          );
          break;
        case "cardsDesc":
          filtered.sort((a, b) => b.cardCount.compareTo(a.cardCount));
          break;
        case "cardsAsc":
          filtered.sort((a, b) => a.cardCount.compareTo(b.cardCount));
          break;
        default:
          break;
      }

      if (!mounted) return;
      setState(() {
        courseList = filtered;
      });
    } catch (e) {
      debugPrint('LOAD ALL COURSES ERROR: $e');
    }
  }





  Future<void> loadFlashSettings() async {
    final savedStarredOnly = await AppSettingsStore.getBool(
      'flash.starredOnly',
    );
    final savedShuffle = await AppSettingsStore.getBool('flash.shuffleEnabled');
    final savedProgress = await AppSettingsStore.getBool(
      'flash.progressTracking',
    );
    final savedAutoPlay = await AppSettingsStore.getBool('flash.autoPlayAudio');

    if (!mounted) return;

    setState(() {
      starredOnly = widget.dueOnly ? false : (savedStarredOnly ?? starredOnly);
      shuffleEnabled = savedShuffle ?? shuffleEnabled;
      progressTracking = widget.dueOnly
          ? true
          : (savedProgress ?? progressTracking);
      autoPlayAudio = savedAutoPlay ?? autoPlayAudio;
    });
  }





  Future<void> saveFlashSettings() async {
    await Future.wait([
      AppSettingsStore.setBool('flash.starredOnly', starredOnly),
      AppSettingsStore.setBool('flash.shuffleEnabled', shuffleEnabled),
      AppSettingsStore.setBool('flash.progressTracking', progressTracking),
      AppSettingsStore.setBool('flash.autoPlayAudio', autoPlayAudio),
    ]);
  }





  Future<void> _startStudySessionIfNeeded() async {
    if (!progressTracking || selectedCourseId == null || visibleOrder.isEmpty)
      return;

    await this._finishStudySession();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    _studySessionId = await db.insert('study_sessions', {
      'courseId': selectedCourseId,
      'mode': 'flashcard_progress',
      'totalCards': visibleOrder.length,
      'correctCount': 0,
      'wrongCount': 0,
      'startedAt': now.toIso8601String(),
      'endedAt': null,
    });
    _studySessionFinished = false;
  }





  Future<void> _finishStudySession() async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'study_sessions',
        {
          'correctCount': progressKnownCount,
          'wrongCount': progressUnknownCount,
          'endedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      _studySessionFinished = true;
    } catch (e) {
      debugPrint('FINISH FLASH SESSION ERROR: $e');
    }
  }





  Future<int?> _insertFlashStudyResult({
    required StudyCardItem card,
    required bool known,
  }) async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return null;

    try {
      final db = await AppDatabase.instance.database;
      return await db.insert('study_results', {
        'sessionId': sessionId,
        'cardId': card.id,
        'answerText': known ? 'known' : 'unknown',
        'isCorrect': known ? 1 : 0,
        'responseTimeMs': null,
        'reviewedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('INSERT FLASH RESULT ERROR: $e');
      return null;
    }
  }





  Future<void> _deleteFlashStudyResult(int? resultId, bool known) async {
    final sessionId = _studySessionId;
    if (resultId == null || sessionId == null) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.delete('study_results', where: 'id = ?', whereArgs: [resultId]);
      await db.update(
        'study_sessions',
        {
          'correctCount': progressKnownCount,
          'wrongCount': progressUnknownCount,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('DELETE FLASH RESULT ERROR: $e');
    }
  }


}
