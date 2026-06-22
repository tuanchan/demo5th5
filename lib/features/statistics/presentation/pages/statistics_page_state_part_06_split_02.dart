part of flutterflashcard_main;

extension StatisticsPageStatePart06Split02 on _StatisticsPageState {
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
                                            duration: getDuration(milliseconds: 200),
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
                                      duration: getDuration(milliseconds: 200),
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
      getDuration(days: 1),
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


}
