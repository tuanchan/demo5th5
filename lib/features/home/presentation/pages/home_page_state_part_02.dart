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
    final savedMatchingPairs = await AppSettingsStore.getBool('review.matchingPairs') ?? false;
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
        bool localMatchingPairs = savedMatchingPairs;
        bool localSentenceMode = savedSentenceMode;
        bool localAnswerByDefinition = savedAnswerByDefinition;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setMode({
              bool? mc,
              bool? essay,
              bool? listening,
              bool? matching,
              bool? sentence,
            }) {
              setSheetState(() {
                if (mc == true) {
                  localMc = true;
                  localEssay = false;
                  localListening = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (essay == true) {
                  localEssay = true;
                  localMc = false;
                  localListening = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (listening == true) {
                  localListening = true;
                  localMc = false;
                  localEssay = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (matching == true) {
                  localMatchingPairs = true;
                  localMc = false;
                  localEssay = false;
                  localListening = false;
                  localSentenceMode = false;
                  return;
                }

                if (sentence == true) {
                  localSentenceMode = true;
                  localMc = false;
                  localEssay = false;
                  localListening = false;
                  localMatchingPairs = false;
                  return;
                }

                localMc = true;
                localEssay = false;
                localListening = false;
                localMatchingPairs = false;
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
                    color: AppColors.popupFill,
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
                              color: AppColors.onIconButton,
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
                            color: AppColors.inputFill,
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
                              dropdownColor: AppColors.dropdownFill,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onIconButton),
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
                        text: 'Kiểm tra cặp thẻ',
                        value: localMatchingPairs,
                        onChanged: (v) => setMode(matching: v),
                      ),
                      this._switchTile(
                        text: 'Kiểm tra tổng hợp',
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
                              AppSettingsStore.setBool('review.matchingPairs', localMatchingPairs),
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
                            if (localMatchingPairs) presetMode = 'matchingPairs';
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

}
