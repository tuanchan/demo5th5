part of flutterflashcard_main;

extension StatisticsPageStatePart02 on _StatisticsPageState {
  Future<StatisticsData> loadStatistics() async {
    final db = await AppDatabase.instance.database;
    await AppDatabase.instance.repairIncompleteReviewSchedules();
    await this._purgeSoftDeletedCourses(db);
    final nowDate = DateTime.now();
    final todayStart = DateTime(nowDate.year, nowDate.month, nowDate.day);
    final tomorrowStart = todayStart.add(Duration(days: 1));
    final todayStartIso = todayStart.toIso8601String();
    final tomorrowStartIso = tomorrowStart.toIso8601String();
    final dueTodayBeforeIso = tomorrowStartIso;
    final masteredLevel = ReviewScheduler.masteredLevel;

    final overviewRows = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM courses WHERE deletedAt IS NULL) AS totalCourses,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND c.deletedAt IS NULL
        ) AS totalCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          INNER JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND c.deletedAt IS NULL AND COALESCE(rs.level, 0) >= $masteredLevel
        ) AS masteredCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          INNER JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND COALESCE(rs.level, 0) > 0
            AND rs.nextReviewAt IS NOT NULL
            AND rs.nextReviewAt < ?
        ) AS needReviewCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND ca.isFavorite = 1 AND c.deletedAt IS NULL
        ) AS favoriteCards,
        (SELECT COUNT(*)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalSessions,
        (SELECT COALESCE(SUM(ss.correctCount), 0)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalCorrect,
        (SELECT COALESCE(SUM(ss.wrongCount), 0)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalWrong,
        (SELECT COUNT(*)
          FROM study_results sr
          INNER JOIN cards ca ON ca.id = sr.cardId
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND c.deletedAt IS NULL
        ) AS totalAnswered,
        (SELECT COUNT(DISTINCT sr.cardId)
          FROM study_results sr
          INNER JOIN cards ca ON ca.id = sr.cardId
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND sr.reviewedAt >= ?
            AND sr.reviewedAt < ?
        ) AS reviewedTodayCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          LEFT JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND COALESCE(rs.level, 0) < $masteredLevel
            AND COALESCE(rs.wrongCount, 0) > $_hardCardWrongThreshold
        ) AS hardCards
    ''',
      [dueTodayBeforeIso, todayStartIso, tomorrowStartIso],
    );

    final overview = overviewRows.isEmpty
        ? <String, Object?>{}
        : overviewRows.first;

    final courseRows = await db.rawQuery(
      '''
      SELECT
        c.id,
        c.title,
        c.languageCode,
        COUNT(ca.id) AS totalCards,
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) >= $masteredLevel THEN 1 ELSE 0 END), 0) AS masteredCards,
        COALESCE(SUM(CASE WHEN ca.id IS NOT NULL AND COALESCE(rs.level, 0) > 0 AND rs.nextReviewAt IS NOT NULL AND rs.nextReviewAt < ? THEN 1 ELSE 0 END), 0) AS needReviewCards,
        (
          SELECT COUNT(DISTINCT sr.cardId)
          FROM study_results sr
          INNER JOIN cards sca ON sca.id = sr.cardId
          WHERE sca.courseId = c.id
            AND sca.deletedAt IS NULL
            AND sca.isHidden = 0
            AND sr.reviewedAt >= ?
            AND sr.reviewedAt < ?
        ) AS reviewedTodayCards,
        (
          SELECT COUNT(DISTINCT sr.cardId)
          FROM study_results sr
          INNER JOIN cards sca ON sca.id = sr.cardId
          INNER JOIN review_states srs ON srs.cardId = sca.id
          WHERE sca.courseId = c.id
            AND sca.deletedAt IS NULL
            AND sca.isHidden = 0
            AND COALESCE(srs.level, 0) >= $masteredLevel
            AND sr.reviewedAt >= ?
            AND sr.reviewedAt < ?
        ) AS masteredTodayCards,
        COALESCE(SUM(rs.correctCount), 0) AS correctCount,
        COALESCE(SUM(rs.wrongCount), 0) AS wrongCount,
        (SELECT COUNT(*) FROM study_sessions ss WHERE ss.courseId = c.id) AS sessionCount,
        CAST(
          COALESCE(
            AVG(
              CASE
                WHEN ca.id IS NOT NULL THEN COALESCE(rs.level, 0)
                ELSE NULL
              END
            ),
            0
          ) AS INTEGER
        ) AS srsStars,
        COALESCE(SUM(CASE WHEN ca.id IS NOT NULL AND COALESCE(rs.level, 0) BETWEEN 1 AND 3 THEN 1 ELSE 0 END), 0) AS srsLearningCards,
        COALESCE(SUM(CASE WHEN ca.id IS NOT NULL AND COALESCE(rs.level, 0) BETWEEN 4 AND 6 THEN 1 ELSE 0 END), 0) AS srsSteadyCards,
        COALESCE(SUM(CASE WHEN ca.id IS NOT NULL AND COALESCE(rs.level, 0) >= 7 THEN 1 ELSE 0 END), 0) AS srsAdvancedCards
      FROM courses c
      LEFT JOIN cards ca
        ON ca.courseId = c.id
        AND ca.deletedAt IS NULL
        AND ca.isHidden = 0
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE c.deletedAt IS NULL
      GROUP BY c.id, c.title, c.languageCode
      ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
    ''',
      [
        dueTodayBeforeIso,
        todayStartIso,
        tomorrowStartIso,
        todayStartIso,
        tomorrowStartIso,
      ],
    );

    final dueRows = await db.rawQuery(
      '''
      SELECT
        ca.term,
        ca.definition,
        c.title AS courseTitle,
        COALESCE(rs.level, 0) AS level,
        COALESCE(rs.repetitionCount, 0) AS repetitionCount,
        COALESCE(rs.intervalDays, 0) AS intervalDays,
        rs.nextReviewAt
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      INNER JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
        AND COALESCE(rs.level, 0) > 0
        AND rs.nextReviewAt IS NOT NULL
        AND rs.nextReviewAt < ?
      ORDER BY
        rs.nextReviewAt ASC,
        ca.position ASC,
        ca.id ASC
      LIMIT 12
    ''',
      [dueTodayBeforeIso],
    );

    final srsRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) >= 7 THEN 1 ELSE 0 END), 0) AS advanced,
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) BETWEEN 4 AND 6 THEN 1 ELSE 0 END), 0) AS steady,
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) BETWEEN 1 AND 3 THEN 1 ELSE 0 END), 0) AS learning,
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) = 0 THEN 1 ELSE 0 END), 0) AS newCards
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
    ''');
    final srs = srsRows.isEmpty ? <String, Object?>{} : srsRows.first;

    // nextReviewAt can contain either a device-local ISO value or a timestamp
    // with a server timezone offset. Comparing those strings in SQLite puts
    // some cards on the wrong day, so normalize every value to local time.
    final scheduleRows = await db.rawQuery('''
      SELECT rs.nextReviewAt
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      INNER JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
        AND COALESCE(rs.level, 0) > 0
        AND rs.nextReviewAt IS NOT NULL
        AND TRIM(rs.nextReviewAt) <> ''
    ''');
    final scheduleCounts = List<int>.filled(7, 0);
    for (final row in scheduleRows) {
      final parsed = DateTime.tryParse(row['nextReviewAt']?.toString() ?? '');
      if (parsed == null) continue;
      final dueAt = parsed.toLocal();
      if (dueAt.isBefore(tomorrowStart)) {
        scheduleCounts[0]++;
        continue;
      }
      for (var i = 1; i < 7; i++) {
        final start = todayStart.add(Duration(days: i));
        final end = todayStart.add(Duration(days: i + 1));
        if (!dueAt.isBefore(start) && dueAt.isBefore(end)) {
          scheduleCounts[i]++;
          break;
        }
      }
    }

    final dueScheduleItems = List<DueScheduleItem>.generate(7, (i) {
      final date = todayStart.add(Duration(days: i));
      final label = i == 0
          ? 'Hôm nay'
          : i == 1
              ? 'Ngày mai'
              : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      return DueScheduleItem(label: label, count: scheduleCounts[i]);
    });

    final languageRows = await db.rawQuery('''
      SELECT c.languageCode, COUNT(ca.id) AS cardCount
      FROM courses c
      INNER JOIN cards ca
        ON ca.courseId = c.id
        AND ca.deletedAt IS NULL
        AND ca.isHidden = 0
      WHERE c.deletedAt IS NULL
      GROUP BY c.languageCode
      ORDER BY cardCount DESC, c.languageCode ASC
    ''');

    final activityRows = await db.rawQuery('''
      SELECT sr.cardId, sr.reviewedAt
      FROM study_results sr
      INNER JOIN cards ca ON ca.id = sr.cardId
      INNER JOIN courses c ON c.id = ca.courseId
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
        AND sr.reviewedAt IS NOT NULL
        AND TRIM(sr.reviewedAt) <> ''
    ''');
    int activityDayKey(DateTime date) =>
        date.year * 10000 + date.month * 100 + date.day;
    DateTime? storedActivityDay(Object? value) {
      final text = value?.toString().trim() ?? '';
      final match = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})',
      ).firstMatch(text);
      if (match == null) return null;
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final day = int.tryParse(match.group(3) ?? '');
      if (year == null || month == null || day == null) return null;
      final parsed = DateTime(year, month, day);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      return parsed;
    }

    final activityCardSets = <int, Set<int>>{};
    final activeDays = <DateTime>{};
    for (final row in activityRows) {
      // study_results historically sync their device-local wall clock through
      // a timestamptz column. Supabase appends +00:00 without changing those
      // clock fields. Calling toLocal() here shifts late-evening reviews into
      // the next calendar day, so activity must use the stored study date.
      final day = storedActivityDay(row['reviewedAt']);
      if (day == null) continue;
      final cardId = this._asInt(row['cardId']);
      final key = activityDayKey(day);
      activityCardSets.putIfAbsent(key, () => <int>{}).add(cardId);
      activeDays.add(day);
    }

    final sortedActiveDays = activeDays.toList()..sort();
    var longestActivityStreak = 0;
    var runningStreak = 0;
    DateTime? previousActiveDay;
    for (final day in sortedActiveDays) {
      if (previousActiveDay != null &&
          day.difference(previousActiveDay).inDays == 1) {
        runningStreak++;
      } else {
        runningStreak = 1;
      }
      longestActivityStreak = math.max(longestActivityStreak, runningStreak);
      previousActiveDay = day;
    }

    var currentActivityStreak = 0;
    var streakCursor = todayStart;
    if (!activeDays.contains(streakCursor)) {
      streakCursor = streakCursor.subtract(Duration(days: 1));
    }
    while (activeDays.contains(streakCursor)) {
      currentActivityStreak++;
      streakCursor = streakCursor.subtract(Duration(days: 1));
    }

    final activityItems = List<ActivityDayItem>.generate(7, (index) {
      final day = todayStart.subtract(Duration(days: 6 - index));
      final dayKey = activityDayKey(day);
      return ActivityDayItem(
        date: day,
        label: index == 6
            ? 'Hôm nay'
            : '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
        reviewCount: activityCardSets[dayKey]?.length ?? 0,
      );
    });

    return StatisticsData(
      totalCourses: this._asInt(overview['totalCourses']),
      totalCards: this._asInt(overview['totalCards']),
      masteredCards: this._asInt(overview['masteredCards']),
      needReviewCards: this._asInt(overview['needReviewCards']),
      favoriteCards: this._asInt(overview['favoriteCards']),
      totalSessions: this._asInt(overview['totalSessions']),
      totalCorrect: this._asInt(overview['totalCorrect']),
      totalWrong: this._asInt(overview['totalWrong']),
      totalAnswered: this._asInt(overview['totalAnswered']),
      reviewedTodayCards: this._asInt(overview['reviewedTodayCards']),
      hardCards: this._asInt(overview['hardCards']),
      srsItems: [
        SrsDistributionItem(
          label: 'Cấp 7-8',
          subtitle: 'Thành thạo',
          count: this._asInt(srs['advanced']),
          color: _dashBlue,
        ),
        SrsDistributionItem(
          label: 'Cấp 4-6',
          subtitle: 'Đang ổn tốt',
          count: this._asInt(srs['steady']),
          color: _dashPurple,
        ),
        SrsDistributionItem(
          label: 'Cấp 1-3',
          subtitle: 'Mới học',
          count: this._asInt(srs['learning']),
          color: _dashBlue,
        ),
        SrsDistributionItem(
          label: 'Cấp 0',
          subtitle: 'Chưa thuộc / Mới',
          count: this._asInt(srs['newCards']),
          color: _dashRed,
        ),
      ],
      dueScheduleItems: dueScheduleItems,
      languageItems: languageRows.asMap().entries.map((entry) {
        final row = entry.value;
        return LanguageDistributionItem(
          label: this._languageLabelFromCode(
            row['languageCode']?.toString() ?? '',
          ),
          count: this._asInt(row['cardCount']),
          color: this._languageColor(entry.key),
        );
      }).toList(),
      courseItems: courseRows.map((row) {
        return CourseStatisticsItem(
          id: this._asInt(row['id']),
          title: row['title']?.toString() ?? '',
          languageCode: row['languageCode']?.toString() ?? '',
          totalCards: this._asInt(row['totalCards']),
          masteredCards: this._asInt(row['masteredCards']),
          needReviewCards: this._asInt(row['needReviewCards']),
          reviewedTodayCards: this._asInt(row['reviewedTodayCards']),
          masteredTodayCards: this._asInt(row['masteredTodayCards']),
          correctCount: this._asInt(row['correctCount']),
          wrongCount: this._asInt(row['wrongCount']),
          sessionCount: this._asInt(row['sessionCount']),
          srsStars: this._asInt(row['srsStars']).clamp(0, 8).toInt(),
          srsLearningCards: this._asInt(row['srsLearningCards']),
          srsSteadyCards: this._asInt(row['srsSteadyCards']),
          srsAdvancedCards: this._asInt(row['srsAdvancedCards']),
        );
      }).toList(),
      dueItems: dueRows.map((row) {
        return ReviewDueItem(
          term: row['term']?.toString() ?? '',
          definition: row['definition']?.toString() ?? '',
          courseTitle: row['courseTitle']?.toString() ?? '',
          level: this._asInt(row['level']),
          repetitionCount: this._asInt(row['repetitionCount']),
          intervalDays: this._asInt(row['intervalDays']),
        );
      }).toList(),
      activityItems: activityItems,
      currentActivityStreak: currentActivityStreak,
      longestActivityStreak: longestActivityStreak,
    );
  }

  void reloadStatistics() {
    setState(() {
      _courseSrsLevelDraft.clear();
      _courseSrsDateDraft.clear();
      _future = this.loadStatistics();
      _srsManagerFuture = this._loadSrsEditorItems();
    });
  }

  Future<void> _refreshDashboard() async {
    if (!mounted || _isDashboardRefreshing) return;
    setState(() {
      _isDashboardRefreshing = true;
      _courseSrsLevelDraft.clear();
      _courseSrsDateDraft.clear();
    });

    final statisticsFuture = this.loadStatistics();
    final srsManagerFuture = this._loadSrsEditorItems();
    try {
      await Future.wait([statisticsFuture, srsManagerFuture]);
      if (!mounted) return;
      setState(() {
        // Both futures are already complete, so the current dashboard remains
        // visible during refresh and is replaced without a full-page spinner.
        _courseSrsLevelDraft.clear();
        _courseSrsDateDraft.clear();
        _future = statisticsFuture;
        _srsManagerFuture = srsManagerFuture;
      });
    } catch (error) {
      debugPrint('REFRESH SRS DASHBOARD ERROR: $error');
    } finally {
      if (mounted) setState(() => _isDashboardRefreshing = false);
    }
  }

  Widget _buildDashboard(StatisticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this._buildDashboardTopBar(),
        SizedBox(height: 8),
        SizedBox(
          height: 3,
          child: _isDashboardRefreshing
              ? LinearProgressIndicator(
                  minHeight: 3,
                  color: _dashBlue,
                  backgroundColor: _dashBorder.withOpacity(0.28),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(height: 13),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;

            if (wide) {
              return Column(
                children: [
                  this._dashRow(
                    [
                      this._buildSrsDistributionPanel(data),
                      this._buildDueSchedulePanel(data),
                      this._buildLanguageDistributionPanel(data),
                    ],
                    flexes: [3, 5, 4],
                  ),
                  SizedBox(height: 16),
                  this._buildLiveActivityPanel(data),
                  SizedBox(height: 16),
                  this._dashRow(
                    [
                      this._buildCourseStarsPanel(data),
                      this._buildCourseSrsCardsPanel(data),
                    ],
                    flexes: [1, 1],
                  ),
                ],
              );
            }

            return Column(
              children: [
                this._buildSrsDistributionPanel(data),
                SizedBox(height: 14),
                this._buildDueSchedulePanel(data),
                SizedBox(height: 14),
                this._buildLanguageDistributionPanel(data),
                SizedBox(height: 14),
                this._buildLiveActivityPanel(data),
                SizedBox(height: 14),
                this._buildCourseStarsPanel(data),
                SizedBox(height: 14),
                this._buildCourseSrsCardsPanel(data),
              ],
            );
          },
        ),
        SizedBox(height: 16),
        this._buildInlineSrsManager(data),
      ],
    );
  }

  Widget _buildDashboardTopBar() {
    return Row(
      children: [
        this._dashIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Dashboard SRS',
            style: TextStyle(
              color: _dashText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        this._dashIconButton(
          icon: Icons.refresh_rounded,
          onTap: this._refreshDashboard,
        ),
      ],
    );
  }

  Widget _dashIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(child: Icon(icon, color: _dashText, size: 24)),
      ),
    );
  }
}
