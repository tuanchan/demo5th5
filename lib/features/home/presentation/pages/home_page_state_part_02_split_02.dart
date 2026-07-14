part of flutterflashcard_main;

extension HomePageStatePart02Split02 on _HomePageState {
  Widget _numberStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      height: 46,
      padding: EdgeInsets.only(left: 12, right: 5),
      decoration: BoxDecoration(
        color: Color(0x0fffffff),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xff2a334a)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$value',
              style: TextStyle(
                color: Color(0xffeaf1ff),
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: value >= max ? null : () => onChanged(value + 1),
                child: Icon(
                  Icons.arrow_drop_up_rounded,
                  size: 18,
                  color: value >= max
                      ? Color(0xff59657f)
                      : Color(0xffeaf1ff),
                ),
              ),
              InkWell(
                onTap: value <= min ? null : () => onChanged(value - 1),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: value <= min
                      ? Color(0xff59657f)
                      : Color(0xffeaf1ff),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }




  Widget _switchTile({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Color(0xffeaf1ff),
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
              ),
            ),
            AnimatedContainer(
              duration: Duration(milliseconds: 180),
              width: 56,
              height: 30,
              padding: EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? Color(0xf23e5cff) : Color(0x8094a3b8),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _solidButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w400),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }






  Future<void> openStatistics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatisticsPage()),
    );
  }

  Future<void> openWritingPractice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WritingPracticePage(
          initialCourseId: selectedHomeCourse?.id,
        ),
      ),
    );
  }





  Future<void> openSettingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage()),
    );
    if (!mounted) return;

    final activeSync = SupabaseSyncService.instance.activeSync;
    if (activeSync == null) {
      await this.loadCourses();
    }
    // If a sync is active, Home is refreshed by the service completion stream.
  }





  Future<void> openFlashCards([CourseListItem? course]) async {
    CourseListItem? targetCourse = course ?? selectedHomeCourse;

    if (targetCourse == null) {
      if (courses.isEmpty) {
        await this.loadCourses();
      }

      if (courses.length == 1) {
        targetCourse = courses.first;
      }
    }

    if (targetCourse == null) {
      setState(() {
        isOpen = true;
      });
      this.showHomeMessage("Hãy chọn học phần trong danh sách trước");
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashCardsPage(
          courseId: targetCourse!.id,
          courseTitle: targetCourse.title,
        ),
      ),
    );

    if (result == true) {
      await this.loadCourses();
    }
  }





  Future<void> loadInitialCourses() async {
    await this.loadCourseListSettings();

    await this.loadCourses();

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) this.showDueCardsReminderIfNeeded();
    });
  }





  Future<void> showDueCardsReminderIfNeeded() async {
    if (_duePopupShown) return;
    _duePopupShown = true;

    final info = await _loadDueReviewLaunchInfo();
    if (!mounted || info == null || info.count <= 0) return;

    final shouldOpen = await _showDueTodayReminderDialog(context, info);
    if (!mounted || shouldOpen != true) return;

    await _openDueReviewFlow(context, initialInfo: info);
    if (mounted) await this.loadCourses();
  }





  Future<void> loadCourses() async {
    if (!mounted || isLoadingCourses) return;

    setState(() {
      isLoadingCourses = true;
    });

    try {
      await AppDatabase.instance.ensureTopicSchema();
      await BuiltInVocabularyImporter.removeBundledDefaults();
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
      final topicRows = await db.rawQuery('''
        SELECT
          t.id,
          t.name,
          COUNT(DISTINCT c.id) AS courseCount,
          COUNT(cards.id) AS cardCount,
          MAX(COALESCE(c.updatedAt, c.createdAt, t.updatedAt, t.createdAt)) AS latestCourseAt
        FROM topics t
        LEFT JOIN courses c
          ON c.topicId = t.id
          AND c.deletedAt IS NULL
        LEFT JOIN cards
          ON cards.courseId = c.id
          AND cards.deletedAt IS NULL
          AND cards.isHidden = 0
        WHERE t.deletedAt IS NULL
        GROUP BY t.id, t.name
        HAVING COUNT(DISTINCT c.id) > 0
          OR lower(trim(t.name)) NOT IN ('chủ đề khác', 'toeic', 'tiếng trung b1')
        ORDER BY lower(t.name) ASC
      ''');

      debugPrint("DRAWER COURSES COUNT: ${rows.length}");
      debugPrint("DRAWER COURSES DATA: $rows");

      if (!mounted) return;

      final loadedCourses = rows
          .map((e) => CourseListItem.fromMap(e))
          .toList();
      final currentLanguages = loadedCourses
          .map((course) => course.languageCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet();
      var nextLanguageFilter = courseLanguageFilter;
      if (nextLanguageFilter != "all" &&
          !currentLanguages.contains(nextLanguageFilter.toLowerCase())) {
        nextLanguageFilter = "all";
        await AppSettingsStore.setString(
          _courseLanguageFilterSettingKey,
          nextLanguageFilter,
        );
      }

      if (!mounted) return;

      setState(() {
        courses = loadedCourses;
        topics = topicRows.map((e) => CourseTopicItem.fromMap(e)).toList();
        courseLanguageFilter = nextLanguageFilter;
        if (_activeHomeTopic != null) {
          final activeTopicId = _activeHomeTopic!.id;
          final stillExists = topics.where((topic) => topic.id == activeTopicId);
          _activeHomeTopic = stillExists.isEmpty ? null : stillExists.first;
        }
        if (selectedHomeCourse != null) {
          final stillExists = courses.where(
            (e) => e.id == selectedHomeCourse!.id,
          );
          selectedHomeCourse = stillExists.isEmpty ? null : stillExists.first;
        }
        if (expandedTopicIds.isEmpty && topics.isNotEmpty) {
          final selectedTopicId = selectedHomeCourse?.topicId;
          expandedTopicIds.add(selectedTopicId ?? topics.first.id);
        }
        expandedTopicIds.removeWhere(
          (id) => !topics.any((topic) => topic.id == id),
        );
        isLoadingCourses = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingCourses = false;
      });

      this.showHomeMessage("Không tải được học phần");
      debugPrint("LOAD COURSES ERROR: $e");
    }
  }





  void showHomeMessage(String text) {
    showAppToast(context, text);
  }


  String? validateCourseTitle(String value) {
    final title = value.trim();

    if (title.isEmpty) {
      return "Vui lòng nhập tên học phần";
    }

    if (title.length < 2) {
      return "Tên học phần phải có ít nhất 2 ký tự";
    }

    if (title.length > 80) {
      return "Tên học phần không được quá 80 ký tự";
    }

    return null;
  }





  Future<bool> isDuplicateCourseTitle({
    required String title,
    int? ignoreCourseId,
  }) async {
    final db = await AppDatabase.instance.database;
    final normalizedTitle = title.trim().toLowerCase();

    final rows = await db.query(
      'courses',
      columns: ['id'],
      where: ignoreCourseId == null
          ? 'lower(trim(title)) = ? AND deletedAt IS NULL'
          : 'lower(trim(title)) = ? AND id != ? AND deletedAt IS NULL',
      whereArgs: ignoreCourseId == null
          ? [normalizedTitle]
          : [normalizedTitle, ignoreCourseId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }





  String languageNameFromCode(String code) {
    switch (code) {
      case "zh-CN":
        return "Tiếng Trung Giản thể (Simplified Chinese)";
      case "en-US":
        return "Tiếng Anh (English)";
      case "de-DE":
        return "Tiếng Đức (German)";
      case "ja-JP":
        return "Tiếng Nhật (Japanese)";
      case "ko-KR":
        return "Tiếng Hàn (Korean)";
      case "vi-VN":
        return "Tiếng Việt (Vietnamese)";
      default:
        return "Tiếng Trung Phồn thể (Traditional Chinese)";
    }
  }





  String languageCodeFromName(String languageName) {
    if (languageName.contains("Giản thể")) return "zh-CN";
    if (languageName.contains("Anh")) return "en-US";
    if (languageName.contains("Đức")) return "de-DE";
    if (languageName.contains("Nhật")) return "ja-JP";
    if (languageName.contains("Hàn")) return "ko-KR";
    if (languageName.contains("Việt")) return "vi-VN";
    return "zh-TW";
  }

}
