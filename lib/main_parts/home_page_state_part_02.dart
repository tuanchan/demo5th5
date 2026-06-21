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

    if (targetCourse.cardCount == 0) {
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
      return;
    }

    await this._openReviewSetupSheet(targetCourse);
  }

  Future<void> _openReviewSetupSheet(CourseListItem targetCourse) async {
    final savedMultipleChoice = await AppSettingsStore.getBool('review.multipleChoice') ?? true;
    final savedEssay = await AppSettingsStore.getBool('review.essay') ?? false;
    final savedListening = await AppSettingsStore.getBool('review.listening') ?? false;
    final savedSentenceMode = await AppSettingsStore.getBool('review.sentenceMode') ?? false;
    final savedAnswerByDefinition = await AppSettingsStore.getBool('review.answerByDefinition') ?? true;
    final savedQuestionLimit = await AppSettingsStore.getInt('review.questionLimit') ?? 20;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetContext) {
        int localLimit = savedQuestionLimit.clamp(1, targetCourse.cardCount).toInt();
        bool localMc = savedMultipleChoice;
        bool localEssay = savedEssay;
        bool localListening = savedListening;
        bool localSentenceMode = savedSentenceMode;
        bool localAnswerByDefinition = savedAnswerByDefinition;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setMode({
              bool? mc,
              bool? essay,
              bool? listening,
              bool? sentence,
            }) {
              setSheetState(() {
                if (mc == true) {
                  localMc = true;
                  localEssay = false;
                  localListening = false;
                  localSentenceMode = false;
                  return;
                }

                if (essay == true) {
                  localEssay = true;
                  localMc = false;
                  localListening = false;
                  localSentenceMode = false;
                  return;
                }

                if (listening == true) {
                  localListening = true;
                  localMc = false;
                  localEssay = false;
                  localSentenceMode = false;
                  return;
                }

                if (sentence == true) {
                  localSentenceMode = true;
                  localMc = false;
                  localEssay = false;
                  localListening = false;
                  return;
                }

                localMc = true;
                localEssay = false;
                localListening = false;
                localSentenceMode = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 560),
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Color(0xfff6f1fb),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 7),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x26000000),
                        offset: Offset(0, 18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
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
                                  targetCourse.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Thiết lập ôn tập',
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
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.border,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      this._setupRow(
                        label: 'Câu hỏi tối đa ${targetCourse.cardCount}',
                        child: this._numberStepper(
                          value: localLimit,
                          min: 1,
                          max: targetCourse.cardCount,
                          onChanged: (value) =>
                              setSheetState(() => localLimit = value),
                        ),
                      ),
                      SizedBox(height: 12),
                      this._setupRow(
                        label: 'Trả lời bằng',
                        child: Container(
                          height: 48,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.3,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: localAnswerByDefinition,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded),
                              items: [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Tiếng Việt'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Thuật ngữ'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(
                                  () => localAnswerByDefinition = value,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Divider(color: AppColors.border.withOpacity(0.18)),
                      this._switchTile(
                        text: 'Trắc nghiệm 4 đáp án',
                        value: localMc,
                        onChanged: (v) => setMode(mc: v),
                      ),
                      this._switchTile(
                        text: 'Tự luận',
                        value: localEssay,
                        onChanged: (v) => setMode(essay: v),
                      ),
                      this._switchTile(
                        text: 'Nghe',
                        value: localListening,
                        onChanged: (v) => setMode(listening: v),
                      ),
                      this._switchTile(
                        text: 'Kiểm tra đặt câu',
                        value: localSentenceMode,
                        onChanged: (v) => setMode(sentence: v),
                      ),
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: this._solidButton(
                          text: 'Bắt đầu ôn tập',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.green,
                          onTap: () async {
                            await Future.wait([
                              AppSettingsStore.setBool('review.multipleChoice', localMc),
                              AppSettingsStore.setBool('review.essay', localEssay),
                              AppSettingsStore.setBool('review.listening', localListening),
                              AppSettingsStore.setBool('review.sentenceMode', localSentenceMode),
                              AppSettingsStore.setBool(
                                'review.answerByDefinition',
                                localAnswerByDefinition,
                              ),
                              AppSettingsStore.setInt('review.questionLimit', localLimit),
                            ]);

                            String presetMode = 'multipleChoice';
                            if (localEssay) presetMode = 'essay';
                            if (localListening) presetMode = 'listening';
                            if (localSentenceMode) presetMode = 'sentence';

                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewPracticePage(
                                  courseId: targetCourse.id,
                                  courseTitle: targetCourse.title,
                                  courseLanguageCode: targetCourse.languageCode,
                                  presetMode: presetMode,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _setupRow({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        final labelWidget = Text(
          label,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, SizedBox(height: 8), child],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            SizedBox(width: 210, child: child),
          ],
        );
      },
    );
  }

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
