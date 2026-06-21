part of flutterflashcard_main;

extension StatisticsPageStatePart06 on _StatisticsPageState {
  Widget _buildDueReviewButton(StatisticsData data) {
    final dueToday = data.dueScheduleItems.isEmpty
        ? 0
        : data.dueScheduleItems.first.count;

    return GestureDetector(
      onTap: () async {
        await _openDueReviewFlow(context);
        if (mounted) this.reloadStatistics();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: dueToday > 0 ? _dashBlue : _dashPanel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _dashBorder.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: _dashBorder.withOpacity(0.22),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Ôn những thẻ đến hạn',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _dashText,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }


  Widget _buildDueItem(ReviewDueItem item) {
    final intervalText = item.intervalDays > 0
        ? ' • ngày ${item.intervalDays}'
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.level >= ReviewScheduler.masteredLevel
                  ? AppColors.green
                  : (item.level > 0 ? AppColors.yellow : AppColors.red),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'L${item.level}',
                style: TextStyle(
                  color: AppColors.border,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${item.definition} • ${item.courseTitle} • ôn ${item.repetitionCount} lần$intervalText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800),
      ),
    );
  }


  Future<List<_SrsEditorItem>> _loadSrsEditorItems() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        ca.id AS cardId,
        c.id AS courseId,
        ca.term,
        ca.definition,
        c.title AS courseTitle,
        c.languageCode,
        COALESCE(rs.level, 0) AS level,
        COALESCE(rs.easeFactor, 2.5) AS easeFactor,
        COALESCE(rs.intervalDays, 0) AS intervalDays,
        COALESCE(rs.repetitionCount, 0) AS repetitionCount,
        COALESCE(rs.correctCount, 0) AS correctCount,
        COALESCE(rs.wrongCount, 0) AS wrongCount,
        COALESCE(rs.lastReviewedAt, '') AS lastReviewedAt,
        COALESCE(rs.nextReviewAt, '') AS nextReviewAt
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
      ORDER BY
        CASE WHEN rs.nextReviewAt IS NULL OR rs.nextReviewAt = '' THEN 1 ELSE 0 END,
        rs.nextReviewAt ASC,
        COALESCE(rs.level, 0) DESC,
        c.title ASC,
        ca.position ASC,
        ca.id ASC
      LIMIT 120
    ''');

    return rows.map(_SrsEditorItem.fromMap).toList();
  }


  Future<void> openSrsEditor() async {
    Future<List<_SrsEditorItem>> editorFuture = this._loadSrsEditorItems();
    final jsonController = TextEditingController();
    int? selectedCourseId;
    String selectedCourseTitle = '';
    bool courseDropdownOpen = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshEditor() async {
              setSheetState(() {
                editorFuture = this._loadSrsEditorItems();
              });
            }

            Future<void> runEditorTask(Future<String> Function() task) async {
              try {
                final message = await task();
                if (!context.mounted) return;
                showAppToast(context, message);
                await refreshEditor();
              } catch (e) {
                if (!context.mounted) return;
                showAppToast(context, 'Lỗi SRS: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 780),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: _dashPanel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _dashBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        offset: Offset(0, 18),
                        blurRadius: 34,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (selectedCourseId != null) ...[
                              IconButton(
                                onPressed: () {
                                  setSheetState(() {
                                    selectedCourseId = null;
                                    selectedCourseTitle = '';
                                    courseDropdownOpen = false;
                                  });
                                },
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: _dashText,
                                ),
                              ),
                              SizedBox(width: 4),
                            ],
                            Expanded(
                              child: selectedCourseId != null
                                ? GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        courseDropdownOpen = !courseDropdownOpen;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _dashPanel2,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: courseDropdownOpen
                                              ? _dashBlue
                                              : _dashBorder.withOpacity(0.72),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              selectedCourseTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _dashText,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          AnimatedRotation(
                                            turns: courseDropdownOpen ? -0.5 : 0,
                                            duration: Duration(milliseconds: 200),
                                            curve: Curves.easeInOut,
                                            child: SvgPicture.asset(
                                              'assets/icon/chevron-down-solid-full.svg',
                                              width: 14,
                                              height: 14,
                                              colorFilter: ColorFilter.mode(
                                                _dashText,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Chỉnh SRS',
                                    style: TextStyle(
                                      color: _dashText,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(
                                Icons.close_rounded,
                                color: _dashText,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dueSolidButton(
                                text: 'Export JSON',
                                icon: Icons.upload_file_rounded,
                                color: AppColors.green,
                                onTap: () => runEditorTask(this._exportSrsJson),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _dueOutlineButton(
                                text: 'Dán clipboard',
                                icon: Icons.content_paste_rounded,
                                onTap: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  jsonController.text = data?.text ?? '';
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: jsonController,
                          minLines: 2,
                          maxLines: 4,
                          style: TextStyle(
                            color: _dashText,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Dán JSON SRS vào đây để import',
                            hintStyle: TextStyle(color: _dashMuted),
                            filled: true,
                            fillColor: _dashPanel2,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _dashBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _dashBlue),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _dueSolidButton(
                            text: 'Import SRS',
                            icon: Icons.download_rounded,
                            color: AppColors.yellow,
                            onTap: () => runEditorTask(
                              () => this._importSrsJsonText(
                                jsonController.text,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Flexible(
                          child: FutureBuilder<List<_SrsEditorItem>>(
                            future: editorFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: _dashBlue,
                                    ),
                                  ),
                                );
                              }

                              final items = snapshot.data ?? [];
                              if (items.isEmpty) {
                                return SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: this._dashEmpty(
                                      'Chưa có thẻ để chỉnh SRS',
                                    ),
                                  ),
                                );
                              }

                              if (selectedCourseId == null) {
                                final courses = this._buildSrsEditorCourses(items);
                                return ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: 420),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: courses.length,
                                    itemBuilder: (context, index) {
                                      final course = courses[index];
                                      return this._buildSrsCourseItem(
                                        course,
                                        onOpen: () {
                                          setSheetState(() {
                                            selectedCourseId = course.id;
                                            selectedCourseTitle = course.title;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                );
                              }

                              final allCourses = this._buildSrsEditorCourses(items);
                              final courseItems = items
                                  .where((item) => item.courseId == selectedCourseId)
                                  .toList();

                              return ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: 420),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    AnimatedCrossFade(
                                      firstChild: SizedBox.shrink(),
                                      secondChild: Container(
                                        margin: EdgeInsets.only(bottom: 10),
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _dashPanel2,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _dashBorder.withOpacity(0.72),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: allCourses.map((course) {
                                            final isActive =
                                                course.id == selectedCourseId;
                                            return GestureDetector(
                                              onTap: () {
                                                setSheetState(() {
                                                  selectedCourseId = course.id;
                                                  selectedCourseTitle =
                                                      course.title;
                                                  courseDropdownOpen = false;
                                                });
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? _dashBlue
                                                          .withOpacity(0.18)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  course.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? _dashBlue
                                                        : _dashText,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      crossFadeState: courseDropdownOpen
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: Duration(milliseconds: 200),
                                    ),
                                    ...courseItems.map((item) {
                                      return this._buildSrsEditorItem(
                                        item,
                                        refreshEditor,
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
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

    jsonController.dispose();
    if (mounted) this.reloadStatistics();
  }


  List<_SrsEditorCourse> _buildSrsEditorCourses(List<_SrsEditorItem> items) {
    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day).add(
      Duration(days: 1),
    );
    final grouped = <int, List<_SrsEditorItem>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.courseId, () => <_SrsEditorItem>[]).add(item);
    }

    final courses = grouped.entries.map((entry) {
      final courseItems = entry.value;
      final first = courseItems.first;
      final reviewed = courseItems
          .where((item) => item.repetitionCount > 0)
          .length;
      final due = courseItems.where((item) {
        if (item.repetitionCount <= 0 || item.nextReviewAt.isEmpty) {
          return false;
        }
        final date = DateTime.tryParse(item.nextReviewAt);
        return date != null && date.isBefore(tomorrowStart);
      }).length;

      return _SrsEditorCourse(
        id: entry.key,
        title: first.courseTitle,
        languageCode: first.languageCode,
        cardCount: courseItems.length,
        reviewedCount: reviewed,
        dueCount: due,
      );
    }).toList();

    courses.sort((a, b) => _naturalCompareText(a.title, b.title));
    return courses;
  }


  Widget _buildSrsCourseItem(
    _SrsEditorCourse course, {
    required VoidCallback onOpen,
  }) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _dashPanel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _dashBorder.withOpacity(0.72)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '${course.cardCount} thẻ • đã ôn ${course.reviewedCount} • đến hạn ${course.dueCount} • ${course.languageCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: _dashText, size: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildSrsEditorItem(
    _SrsEditorItem item,
    Future<void> Function() refresh,
  ) {
    final dateText = this._formatSrsDate(item.nextReviewAt);

    Widget miniButton(IconData icon, Future<void> Function() onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await onTap();
          await refresh();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _dashPanel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _dashBorder),
          ),
          child: Icon(icon, color: _dashText, size: 18),
        ),
      );
    }

    Widget valuePill({
      required String text,
      required Color color,
    }) {
      return Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _dashBorder),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _dashText,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      );
    }

    Widget calendarButton() {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final now = DateTime.now();
          final current = DateTime.tryParse(item.nextReviewAt) ??
              DateTime(now.year, now.month, now.day);
          final picked = await showDatePicker(
            context: context,
            initialDate: current,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 3),
            builder: (ctx, child) {
              return Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: _dashBlue,
                    surface: _dashPanel,
                    onSurface: _dashText,
                    onPrimary: Colors.white,
                  ),
                  dialogTheme: DialogThemeData(
                    backgroundColor: _dashPanel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  textTheme: TextTheme(
                    bodyLarge: TextStyle(color: _dashText),
                    bodyMedium: TextStyle(color: _dashText),
                    titleSmall: TextStyle(color: _dashText),
                    labelLarge: TextStyle(color: _dashText),
                    headlineLarge: TextStyle(color: _dashText),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    labelStyle: TextStyle(color: _dashMuted),
                    hintStyle: TextStyle(color: _dashMuted),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _dashBorder),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _dashBlue),
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: _dashText,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            await this._setSrsDueDate(item, picked);
            await refresh();
          }
        },
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            Icons.calendar_month_rounded,
            color: _dashText,
            size: 20,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _dashPanel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dashBorder.withOpacity(0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.term,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 3),
          Text(
            '${item.definition} • ${item.courseTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _dashMuted, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Column(
            children: [
              Row(
                children: [
                  miniButton(
                    Icons.remove_rounded,
                    () => this._changeSrsLevel(item, -1),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: valuePill(
                      text: 'L${item.level}',
                      color: _dashBlue,
                    ),
                  ),
                  SizedBox(width: 8),
                  miniButton(
                    Icons.add_rounded,
                    () => this._changeSrsLevel(item, 1),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  miniButton(
                    Icons.chevron_left_rounded,
                    () => this._shiftSrsDate(item, -1),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: valuePill(text: dateText, color: _dashPanel)),
                  SizedBox(width: 8),
                  miniButton(
                    Icons.chevron_right_rounded,
                    () => this._shiftSrsDate(item, 1),
                  ),
                  SizedBox(width: 4),
                  calendarButton(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _changeSrsLevel(_SrsEditorItem item, int delta) async {
    final nextLevel = (item.level + delta).clamp(0, 8).toInt();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final interval = ReviewScheduler.intervalDaysForLevel(nextLevel);
    await this._upsertSrsState(
      cardId: item.cardId,
      level: nextLevel,
      intervalDays: interval,
      nextReviewAt: nextLevel <= 0 ? now : today.add(Duration(days: interval)),
    );
  }


  Future<void> _shiftSrsDate(_SrsEditorItem item, int days) async {
    final now = DateTime.now();
    final fallback = DateTime(now.year, now.month, now.day);
    final current = DateTime.tryParse(item.nextReviewAt) ?? fallback;
    final next = current.add(Duration(days: days));
    final today = DateTime(now.year, now.month, now.day);
    final interval = math.max(0, next.difference(today).inDays);
    await this._upsertSrsState(
      cardId: item.cardId,
      level: item.level,
      intervalDays: interval,
      nextReviewAt: next,
    );
  }


  Future<void> _setSrsDueDate(_SrsEditorItem item, DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final interval = math.max(0, target.difference(today).inDays);
    await this._upsertSrsState(
      cardId: item.cardId,
      level: item.level,
      intervalDays: interval,
      nextReviewAt: target,
    );
  }


  Future<void> _upsertSrsState({
    required int cardId,
    required int level,
    required int intervalDays,
    required DateTime nextReviewAt,
  }) async {
    final db = await AppDatabase.instance.database;
    await this._upsertSrsStateOn(
      db,
      cardId: cardId,
      level: level,
      easeFactor: null,
      intervalDays: intervalDays,
      repetitionCount: null,
      correctCount: null,
      wrongCount: null,
      lastReviewedAt: null,
      nextReviewAt: nextReviewAt,
    );
  }


  Future<void> _upsertSrsStateOn(
    DatabaseExecutor executor, {
    required int cardId,
    required int level,
    required double? easeFactor,
    required int intervalDays,
    required int? repetitionCount,
    required int? correctCount,
    required int? wrongCount,
    required String? lastReviewedAt,
    required DateTime nextReviewAt,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final rows = await executor.query(
      'review_states',
      where: 'cardId = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    final previous = rows.isEmpty ? null : rows.first;
    final nextLevel = level.clamp(0, 8).toInt();
    final nextRepetition = repetitionCount ??
        math.max(_dbInt(previous?['repetitionCount']), nextLevel > 0 ? 1 : 0);

    final values = <String, Object?>{
      'cardId': cardId,
      'level': nextLevel,
      'easeFactor': easeFactor ?? _dbDouble(previous?['easeFactor'], 2.5),
      'intervalDays': math.max(0, intervalDays),
      'repetitionCount': nextRepetition,
      'correctCount': correctCount ?? _dbInt(previous?['correctCount']),
      'wrongCount': wrongCount ?? _dbInt(previous?['wrongCount']),
      'lastReviewedAt': lastReviewedAt ??
          previous?['lastReviewedAt']?.toString() ??
          (nextRepetition > 0 ? nowIso : null),
      'nextReviewAt': nextReviewAt.toIso8601String(),
      'updatedAt': nowIso,
    };

    if (rows.isEmpty) {
      values['createdAt'] = nowIso;
      await executor.insert('review_states', values);
      return;
    }

    await executor.update(
      'review_states',
      values,
      where: 'cardId = ?',
      whereArgs: [cardId],
    );
  }


  Future<String> _exportSrsJson() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        ca.id AS cardId,
        c.id AS courseId,
        ca.term,
        ca.definition,
        c.title AS courseTitle,
        c.languageCode,
        COALESCE(rs.level, 0) AS level,
        COALESCE(rs.easeFactor, 2.5) AS easeFactor,
        COALESCE(rs.intervalDays, 0) AS intervalDays,
        COALESCE(rs.repetitionCount, 0) AS repetitionCount,
        COALESCE(rs.correctCount, 0) AS correctCount,
        COALESCE(rs.wrongCount, 0) AS wrongCount,
        COALESCE(rs.lastReviewedAt, '') AS lastReviewedAt,
        COALESCE(rs.nextReviewAt, '') AS nextReviewAt
      FROM review_states rs
      INNER JOIN cards ca ON ca.id = rs.cardId
      INNER JOIN courses c ON c.id = ca.courseId
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
      ORDER BY c.title ASC, ca.position ASC, ca.id ASC
    ''');
    final items = rows.map((row) => _SrsEditorItem.fromMap(row).toJson()).toList();
    final data = {
      'format': 'flutterflashcard.srs.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items,
    };
    final text = JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: text));

    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/srs_exports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/srs_${this._srsStamp()}.json');
    await file.writeAsString(text);

    await db.insert('import_exports', {
      'type': 'export',
      'fileName': file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'srs.json',
      'filePath': file.path,
      'format': 'json',
      'courseId': null,
      'status': 'success',
      'message': 'Export SRS JSON',
      'createdAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'FlashCard SRS JSON',
        text: 'SRS JSON để import lại lịch ôn.',
      );
    }

    return 'Đã export ${items.length} SRS, đã copy JSON vào clipboard';
  }


  Future<String> _importSrsJsonText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      throw FormatException('JSON đang trống');
    }

    final decoded = jsonDecode(text);
    final items = this._extractSrsImportItems(decoded);
    if (items.isEmpty) {
      throw FormatException('Không tìm thấy items SRS');
    }

    final db = await AppDatabase.instance.database;
    var imported = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      for (final item in items) {
        final cardId = await this._findSrsImportCardId(txn, item);
        if (cardId == null) {
          skipped++;
          continue;
        }

        final now = DateTime.now();
        final level = _dbInt(item['level']).clamp(0, 8).toInt();
        final interval = math.max(0, _dbInt(item['intervalDays']));
        final nextReviewAt =
            DateTime.tryParse(item['nextReviewAt']?.toString() ?? '') ??
            DateTime(now.year, now.month, now.day).add(
              Duration(days: interval),
            );

        await this._upsertSrsStateOn(
          txn,
          cardId: cardId,
          level: level,
          easeFactor: _dbDouble(item['easeFactor'], 2.5),
          intervalDays: interval,
          repetitionCount: _dbInt(item['repetitionCount']),
          correctCount: _dbInt(item['correctCount']),
          wrongCount: _dbInt(item['wrongCount']),
          lastReviewedAt: item['lastReviewedAt']?.toString(),
          nextReviewAt: nextReviewAt,
        );
        imported++;
      }

      await txn.insert('import_exports', {
        'type': 'import',
        'fileName': 'srs_json_clipboard',
        'filePath': null,
        'format': 'json',
        'courseId': null,
        'status': skipped == 0 ? 'success' : 'partial',
        'message': 'Import SRS JSON: $imported ok, $skipped bỏ qua',
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    return 'Đã import $imported SRS, bỏ qua $skipped thẻ không khớp';
  }


  List<Map<String, Object?>> _extractSrsImportItems(Object? decoded) {
    final source = decoded is Map ? decoded['items'] : decoded;
    if (source is! List) return [];

    return source
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }


  Future<int?> _findSrsImportCardId(
    DatabaseExecutor executor,
    Map<String, Object?> item,
  ) async {
    final term = item['term']?.toString().trim() ?? '';
    final definition = item['definition']?.toString().trim() ?? '';
    final courseTitle = item['courseTitle']?.toString().trim() ?? '';
    final languageCode = item['languageCode']?.toString().trim() ?? '';

    Future<int?> firstId(String sql, List<Object?> args) async {
      final rows = await executor.rawQuery(sql, args);
      if (rows.isEmpty) return null;
      final id = _dbInt(rows.first['id']);
      return id > 0 ? id : null;
    }

    if (term.isNotEmpty && definition.isNotEmpty && courseTitle.isNotEmpty) {
      final id = await firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
          AND lower(trim(c.title)) = lower(trim(?))
          AND (? = '' OR c.languageCode = ?)
          AND lower(trim(ca.term)) = lower(trim(?))
          AND lower(trim(ca.definition)) = lower(trim(?))
        LIMIT 1
        ''',
        [courseTitle, languageCode, languageCode, term, definition],
      );
      if (id != null) return id;
    }

    if (term.isNotEmpty && definition.isNotEmpty) {
      final id = await firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
          AND (? = '' OR c.languageCode = ?)
          AND lower(trim(ca.term)) = lower(trim(?))
          AND lower(trim(ca.definition)) = lower(trim(?))
        ORDER BY c.updatedAt DESC, c.createdAt DESC, ca.id ASC
        LIMIT 1
        ''',
        [languageCode, languageCode, term, definition],
      );
      if (id != null) return id;
    }

    final staleCardId = _dbInt(item['cardId']);
    if (staleCardId > 0) {
      return firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.id = ?
          AND ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
        LIMIT 1
        ''',
        [staleCardId],
      );
    }

    return null;
  }


  String _formatSrsDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return 'chưa có ngày';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }


  String _srsStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}


class _DueReviewLaunchInfo {
  final int count;
  final int courseId;
  final String courseTitle;
  final String languageCode;

  _DueReviewLaunchInfo({
    required this.count,
    required this.courseId,
    required this.courseTitle,
    required this.languageCode,
  });
}


enum _DueStudyAction { flash, review }


Future<_DueReviewLaunchInfo?> _loadDueReviewLaunchInfo() async {
  final db = await AppDatabase.instance.database;
  final now = DateTime.now();
  final tomorrowStart = DateTime(now.year, now.month, now.day).add(
    Duration(days: 1),
  );
  final dueBefore = tomorrowStart.toIso8601String();

  final countRows = await db.rawQuery(
    '''
    SELECT COUNT(*) AS count
    FROM cards ca
    INNER JOIN courses c ON c.id = ca.courseId
    INNER JOIN review_states rs ON rs.cardId = ca.id
    WHERE ca.deletedAt IS NULL
      AND ca.isHidden = 0
      AND c.deletedAt IS NULL
      AND COALESCE(rs.repetitionCount, 0) > 0
      AND rs.nextReviewAt IS NOT NULL
      AND rs.nextReviewAt < ?
    ''',
    [dueBefore],
  );

  final count = countRows.isEmpty ? 0 : _dbInt(countRows.first['count']);
  if (count <= 0) return null;

  final firstRows = await db.rawQuery(
    '''
    SELECT
      ca.courseId,
      c.title AS courseTitle,
      c.languageCode
    FROM cards ca
    INNER JOIN courses c ON c.id = ca.courseId
    INNER JOIN review_states rs ON rs.cardId = ca.id
    WHERE ca.deletedAt IS NULL
      AND ca.isHidden = 0
      AND c.deletedAt IS NULL
      AND COALESCE(rs.repetitionCount, 0) > 0
      AND rs.nextReviewAt IS NOT NULL
      AND rs.nextReviewAt < ?
    ORDER BY
      rs.nextReviewAt ASC,
      ca.position ASC,
      ca.id ASC
    LIMIT 1
    ''',
    [dueBefore],
  );

  if (firstRows.isEmpty) return null;
  final row = firstRows.first;

  return _DueReviewLaunchInfo(
    count: count,
    courseId: _dbInt(row['courseId']),
    courseTitle: row['courseTitle']?.toString() ?? '',
    languageCode: row['languageCode']?.toString() ?? 'zh-TW',
  );
}


Future<void> _openDueReviewFlow(
  BuildContext context, {
  _DueReviewLaunchInfo? initialInfo,
}) async {
  final info = initialInfo ?? await _loadDueReviewLaunchInfo();
  if (!context.mounted) return;

  if (info == null || info.count <= 0) {
    showAppToast(context, 'Hôm nay chưa có thẻ đến hạn');
    return;
  }

  final action = await _showDueStudyTypeDialog(context, info);
  if (!context.mounted || action == null) return;

  if (action == _DueStudyAction.flash) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashCardsPage(
          courseId: info.courseId,
          courseTitle: 'Thẻ đến hạn hôm nay',
          dueOnly: true,
        ),
      ),
    );
    return;
  }

  final presetMode = await _showDueReviewModeDialog(context);
  if (!context.mounted || presetMode == null) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReviewPracticePage(
        courseId: info.courseId,
        courseTitle: 'Ôn thẻ đến hạn hôm nay',
        courseLanguageCode: info.languageCode,
        dueOnly: true,
        presetMode: presetMode,
      ),
    ),
  );
}


Future<bool?> _showDueTodayReminderDialog(
  BuildContext context,
  _DueReviewLaunchInfo info,
) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 430),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: _dueDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: AppColors.border,
                size: 54,
              ),
              SizedBox(height: 10),
              Text(
                'Hôm nay có ${info.count} thẻ đến hạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có thể học flash card hoặc chọn kiểu kiểm tra để ôn ngay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _dueOutlineButton(
                      text: 'Đóng',
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _dueSolidButton(
                      text: 'Ôn tập',
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.green,
                      onTap: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}


Future<_DueStudyAction?> _showDueStudyTypeDialog(
  BuildContext context,
  _DueReviewLaunchInfo info,
) async {
  return showDialog<_DueStudyAction>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 460),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: _dueDialogDecoration(),
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
                          '${info.count} thẻ đến hạn hôm nay',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Chọn cách ôn tập',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close_rounded, color: AppColors.border),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _dueActionTile(
                title: 'Học thẻ',
                subtitle: 'Mở màn hình flash card chỉ gồm thẻ đến hạn.',
                icon: Icons.style_rounded,
                color: AppColors.yellow,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.flash),
              ),
              SizedBox(height: 12),
              _dueActionTile(
                title: 'Ôn tập',
                subtitle: 'Chọn phương thức kiểm tra cho thẻ đến hạn.',
                icon: Icons.school_rounded,
                color: AppColors.green,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.review),
              ),
            ],
          ),
        ),
      );
    },
  );
}


Future<String?> _showDueReviewModeDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: _dueDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn phương thức kiểm tra',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close_rounded, color: AppColors.border),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _dueActionTile(
                title: 'Trắc nghiệm 4 đáp án',
                subtitle: 'Chọn đáp án đúng cho từng thẻ.',
                icon: Icons.checklist_rounded,
                color: AppColors.blue,
                onTap: () => Navigator.pop(dialogContext, 'multipleChoice'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Tự luận',
                subtitle: 'Gõ câu trả lời rồi kiểm tra kết quả.',
                icon: Icons.edit_note_rounded,
                color: AppColors.green,
                onTap: () => Navigator.pop(dialogContext, 'essay'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Nghe',
                subtitle: 'Nghe âm thanh và chọn đáp án.',
                icon: Icons.hearing_rounded,
                color: AppColors.yellow,
                onTap: () => Navigator.pop(dialogContext, 'listening'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Kiểm tra đặt câu',
                subtitle: 'Tạo câu hỏi đặt câu từ thẻ đến hạn.',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.red,
                onTap: () => Navigator.pop(dialogContext, 'sentence'),
              ),
            ],
          ),
        ),
      );
    },
  );
}


BoxDecoration _dueDialogDecoration() {
  return BoxDecoration(
    color: Color(0xfff6f1fb),
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: AppColors.border, width: 1.4),
    boxShadow: [
      BoxShadow(color: AppColors.border, offset: Offset(0, 7), blurRadius: 0),
      BoxShadow(
        color: Color(0x26000000),
        offset: Offset(0, 18),
        blurRadius: 28,
      ),
    ],
  );
}


Widget _dueActionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.3),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Icon(icon, color: AppColors.border, size: 23),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppColors.border),
        ],
      ),
    ),
  );
}


Widget _dueSolidButton({
  required String text,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.border, size: 20),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.border,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


Widget _dueOutlineButton({
  required String text,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.border, size: 20),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.border,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
