part of flutterflashcard_main;

extension HomePageStatePart02Split02 on _HomePageState {
  Widget _numberStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.3),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: Icon(Icons.add_rounded),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.border,
            activeTrackColor: AppColors.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }




  Widget _solidButton({
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
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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






  Future<void> openStatistics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatisticsPage()),
    );
  }





  Future<void> openSettingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage()),
    );
    if (mounted) setState(() {});
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
    if (mounted) {
      setState(() {
        isLoadingCourses = true;
      });
    }

    await this.loadCourseListSettings();

    try {
      final result = await BuiltInVocabularyImporter.importMissing();
      if (mounted && result.importedCourses > 0) {
        this.showHomeMessage(
          'Đã thêm ${result.importedCourses} học phần TOEIC/TOCFL (${result.importedCards} thẻ)',
        );
      }
    } catch (e) {
      debugPrint('BUILT-IN VOCABULARY IMPORT ERROR: $e');
    }

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
    if (!mounted) return;

    setState(() {
      isLoadingCourses = true;
    });

    try {
      final db = await AppDatabase.instance.database;

      final rows = await db.rawQuery('''
      SELECT 
        c.id,
        c.title,
        c.languageCode,
        COUNT(cards.id) AS cardCount
      FROM courses c
      LEFT JOIN cards 
        ON cards.courseId = c.id 
        AND cards.deletedAt IS NULL
        AND cards.isHidden = 0
      WHERE c.deletedAt IS NULL
      GROUP BY c.id, c.title, c.languageCode
      ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
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
        courseLanguageFilter = nextLanguageFilter;
        if (selectedHomeCourse != null) {
          final stillExists = courses.where(
            (e) => e.id == selectedHomeCourse!.id,
          );
          selectedHomeCourse = stillExists.isEmpty ? null : stillExists.first;
        }
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
