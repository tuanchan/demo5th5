part of flutterflashcard_main;

extension HomePageStatePart02 on _HomePageState {
  Future<void> loadCourseListSettings() async {
    final savedSort = await AppSettingsStore.getString(_courseSortSettingKey);
    final savedLanguage = await AppSettingsStore.getString(
      _courseLanguageFilterSettingKey,
    );

    if (!mounted) return;

    setState(() {
      if (savedSort != null && _courseSortTypes.contains(savedSort)) {
        courseSortType = savedSort;
      }

      final language = savedLanguage?.trim();
      if (language != null && language.isNotEmpty) {
        courseLanguageFilter = language;
      }
    });
  }


  Future<void> setCourseSortType(String value) async {
    if (!_courseSortTypes.contains(value)) return;

    setState(() {
      courseSortType = value;
    });

    await AppSettingsStore.setString(_courseSortSettingKey, value);
  }


  Future<void> setCourseLanguageFilter(String value) async {
    setState(() {
      courseLanguageFilter = value.trim().isEmpty ? 'all' : value.trim();
    });

    await AppSettingsStore.setString(
      _courseLanguageFilterSettingKey,
      courseLanguageFilter,
    );
  }


  Future<void> toggleMenu() async {
    if (isOpen) {
      this.closeMenu();
      return;
    }

    await this.openMenu();
  }


  Future<void> openMenu() async {
    if (isOpen) return;

    setState(() {
      isOpen = true;
    });

    await this.loadCourses();
  }


  void closeMenu() {
    setState(() {
      isOpen = false;
    });
  }


  Future<void> openCreateCourse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateCoursePage()),
    );

    if (result == true) {
      await this.loadCourses();
    }
  }


  Future<void> openReviewPractice([CourseListItem? course]) async {
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewPracticePage(
          courseId: targetCourse!.id,
          courseTitle: targetCourse.title,
          courseLanguageCode: targetCourse.languageCode,
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


  List<DropdownMenuItem<String>> buildLanguageItems() {
    return [
      DropdownMenuItem(
        value: "Tiếng Trung Phồn thể (Traditional Chinese)",
        child: Text("Tiếng Trung Phồn thể"),
      ),
      DropdownMenuItem(
        value: "Tiếng Trung Giản thể (Simplified Chinese)",
        child: Text("Tiếng Trung Giản thể"),
      ),
      DropdownMenuItem(value: "Tiếng Anh (English)", child: Text("Tiếng Anh")),
      DropdownMenuItem(value: "Tiếng Đức (German)", child: Text("Tiếng Đức")),
      DropdownMenuItem(
        value: "Tiếng Nhật (Japanese)",
        child: Text("Tiếng Nhật"),
      ),
      DropdownMenuItem(value: "Tiếng Hàn (Korean)", child: Text("Tiếng Hàn")),
      DropdownMenuItem(
        value: "Tiếng Việt (Vietnamese)",
        child: Text("Tiếng Việt"),
      ),
    ];
  }

}
