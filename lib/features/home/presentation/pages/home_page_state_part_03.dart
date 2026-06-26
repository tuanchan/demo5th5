part of flutterflashcard_main;

extension HomePageStatePart03 on _HomePageState {
  Future<void> openCreateTopicDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border, width: 1.2),
          ),
          title: Text(
            "Tạo chủ đề",
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: "Tên chủ đề",
              filled: true,
              fillColor: AppColors.panel2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                final error = this.validateTopicName(name);
                if (error != null) {
                  this.showHomeMessage(error);
                  return;
                }

                await AppDatabase.instance.ensureTopicSchema();
                final duplicated = await this.isDuplicateTopicName(
                  name: name,
                );
                if (duplicated) {
                  this.showHomeMessage("Tên chủ đề đã tồn tại");
                  return;
                }

                final db = await AppDatabase.instance.database;
                final now = DateTime.now().toIso8601String();
                final topicId = await db.insert('topics', {
                  'name': name,
                  'createdAt': now,
                  'updatedAt': now,
                });

                if (!mounted) return;
                expandedTopicIds.add(topicId);
                Navigator.pop(dialogContext);
                await this.loadCourses();
                this.showHomeMessage("Đã tạo chủ đề");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.onAccentButton,
              ),
              child: Text("Tạo"),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }


  Future<void> openEditTopicDialog(CourseTopicItem topic) async {
    final controller = TextEditingController(text: topic.name);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.border, width: 1.2),
          ),
          title: Text(
            "Sửa chủ đề",
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: "Tên chủ đề",
              filled: true,
              fillColor: AppColors.panel2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                final error = this.validateTopicName(name);
                if (error != null) {
                  this.showHomeMessage(error);
                  return;
                }

                await AppDatabase.instance.ensureTopicSchema();
                final duplicated = await this.isDuplicateTopicName(
                  name: name,
                  ignoreTopicId: topic.id,
                );
                if (duplicated) {
                  this.showHomeMessage("Tên chủ đề đã tồn tại");
                  return;
                }

                final db = await AppDatabase.instance.database;
                await db.update(
                  'topics',
                  {
                    'name': name,
                    'updatedAt': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ? AND deletedAt IS NULL',
                  whereArgs: [topic.id],
                );

                if (!mounted) return;
                Navigator.pop(dialogContext);
                await this.loadCourses();
                this.showHomeMessage("Đã sửa chủ đề");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.onAccentButton,
              ),
              child: Text("Lưu"),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }


  Future<void> confirmDeleteTopic(CourseTopicItem topic) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Xóa chủ đề"),
          content: Text(
            topic.courseCount > 0
                ? "Xóa \"${topic.name}\"? Các học phần trong chủ đề này sẽ được chuyển sang \"Chủ đề khác\"."
                : "Xóa \"${topic.name}\"?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text("Xóa"),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await AppDatabase.instance.ensureTopicSchema();
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      final needsFallback = topic.courseCount > 0;
      final fallbackName =
          topic.name.trim().toLowerCase() == "chủ đề khác"
          ? "Chủ đề khác 2"
          : "Chủ đề khác";
      final fallbackTopicId = needsFallback
          ? await this.ensureTopicByName(
              db: db,
              name: fallbackName,
              now: now,
              ignoreTopicId: topic.id,
            )
          : null;

      await db.transaction((txn) async {
        if (fallbackTopicId != null) {
          await txn.update(
            'courses',
            {
              'topicId': fallbackTopicId,
              'updatedAt': now,
            },
            where: 'topicId = ? AND deletedAt IS NULL',
            whereArgs: [topic.id],
          );
        }

        await txn.delete(
          'topics',
          where: 'id = ?',
          whereArgs: [topic.id],
        );
      });

      expandedTopicIds.remove(topic.id);
      if (fallbackTopicId != null) expandedTopicIds.add(fallbackTopicId);
      if (!mounted) return;
      await this.loadCourses();
      this.showHomeMessage("Đã xóa chủ đề");
    } catch (e) {
      this.showHomeMessage("Xóa chủ đề thất bại");
      debugPrint("DELETE TOPIC ERROR: $e");
    }
  }


  Future<int> ensureTopicByName({
    required Database db,
    required String name,
    required String now,
    int? ignoreTopicId,
  }) async {
    final normalized = name.trim();
    final rows = await db.query(
      'topics',
      columns: ['id'],
      where: ignoreTopicId == null
          ? 'lower(trim(name)) = ? AND deletedAt IS NULL'
          : 'lower(trim(name)) = ? AND id != ? AND deletedAt IS NULL',
      whereArgs: ignoreTopicId == null
          ? [normalized.toLowerCase()]
          : [normalized.toLowerCase(), ignoreTopicId],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;

    return await db.insert('topics', {
      'name': normalized,
      'createdAt': now,
      'updatedAt': now,
    });
  }


  String? validateTopicName(String value) {
    final name = value.trim();
    if (name.isEmpty) return "Vui lòng nhập tên chủ đề";
    if (name.length < 2) return "Tên chủ đề phải có ít nhất 2 ký tự";
    if (name.length > 80) return "Tên chủ đề không được quá 80 ký tự";
    return null;
  }


  Future<bool> isDuplicateTopicName({
    required String name,
    int? ignoreTopicId,
  }) async {
    await AppDatabase.instance.ensureTopicSchema();
    final db = await AppDatabase.instance.database;
    final normalized = name.trim().toLowerCase();
    final rows = await db.query(
      'topics',
      columns: ['id'],
      where: ignoreTopicId == null
          ? 'lower(trim(name)) = ? AND deletedAt IS NULL'
          : 'lower(trim(name)) = ? AND id != ? AND deletedAt IS NULL',
      whereArgs: ignoreTopicId == null
          ? [normalized]
          : [normalized, ignoreTopicId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }


  Future<void> openEditCourseDialog(CourseListItem course) async {
    final controller = TextEditingController(text: course.title);
    String selectedLanguage = this.languageNameFromCode(course.languageCode);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: AppColors.border, width: 1.2),
              ),
              title: Text(
                "Sửa học phần",
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: "Tên học phần",
                        filled: true,
                        fillColor: AppColors.panel2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Ngôn ngữ học phần",
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLanguage,
                          isExpanded: true,
                          dropdownColor: AppColors.dropdownFill,
                          iconEnabledColor: AppColors.onIconButton,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          items: this.buildLanguageItems(),
                          onChanged: (value) {
                            if (value == null) return;
                            dialogSetState(() {
                              selectedLanguage = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newTitle = controller.text.trim();

                    final error = this.validateCourseTitle(newTitle);
                    if (error != null) {
                      this.showHomeMessage(error);
                      return;
                    }

                    final duplicated = await this.isDuplicateCourseTitle(
                      title: newTitle,
                      ignoreCourseId: course.id,
                    );

                    if (duplicated) {
                      this.showHomeMessage("Tên học phần đã tồn tại");
                      return;
                    }

                    final db = await AppDatabase.instance.database;
                    final now = DateTime.now().toIso8601String();
                    final oldLanguageCode = course.languageCode;
                    final newLanguageCode = this.languageCodeFromName(
                      selectedLanguage,
                    );
                    final languageChanged = oldLanguageCode != newLanguageCode;

                    await db.update(
                      'courses',
                      {
                        'title': newTitle,
                        'languageName': selectedLanguage,
                        'languageCode': newLanguageCode,
                        'updatedAt': now,
                      },
                      where: 'id = ? AND deletedAt IS NULL',
                      whereArgs: [course.id],
                    );

                    if (languageChanged) {
                      this.showHomeMessage(
                        "Đang tạo lại âm thanh cho ngôn ngữ mới...",
                      );

                      final cardRows = await db.query(
                        'cards',
                        where:
                            'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
                        whereArgs: [course.id],
                        orderBy: 'position ASC, id ASC',
                      );

                      final items = cardRows.map((row) {
                        return FlashCardItem(
                          term: row['term']?.toString() ?? '',
                          definition: row['definition']?.toString() ?? '',
                          pronunciation: row['pronunciation']?.toString() ?? '',
                        );
                      }).toList();

                      await TtsAudioCache.instance.deleteCourseAudioCache(
                        courseId: course.id,
                      );

                      await TtsAudioCache.instance.prepareCourseAudio(
                        items: items,
                        languageCode: newLanguageCode,
                        courseId: course.id,
                      );
                    }

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                    await this.loadCourses();
                    this.showHomeMessage(
                      languageChanged
                          ? "Đã đổi ngôn ngữ và tạo lại âm thanh"
                          : "Đã sửa học phần",
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.onAccentButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }


  Future<void> confirmDeleteCourse(CourseListItem course) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Xóa học phần"),
          content: Text("Bạn có chắc muốn xóa \"${course.title}\" không?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text("Xóa"),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      final db = await AppDatabase.instance.database;

      await TtsAudioCache.instance.deleteCourseAudioCache(courseId: course.id);

      await db.transaction((txn) async {
        await txn.delete(
          'study_results',
          where:
              'sessionId IN (SELECT id FROM study_sessions WHERE courseId = ?) OR cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [course.id, course.id],
        );
        await txn.delete(
          'study_sessions',
          where: 'courseId = ?',
          whereArgs: [course.id],
        );
        await txn.delete(
          'review_states',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [course.id],
        );
        await txn.delete(
          'card_examples',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [course.id],
        );
        await txn.delete(
          'cards',
          where: 'courseId = ?',
          whereArgs: [course.id],
        );
        await txn.delete(
          'course_tags',
          where: 'courseId = ?',
          whereArgs: [course.id],
        );
        await txn.delete(
          'import_exports',
          where: 'courseId = ?',
          whereArgs: [course.id],
        );
        await txn.delete('courses', where: 'id = ?', whereArgs: [course.id]);
      });

      await this.loadCourses();
      this.showHomeMessage("Đã xóa học phần khỏi app và DB");
    } catch (e) {
      this.showHomeMessage("Xóa thất bại");
      debugPrint("DELETE COURSE ERROR: $e");
    }
  }

}
