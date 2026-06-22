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
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "List Card",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
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
                                    color: AppColors.muted.withOpacity(
                                      0.75,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.panel,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.green,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 74,
                            height: 42,
                            child: PopupMenuButton<String>(
                              tooltip: "Lọc ngôn ngữ",
                              initialValue: courseLanguageFilter,
                              onSelected: (value) {
                                this.setCourseLanguageFilter(value);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: "all",
                                  child: Text("Tất cả ngôn ngữ"),
                                ),
                                ...courseLanguageFilters.map(
                                  (code) => PopupMenuItem(
                                    value: code,
                                    child: Text(
                                      "${this.languageNameFromCode(code)} • $code",
                                    ),
                                  ),
                                ),
                              ],
                              child: Container(
                                decoration: BoxDecoration(
                                  color: courseLanguageFilter == "all"
                                      ? AppColors.green
                                      : AppColors.blue,
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.translate_rounded,
                                    size: 20,
                                    color: AppColors.onIconButton,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            height: 42,
                            child: PopupMenuButton<String>(
                              tooltip: "Sắp xếp học phần",
                              initialValue: courseSortType,
                              onSelected: (value) {
                                this.setCourseSortType(value);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: "updatedDesc",
                                  child: Text("Mới nhất"),
                                ),
                                PopupMenuItem(
                                  value: "az",
                                  child: Text("A-Z"),
                                ),
                                PopupMenuItem(
                                  value: "za",
                                  child: Text("Z-A"),
                                ),
                                PopupMenuItem(
                                  value: "cardsDesc",
                                  child: Text("Nhiều thẻ nhất"),
                                ),
                                PopupMenuItem(
                                  value: "cardsAsc",
                                  child: Text("Ít thẻ nhất"),
                                ),
                              ],
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.yellow,
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 22,
                                    color: AppColors.onIconButton,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoadingCourses
                      ? Center(child: CircularProgressIndicator())
                      : courses.isEmpty
                      ? Center(
                          child: Text(
                            "Chưa có học phần nào",
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : visibleCourses.isEmpty
                      ? Center(
                          child: Text(
                            courseLanguageFilter == "all"
                                ? "Không tìm thấy học phần"
                                : "Không có học phần ngôn ngữ này",
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                          itemCount: visibleCourses.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final course = visibleCourses[index];
    
                            final isSelected =
                                selectedHomeCourse?.id == course.id;
    
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                10,
                                6,
                                10,
                                6,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  setState(() {
                                    selectedHomeCourse = course;
                                  });
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
                                  padding: EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    8,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.green
                                        : AppColors.panel2,
                                    borderRadius: BorderRadius.circular(
                                      18,
                                    ),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.25,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.border
                                            .withOpacity(
                                              isSelected ? 1 : 0.18,
                                            ),
                                        offset: Offset(
                                          0,
                                          isSelected ? 4 : 2,
                                        ),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course.title,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.text,
                                                fontWeight:
                                                    FontWeight.w900,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "${course.cardCount} thẻ • ${course.languageCode}",
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.text
                                                    .withOpacity(0.72),
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == "edit") {
                                            this.openEditCourseDialog(
                                              course,
                                            );
                                          }
    
                                          if (value == "delete") {
                                            this.confirmDeleteCourse(course);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: "edit",
                                            child: Text("Sửa"),
                                          ),
                                          PopupMenuItem(
                                            value: "delete",
                                            child: Text("Xóa"),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: this.openCreateCourse,
                            child: Text("Tạo Cards"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.onAccentButton,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.border,
                                  width: 1.3,
                                ),
                              ),
                            ),
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
                              side: BorderSide(
                                color: AppColors.border,
                                width: 1.3,
                              ),
                            ),
                          ),
                          child: Icon(Icons.menu),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
