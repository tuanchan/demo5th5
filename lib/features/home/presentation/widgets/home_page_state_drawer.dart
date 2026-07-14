part of flutterflashcard_main;

extension HomePageStateDrawer on _HomePageState {
  Widget _buildHomeCourseDrawer() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      left: isOpen ? 0 : -280,
      top: 0,
      bottom: 0,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
        opacity: isOpen ? 1 : 0.98,
        child: Container(
          width: 260,
          color: AppColors.panel,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                this._buildDrawerHeader(),
                Expanded(child: this._buildTopicCourseList()),
                this._buildDrawerFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "List Card",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: courseSearchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: "Tìm học phần...",
                      hintStyle: TextStyle(
                        color: AppColors.muted.withOpacity(0.75),
                        fontWeight: FontWeight.w700,
                      ),
                      filled: true,
                      fillColor: AppColors.panel,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.green, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              this._drawerPopupButton(
                tooltip: "Lọc ngôn ngữ",
                color: courseLanguageFilter == "all"
                    ? AppColors.green
                    : AppColors.blue,
                icon: Icons.translate_rounded,
                menu: PopupMenuButton<String>(
                  tooltip: "Lọc ngôn ngữ",
                  initialValue: courseLanguageFilter,
                  onSelected: (value) {
                    this.setCourseLanguageFilter(value);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: "all", child: Text("Tất cả ngôn ngữ")),
                    ...courseLanguageFilters.map(
                      (code) => PopupMenuItem(
                        value: code,
                        child: Text("${this.languageNameFromCode(code)} • $code"),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              this._drawerPopupButton(
                tooltip: "Sắp xếp học phần",
                color: AppColors.yellow,
                icon: Icons.tune_rounded,
                menu: PopupMenuButton<String>(
                  tooltip: "Sắp xếp học phần",
                  initialValue: courseSortType,
                  onSelected: (value) {
                    this.setCourseSortType(value);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: "updatedDesc", child: Text("Mới nhất")),
                    PopupMenuItem(value: "az", child: Text("A-Z")),
                    PopupMenuItem(value: "za", child: Text("Z-A")),
                    PopupMenuItem(
                      value: "cardsDesc",
                      child: Text("Nhiều thẻ nhất"),
                    ),
                    PopupMenuItem(
                      value: "cardsAsc",
                      child: Text("Ít thẻ nhất"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerPopupButton({
    required String tooltip,
    required Color color,
    required IconData icon,
    required PopupMenuButton<String> menu,
  }) {
    return SizedBox(
      width: 72,
      height: 42,
      child: PopupMenuButton<String>(
        tooltip: tooltip,
        initialValue: menu.initialValue,
        onSelected: menu.onSelected,
        itemBuilder: menu.itemBuilder,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 22, color: AppColors.onIconButton),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCourseList() {
    if (isLoadingCourses) {
      return Center(child: CircularProgressIndicator());
    }

    if (courses.isEmpty && topics.isEmpty) {
      return this._drawerEmptyText("Chưa có học phần nào");
    }

    if (visibleTopics.isEmpty) {
      return this._drawerEmptyText(
        courseLanguageFilter == "all"
            ? "Không tìm thấy học phần"
            : "Không có học phần ngôn ngữ này",
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
      itemCount: visibleTopics.length,
      itemBuilder: (context, index) {
        final topic = visibleTopics[index];
        final topicCourses = this.visibleCoursesForTopic(topic.id);
        final isExpanded = expandedTopicIds.contains(topic.id);

        return Padding(
          padding: EdgeInsets.fromLTRB(8, 5, 8, 5),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      expandedTopicIds.remove(topic.id);
                    } else {
                      expandedTopicIds.add(topic.id);
                    }
                  });
                },
                onLongPress: () => this.openEditTopicDialog(topic),
                child: Container(
                  padding: EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.25),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        color: AppColors.onIconButton,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          topic.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "edit") this.openEditTopicDialog(topic);
                          if (value == "delete") this.confirmDeleteTopic(topic);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: "edit", child: Text("Sửa")),
                          PopupMenuItem(value: "delete", child: Text("Xóa")),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${topic.courseCount}',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.more_vert_rounded,
                              color: AppColors.onIconButton,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                ...topicCourses.map((course) => this._buildCourseTile(course)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseTile(CourseListItem course) {
    final isSelected = selectedHomeCourse?.id == course.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 6, 0, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            selectedHomeCourse = course;
            isOpen = false;
          });
          this._navigateHomeToCourse(course.id);
        },
        onDoubleTap: () {
          setState(() {
            selectedHomeCourse = course;
          });
          this.openFlashCards(course);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.green : AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.15),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withOpacity(isSelected ? 1 : 0.14),
                offset: Offset(0, isSelected ? 4 : 2),
                blurRadius: 0,
              ),
            ],
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
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${course.cardCount} thẻ • ${course.languageCode}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text.withOpacity(0.72),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "edit") this.openEditCourseDialog(course);
                  if (value == "delete") this.confirmDeleteCourse(course);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: "edit", child: Text("Sửa")),
                  PopupMenuItem(value: "delete", child: Text("Xóa")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerEmptyText(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: this.openCreateTopicDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.onAccentButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.border, width: 1.3),
                  ),
                ),
                child: Text("Tạo chủ đề"),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 46,
            child: ElevatedButton(
              onPressed: this.closeMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.border, width: 1.3),
                ),
              ),
              child: Icon(Icons.menu),
            ),
          ),
        ],
      ),
    );
  }
}
