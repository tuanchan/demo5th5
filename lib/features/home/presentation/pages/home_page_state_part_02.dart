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
    final initialTopicId =
        _activeHomeTopic?.id ?? selectedHomeCourse?.topicId;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCoursePage(initialTopicId: initialTopicId),
      ),
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
    final savedAnswerByDefinition = await AppSettingsStore.getBool('review.answerByDefinition') ?? true;
    final savedQuestionLimit = await AppSettingsStore.getInt('review.questionLimit') ?? 20;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (sheetContext) {
        int localLimit = savedQuestionLimit.clamp(1, targetCourse.cardCount).toInt();
        bool localMc = savedMultipleChoice;
        bool localEssay = savedEssay;
        bool localListening = savedListening;
        bool localMatchingPairs = savedMatchingPairs;
        bool localSentenceMode = false;
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

            final compactDialog = MediaQuery.sizeOf(context).width < 600;
            return Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(
                  left: compactDialog ? 12 : 18,
                  right: compactDialog ? 12 : 18,
                  top: compactDialog ? 12 : 18,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      (compactDialog ? 12 : 18),
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                    ),
                    padding: EdgeInsets.all(compactDialog ? 16 : 22),
                    decoration: BoxDecoration(
                      color: Color(0xff121828),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Color(0xff2a334a)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x59000000),
                          offset: Offset(0, 18),
                          blurRadius: 46,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Color(0xffa8b6d6),
                                        fontWeight: FontWeight.w900,
                                        fontSize: compactDialog ? 12 : 13,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Thiết lập bài kiểm tra',
                                      maxLines: compactDialog ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xffeaf1ff),
                                        fontSize: compactDialog ? 21 : 28,
                                        height: 1.15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Đóng',
                                onPressed: () => Navigator.pop(sheetContext),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xffa8b6d6),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                      SizedBox(height: 14),
                      this._setupRow(
                        label: 'Câu hỏi (tối đa ${targetCourse.cardCount})',
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
                          height: 46,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Color(0x0fffffff),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Color(0xff2a334a)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: localAnswerByDefinition,
                              isExpanded: true,
                              dropdownColor: Color(0xff121828),
                              style: TextStyle(
                                color: Color(0xffeaf1ff),
                                fontWeight: FontWeight.w800,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xffa8b6d6),
                              ),
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
                      Divider(color: Color(0xff2a334a)),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeepLearnPage(
                                courseId: targetCourse.id,
                                courseTitle: targetCourse.title,
                                courseLanguageCode: targetCourse.languageCode,
                              ),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 160),
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Color(0xff303a59),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/icon/brain-solid-full.svg',
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Học Chuyên Sâu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      this._switchTile(
                        text: 'Trắc nghiệm (4 đáp án)',
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
                        text: 'Ghép thẻ',
                        value: localMatchingPairs,
                        onChanged: (v) => setMode(matching: v),
                      ),
                      SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: this._solidButton(
                          text: 'Bắt đầu làm kiểm tra',
                          icon: Icons.play_arrow_rounded,
                          color: Color(0xff3e5cff),
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
                                builder: (_) => localSentenceMode
                                    ? DeepLearnPage(
                                        courseId: targetCourse.id,
                                        courseTitle: targetCourse.title,
                                        courseLanguageCode: targetCourse.languageCode,
                                      )
                                    : ReviewPracticePage(
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
            color: Color(0xffa8b6d6),
            fontWeight: FontWeight.w900,
            fontSize: 14,
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
