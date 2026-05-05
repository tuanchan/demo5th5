import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/app_database.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class AppColors {
  static const bg = Color(0xffeef1f4);
  static const panel = Color(0xffffffff);
  static const panel2 = Color(0xfff7f9fc);
  static const border = Color(0xff1f3b63);
  static const text = Color(0xff183153);
  static const muted = Color(0xff6d7890);
  static const yellow = Color(0xfff5c400);
  static const green = Color(0xff8ee88b);
  static const red = Color(0xffff9f9f);
  static const blue = Color(0xffa1a7fb);
}

class FlashCardItem {
  final String term;
  final String definition;
  final String pronunciation;

  FlashCardItem({
    required this.term,
    required this.definition,
    this.pronunciation = '',
  });
}
class CourseListItem {
  final int id;
  final String title;
  final String languageCode;
  final int cardCount;

  CourseListItem({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.cardCount,
  });

  factory CourseListItem.fromMap(Map<String, Object?> map) {
    return CourseListItem(
      id: map['id'] as int,
      title: map['title']?.toString() ?? '',
      languageCode: map['languageCode']?.toString() ?? '',
      cardCount: map['cardCount'] as int? ?? 0,
    );
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOpen = false;

  bool isLoadingCourses = false;
  List<CourseListItem> courses = [];

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> toggleMenu() async {
  final nextOpen = !isOpen;

  setState(() {
    isOpen = nextOpen;
  });

  if (nextOpen) {
    await loadCourses();
  }
}

 
 void closeMenu() {
    setState(() {
      isOpen = false;
    });
  }

 Future<void> openCreateCourse() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CreateCoursePage(),
    ),
  );

  if (result == true) {
    await loadCourses();
  }
}

Future<void> openFlashCards() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const FlashCardsPage(),
    ),
  );

  if (result == true) {
    await loadCourses();
  }
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
      WHERE c.deletedAt IS NULL
      GROUP BY c.id, c.title, c.languageCode
      ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
    ''');

    debugPrint("DRAWER COURSES COUNT: ${rows.length}");
    debugPrint("DRAWER COURSES DATA: $rows");

    if (!mounted) return;

    setState(() {
      courses = rows.map((e) => CourseListItem.fromMap(e)).toList();
      isLoadingCourses = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isLoadingCourses = false;
    });

    showHomeMessage("Không tải được học phần");
    debugPrint("LOAD COURSES ERROR: $e");
  }
}
void showHomeMessage(String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: AppColors.border,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
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

Future<void> openEditCourseDialog(CourseListItem course) async {
  final controller = TextEditingController(text: course.title);

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Đổi tên"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: "Tên học phần",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();

              final error = validateCourseTitle(newTitle);
              if (error != null) {
                showHomeMessage(error);
                return;
              }

              final duplicated = await isDuplicateCourseTitle(
                title: newTitle,
                ignoreCourseId: course.id,
              );

              if (duplicated) {
                showHomeMessage("Tên học phần đã tồn tại");
                return;
              }

              final db = await AppDatabase.instance.database;
              final now = DateTime.now().toIso8601String();

              await db.update(
                'courses',
                {
                  'title': newTitle,
                  'updatedAt': now,
                },
                where: 'id = ? AND deletedAt IS NULL',
                whereArgs: [course.id],
              );

              if (!mounted) return;

              Navigator.pop(dialogContext);
              await loadCourses();
              showHomeMessage("Đã sửa học phần");
            },
            child: const Text("Lưu"),
          ),
        ],
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
        title: const Text("Xóa học phần"),
        content: Text("Bạn có chắc muốn xóa \"${course.title}\" không?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Xóa"),
          ),
        ],
      );
    },
  );

  if (result != true) return;

  try {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'courses',
      {
        'deletedAt': now,
        'updatedAt': now,
      },
      where: 'id = ? AND deletedAt IS NULL',
      whereArgs: [course.id],
    );

    await loadCourses();
    showHomeMessage("Đã xóa học phần");
  } catch (e) {
    showHomeMessage("Xóa thất bại");
    debugPrint("DELETE COURSE ERROR: $e");
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Big3DButton(
                          text: "Tạo Học Phần",
                          icon: Icons.create,
                          color: AppColors.yellow,
                          onTap: openCreateCourse,
                        ),
                        const SizedBox(height: 28),
                        Big3DButton(
                          text: "Flash Card",
                          icon: Icons.style_outlined,
                          color: AppColors.red,
                          onTap: openFlashCards,
                        ),
                        const SizedBox(height: 28),
                        Big3DButton(
                          text: "Ôn Tập",
                          icon: Icons.school,
                          color: AppColors.green,
                          onTap: () {},
                        ),
                        const SizedBox(height: 28),
                        Big3DButton(
                          text: "Cài Đặt",
                          icon: Icons.settings,
                          color: AppColors.blue,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          IgnorePointer(
  ignoring: !isOpen,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    opacity: isOpen ? 1 : 0,
    child: GestureDetector(
      onTap: closeMenu,
      child: Container(
        color: Colors.black.withOpacity(0.25),
      ),
    ),
  ),
),
          AnimatedPositioned(
  duration: const Duration(milliseconds: 360),
  curve: Curves.easeOutCubic,
  left: isOpen ? 0 : -280,
  top: 0,
  bottom: 0,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    opacity: isOpen ? 1 : 0.98,
    child: Container(
              width: 260,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 75,
                      width: double.infinity,
                      color: Colors.black,
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        "List Card",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
  child: isLoadingCourses
      ? const Center(
          child: CircularProgressIndicator(),
        )
      : courses.isEmpty
          ? const Center(
              child: Text(
                "Chưa có học phần nào",
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: courses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final course = courses[index];

                return ListTile(
                  leading: const Icon(
                    Icons.menu_book,
                    color: AppColors.border,
                  ),
                  title: Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    "${course.cardCount} thẻ • ${course.languageCode}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "edit") {
                        openEditCourseDialog(course);
                      }

                      if (value == "delete") {
                        confirmDeleteCourse(course);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: "edit",
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text("Sửa"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text("Xóa"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    closeMenu();
                    showHomeMessage("Đã chọn: ${course.title}");
                  },
                );
              },
            ),
),
Padding(
  padding: const EdgeInsets.all(12),
  child: Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: openCreateCourse,
            icon: const Icon(Icons.add),
            label: const Text("Thêm học phần"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: AppColors.border,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),

      const SizedBox(width: 8),

      SizedBox(
        width: 52,
        height: 46,
        child: ElevatedButton(
          onPressed: closeMenu,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: AppColors.border,
                width: 1.3,
              ),
            ),
          ),
          child: const Icon(Icons.menu),
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
          ),
          Positioned(
  left: 16,
  right: 16,
  bottom: 20,
  child: IgnorePointer(
    ignoring: isOpen,
    child: AnimatedSlide(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      offset: isOpen ? const Offset(0, 1.35) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        opacity: isOpen ? 0 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 18,
              sigmaY: 18,
            ),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: toggleMenu,
                    icon: const Icon(
                      Icons.menu,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.home,
                      size: 30,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.settings,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.person_outline,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
),
        ],
      ),
    );
  }
}

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final TextEditingController titleController = TextEditingController();

 final TextEditingController dataController = TextEditingController();

  final TextEditingController customTermSepController =
      TextEditingController(text: "|");

  final TextEditingController customCardSepController =
      TextEditingController(text: "###");

  String termSeparatorType = "tab";
  String cardSeparatorType = "newline";
  String selectedLanguage = "Tiếng Trung Phồn thể (Traditional Chinese)";

  bool showPreview = false;
  List<FlashCardItem> previewItems = [];

  @override
  void dispose() {
    titleController.dispose();
    dataController.dispose();
    customTermSepController.dispose();
    customCardSepController.dispose();
    super.dispose();
  }

  String getTermSeparator() {
    if (termSeparatorType == "tab") return "\t";
    if (termSeparatorType == "comma") return ",";
    return customTermSepController.text;
  }

  String getCardSeparator() {
    if (cardSeparatorType == "newline") return "\n";
    if (cardSeparatorType == "semicolon") return ";";
    return customCardSepController.text;
  }
String getLanguageCode() {
  if (selectedLanguage.contains("Giản thể")) return "zh-CN";
  if (selectedLanguage.contains("Anh")) return "en-US";
  if (selectedLanguage.contains("Đức")) return "de-DE";
  if (selectedLanguage.contains("Nhật")) return "ja-JP";
  if (selectedLanguage.contains("Hàn")) return "ko-KR";
  if (selectedLanguage.contains("Việt")) return "vi-VN";

  return "zh-TW";
}
  List<FlashCardItem> parseCards() {
  final text = dataController.text.trim();
  final termSep = getTermSeparator();
  final cardSep = getCardSeparator();

  if (text.isEmpty || termSep.isEmpty || cardSep.isEmpty) {
    return [];
  }

  final rawCards = text
      .split(cardSep)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final List<FlashCardItem> result = [];

  for (final raw in rawCards) {
    final parts = raw.split(termSep).map((e) => e.trim()).toList();

    if (parts.length >= 3) {
      result.add(
        FlashCardItem(
          term: parts[0].isEmpty ? "Chưa có thuật ngữ" : parts[0],
          pronunciation: parts[1],
          definition: parts.sublist(2).join(" "),
        ),
      );
      continue;
    }

    if (parts.length == 2) {
      final parsed = parseDefinitionAndPronunciation(parts[1]);

      result.add(
        FlashCardItem(
          term: parts[0].isEmpty ? "Chưa có thuật ngữ" : parts[0],
          definition: parsed.definition,
          pronunciation: parsed.pronunciation,
        ),
      );
      continue;
    }

    result.add(
      FlashCardItem(
        term: raw,
        definition: "Chưa có định nghĩa",
        pronunciation: "",
      ),
    );
  }

  return result;
}
    


ParsedDefinition parseDefinitionAndPronunciation(String raw) {
  final text = raw.trim();

  final regex = RegExp(r'^(.*?)\s*\(([^()]*)\)\s*$');
  final match = regex.firstMatch(text);

  if (match == null) {
    return ParsedDefinition(
      definition: text,
      pronunciation: '',
    );
  }

  return ParsedDefinition(
    definition: match.group(1)?.trim() ?? '',
    pronunciation: match.group(2)?.trim() ?? '',
  );
}



  void updatePreview() {
    setState(() {
      previewItems = parseCards();
      showPreview = true;
    });
  }

  Future<void> saveCourse() async {
  final title = titleController.text.trim();
  final rawText = dataController.text.trim();

  // 1. Validate tên học phần
  if (title.isEmpty) {
    showMessage("Vui lòng nhập tên học phần");
    return;
  }

  if (title.length < 2) {
    showMessage("Tên học phần phải có ít nhất 2 ký tự");
    return;
  }

  if (title.length > 80) {
    showMessage("Tên học phần không được quá 80 ký tự");
    return;
  }

  // 2. Validate dữ liệu nhập
  if (rawText.isEmpty) {
    showMessage("Vui lòng nhập dữ liệu thẻ");
    return;
  }

  // 3. Validate dấu phân cách
  if (getTermSeparator().isEmpty) {
    showMessage("Dấu phân cách thuật ngữ và định nghĩa không được rỗng");
    return;
  }

  if (getCardSeparator().isEmpty) {
    showMessage("Dấu phân cách giữa các thẻ không được rỗng");
    return;
  }

  final items = parseCards();

  // 4. Validate danh sách thẻ
  if (items.isEmpty) {
    showMessage("Chưa có thẻ nào để lưu");
    return;
  }

  // 5. Không cho lưu thẻ bị thiếu thuật ngữ / định nghĩa
  for (int i = 0; i < items.length; i++) {
    final item = items[i];

    if (item.term.trim().isEmpty || item.term == "Chưa có thuật ngữ") {
      showMessage("Thẻ số ${i + 1} bị thiếu thuật ngữ");
      return;
    }

    if (item.definition.trim().isEmpty ||
        item.definition == "Chưa có định nghĩa") {
      showMessage("Thẻ số ${i + 1} bị thiếu định nghĩa");
      return;
    }
  }

  

  final db = await AppDatabase.instance.database;
  final now = DateTime.now().toIso8601String();

  final normalizedTitle = title.trim().toLowerCase();

  // 7. Check trùng tên học phần
  final existed = await db.query(
    'courses',
    columns: ['id'],
    where: 'lower(trim(title)) = ? AND deletedAt IS NULL',
    whereArgs: [normalizedTitle],
    limit: 1,
  );

  if (existed.isNotEmpty) {
    showMessage("Tên học phần đã tồn tại, vui lòng nhập tên khác");
    return;
  }

  try {
    await db.transaction((txn) async {
      final courseId = await txn.insert('courses', {
        'title': title,
        'description': '',
        'languageName': selectedLanguage,
        'languageCode': getLanguageCode(),
        'cardCount': items.length,
        'isFavorite': 0,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      for (int i = 0; i < items.length; i++) {
        final item = items[i];

        await txn.insert('cards', {
          'courseId': courseId,
          'term': item.term.trim(),
          'definition': item.definition.trim(),
          'pronunciation': item.pronunciation.trim(),
          'rawText': '${item.term}\t${item.definition} (${item.pronunciation})',
          'inputFormat': 'auto',
          'position': i,
          'isFavorite': 0,
          'isHidden': 0,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      debugPrint("ĐÃ LƯU DB: courseId=$courseId");
      debugPrint("TỔNG THẺ VỪA LƯU: ${items.length}");
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Đã lưu học phần: $title (${items.length} thẻ)"),
        backgroundColor: AppColors.border,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Lưu xong tự quay về Home
    Navigator.pop(context, true);
  } catch (e) {
    showMessage("Lưu thất bại, vui lòng thử lại");
    debugPrint("SAVE COURSE ERROR: $e");
  }
}
  void showMessage(String text) {
  final messenger = ScaffoldMessenger.of(context);

  // Xóa thông báo cũ ngay lập tức
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: AppColors.border,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

  void openSettingPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void refresh() {
              modalSetState(() {});
              setState(() {});
            }

            return Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0x22000000),
                    offset: Offset(0, 20),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.settings,
                            color: AppColors.border,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Tùy chỉnh học phần",
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      CompactSelectBox(
                        title: "GIỮA THUẬT NGỮ VÀ ĐỊNH NGHĨA",
                        value: termSeparatorType,
                        items: const [
                          CompactSelectItem(value: "tab", label: "Tab"),
                          CompactSelectItem(value: "comma", label: "Phẩy ,"),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          termSeparatorType = value;
                          refresh();
                        },
                        customController: customTermSepController,
                        customHint: "vd: |",
                        showCustomInput: termSeparatorType == "custom",
                        onCustomChanged: (_) => refresh(),
                      ),

                      const SizedBox(height: 14),

                      CompactSelectBox(
                        title: "GIỮA CÁC THẺ",
                        value: cardSeparatorType,
                        items: const [
                          CompactSelectItem(value: "newline", label: "Dòng mới"),
                          CompactSelectItem(
                              value: "semicolon", label: "Chấm phẩy ;"),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          cardSeparatorType = value;
                          refresh();
                        },
                        customController: customCardSepController,
                        customHint: "vd: ###",
                        showCustomInput: cardSeparatorType == "custom",
                        onCustomChanged: (_) => refresh(),
                      ),

                      const SizedBox(height: 14),

                      buildLanguageSetting(modalSetState),

                      const SizedBox(height: 18),

                      BigPopupButton(
                        text: "Xong",
                        icon: Icons.check,
                        color: AppColors.green,
                        onTap: () {
                          Navigator.pop(context);
                        },
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

  Widget buildLanguageSetting(StateSetter modalSetState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle("NGÔN NGỮ HỌC PHẦN"),
          const SizedBox(height: 10),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedLanguage,
                isExpanded: true,
                dropdownColor: Colors.white,
                iconEnabledColor: AppColors.border,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Tiếng Trung Phồn thể (Traditional Chinese)",
                    child: Text("Tiếng Trung Phồn thể"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Trung Giản thể (Simplified Chinese)",
                    child: Text("Tiếng Trung Giản thể"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Anh (English)",
                    child: Text("Tiếng Anh"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Đức (German)",
                    child: Text("Tiếng Đức"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Nhật (Japanese)",
                    child: Text("Tiếng Nhật"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Hàn (Korean)",
                    child: Text("Tiếng Hàn"),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  modalSetState(() {
                    selectedLanguage = value;
                  });
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      "NHẬP DỮ LIỆU",
                    ),
                    const SizedBox(height: 8),
                    buildDataInput(),

                    if (showPreview) ...[
                      const SizedBox(height: 16),
                      buildPreviewTitle(),
                      const SizedBox(height: 8),
                      buildPreviewBox(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: AppColors.red,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LightInput(
              controller: titleController,
              hintText: "Tên học phần...",
              height: 48,
            ),
          ),
          const SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: AppColors.blue,
            onTap: openSettingPopup,
          ),
          const SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.visibility,
            color: AppColors.yellow,
            onTap: updatePreview,
          ),
          const SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.save,
            color: AppColors.green,
            onTap: saveCourse,
          ),
        ],
      ),
    );
  }

  Widget buildDataInput() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.58,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, 18),
            blurRadius: 26,
          ),
        ],
      ),
      child: TextField(
        controller: dataController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 15,
          height: 1.6,
          fontFamily: "monospace",
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: "Từ 1\tĐịnh nghĩa 1\nTừ 2\tĐịnh nghĩa 2\nTừ 3\tĐịnh nghĩa 3",
          hintStyle: TextStyle(
            color: AppColors.muted,
            fontFamily: "monospace",
          ),
        ),
      ),
    );
  }

  Widget buildPreviewTitle() {
    return Row(
      children: [
        const SectionTitle("XEM TRƯỚC"),
        const SizedBox(width: 8),
        Container(
          width: 26,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  Widget buildPreviewBox() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: previewItems.isEmpty
          ? const Center(
              child: Text(
                "Chưa có dữ liệu xem trước",
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Column(
              children: List.generate(previewItems.length, (index) {
                final item = previewItems[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: AppColors.border,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.term,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.definition,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}


class StudyCardItem {
  final int id;
  final int courseId;
  final String term;
  final String definition;
  final String pronunciation;
  final bool isFavorite;

  const StudyCardItem({
    required this.id,
    required this.courseId,
    required this.term,
    required this.definition,
    required this.pronunciation,
    required this.isFavorite,
  });

  factory StudyCardItem.fromMap(Map<String, Object?> map) {
    return StudyCardItem(
      id: map['id'] as int,
      courseId: map['courseId'] as int,
      term: map['term']?.toString() ?? '',
      definition: map['definition']?.toString() ?? '',
      pronunciation: map['pronunciation']?.toString() ?? '',
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
    );
  }

  StudyCardItem copyWith({
    String? term,
    String? definition,
    String? pronunciation,
    bool? isFavorite,
  }) {
    return StudyCardItem(
      id: id,
      courseId: courseId,
      term: term ?? this.term,
      definition: definition ?? this.definition,
      pronunciation: pronunciation ?? this.pronunciation,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class FlashCardsPage extends StatefulWidget {
  const FlashCardsPage({super.key});

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class _FlashCardsPageState extends State<FlashCardsPage>
    with TickerProviderStateMixin {
  late final AnimationController flipController;
  late final AnimationController ghostController;

  List<CourseListItem> courseList = [];
  List<StudyCardItem> allCards = [];
  List<int> visibleOrder = [];

  int? selectedCourseId;
  int currentPos = 0;

  bool isLoading = true;
  bool progressTracking = false;
  bool shuffleEnabled = false;
  bool starredOnly = false;
  bool isFlipped = false;
  bool ghostReverse = false;
  bool showCompletion = false;

  String ghostText = '';
  double cardDragDx = 0;
bool isDraggingCard = false;

  StudyCardItem? get currentCard {
    if (visibleOrder.isEmpty) return null;
    if (currentPos < 0 || currentPos >= visibleOrder.length) return null;
    final realIndex = visibleOrder[currentPos];
    if (realIndex < 0 || realIndex >= allCards.length) return null;
    return allCards[realIndex];
  }

  int get displayIndex => visibleOrder.isEmpty ? 0 : currentPos + 1;
  int get displayTotal => visibleOrder.length;
  bool get canPrev => currentPos > 0;
  bool get canNext => currentPos < visibleOrder.length - 1;

  @override
  void initState() {
    super.initState();

    flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );

    ghostController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    loadInitialData();
  }

  @override
  void dispose() {
    flipController.dispose();
    ghostController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final db = await AppDatabase.instance.database;

      final courseRows = await db.rawQuery('''
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

      final loadedCourses =
          courseRows.map((e) => CourseListItem.fromMap(e)).toList();

      if (!mounted) return;

      setState(() {
        courseList = loadedCourses;
        selectedCourseId = loadedCourses.isEmpty ? null : loadedCourses.first.id;
      });

      await loadCardsForCourse(selectedCourseId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showFlashMessage("Không tải được flash card");
      debugPrint("FLASHCARD LOAD ERROR: $e");
    }
  }

  Future<void> loadCardsForCourse(int? courseId) async {
    if (courseId == null) {
      if (!mounted) return;
      setState(() {
        allCards = [];
        visibleOrder = [];
        currentPos = 0;
        isLoading = false;
        showCompletion = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      showCompletion = false;
    });

    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'cards',
        where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
        whereArgs: [courseId],
        orderBy: 'position ASC, id ASC',
      );

      if (!mounted) return;

      setState(() {
        allCards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        currentPos = 0;
        isFlipped = false;
        flipController.value = 0;
        rebuildVisibleOrder(resetPosition: true);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showFlashMessage("Không tải được thẻ");
      debugPrint("LOAD FLASHCARDS ERROR: $e");
    }
  }

  void rebuildVisibleOrder({bool resetPosition = false}) {
    final oldCardId = currentCard?.id;

    final indices = <int>[];
    for (int i = 0; i < allCards.length; i++) {
      if (!starredOnly || allCards[i].isFavorite) {
        indices.add(i);
      }
    }

    if (shuffleEnabled) {
      indices.shuffle();
    }

    int nextPos = 0;
    if (!resetPosition && oldCardId != null) {
      final found = indices.indexWhere((i) => allCards[i].id == oldCardId);
      if (found >= 0) nextPos = found;
    }

    visibleOrder = indices;
    currentPos = indices.isEmpty ? 0 : nextPos.clamp(0, indices.length - 1);
  }

  void resetFlip() {
    isFlipped = false;
    flipController.reverse();
  }

  Future<void> toggleFlip() async {
    if (currentCard == null) return;

    setState(() {
      isFlipped = !isFlipped;
    });

    if (isFlipped) {
      await flipController.forward();
    } else {
      await flipController.reverse();
    }
  }

  Future<void> moveCard(int delta) async {
    if (currentCard == null) return;

    if (progressTracking) {
      await markCurrentCard(delta > 0);
    }

    final nextPos = currentPos + delta;

    if (nextPos < 0) {
      showFlashMessage("Đang ở thẻ đầu tiên");
      return;
    }

    if (nextPos >= visibleOrder.length) {
      setState(() {
        showCompletion = true;
      });
      return;
    }

    playGhost(delta < 0);

    setState(() {
      currentPos = nextPos;
      isFlipped = false;
      showCompletion = false;
    });

    flipController.value = 0;
  }

  void playGhost(bool reverse) {
    ghostController.stop();
    ghostController.reset();

    setState(() {
      ghostReverse = reverse;
      ghostText = currentCard?.term ?? '';
    });

    ghostController.forward();
  }

  Future<void> toggleStar() async {
    final card = currentCard;
    if (card == null) return;

    final nextValue = !card.isFavorite;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'cards',
        {
          'isFavorite': nextValue ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [card.id],
      );

      if (!mounted) return;

      setState(() {
        final index = allCards.indexWhere((e) => e.id == card.id);
        if (index >= 0) {
          allCards[index] = allCards[index].copyWith(isFavorite: nextValue);
        }
        rebuildVisibleOrder();
      });

      showFlashMessage(nextValue ? "Đã gắn sao" : "Đã bỏ sao");
    } catch (e) {
      showFlashMessage("Không cập nhật được sao");
      debugPrint("TOGGLE STAR ERROR: $e");
    }
  }

  Future<void> markCurrentCard(bool known) async {
    final card = currentCard;
    if (card == null) return;

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(
      'review_states',
      columns: ['id', 'correctCount', 'wrongCount', 'repetitionCount'],
      where: 'cardId = ?',
      whereArgs: [card.id],
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('review_states', {
        'cardId': card.id,
        'level': known ? 1 : 0,
        'easeFactor': 2.5,
        'intervalDays': known ? 1 : 0,
        'repetitionCount': 1,
        'correctCount': known ? 1 : 0,
        'wrongCount': known ? 0 : 1,
        'lastReviewedAt': now,
        'nextReviewAt': now,
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      final row = rows.first;
      await db.update(
        'review_states',
        {
          'level': known ? 1 : 0,
          'repetitionCount': (row['repetitionCount'] as int? ?? 0) + 1,
          'correctCount': (row['correctCount'] as int? ?? 0) + (known ? 1 : 0),
          'wrongCount': (row['wrongCount'] as int? ?? 0) + (known ? 0 : 1),
          'lastReviewedAt': now,
          'updatedAt': now,
        },
        where: 'cardId = ?',
        whereArgs: [card.id],
      );
    }

    showFlashMessage(known ? "Đã thuộc" : "Đang học");
  }

  Future<void> openEditCardDialog() async {
    final card = currentCard;
    if (card == null) return;

    final termController = TextEditingController(text: card.term);
    final definitionController = TextEditingController(text: card.definition);
    final pronunciationController =
        TextEditingController(text: card.pronunciation);

    final result = await showDialog<StudyCardItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Sửa thẻ"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LightInput(
                  controller: termController,
                  hintText: "Thuật ngữ",
                  height: 1,
                ),
                const SizedBox(height: 12),
                LightInput(
                  controller: definitionController,
                  hintText: "Định nghĩa",
                  height: 3,
                ),
                const SizedBox(height: 12),
                LightInput(
                  controller: pronunciationController,
                  hintText: "Phiên âm",
                  height: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () {
                final term = termController.text.trim();
                final definition = definitionController.text.trim();
                final pronunciation = pronunciationController.text.trim();

                if (term.isEmpty || definition.isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  card.copyWith(
                    term: term,
                    definition: definition,
                    pronunciation: pronunciation,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.border,
              ),
              child: const Text("Lưu"),
            ),
          ],
        );
      },
    );

    termController.dispose();
    definitionController.dispose();
    pronunciationController.dispose();

    if (result == null) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'cards',
        {
          'term': result.term,
          'definition': result.definition,
          'pronunciation': result.pronunciation,
          'rawText': '${result.term}\t${result.definition} (${result.pronunciation})',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [result.id],
      );

      if (!mounted) return;

      setState(() {
        final index = allCards.indexWhere((e) => e.id == result.id);
        if (index >= 0) {
          allCards[index] = result;
        }
      });

      showFlashMessage("Đã sửa thẻ");
    } catch (e) {
      showFlashMessage("Sửa thẻ thất bại");
      debugPrint("EDIT CARD ERROR: $e");
    }
  }

  void toggleShuffle() {
    setState(() {
      shuffleEnabled = !shuffleEnabled;
      rebuildVisibleOrder(resetPosition: true);
      resetFlip();
    });
  }

  void toggleStarredOnly() {
    setState(() {
      starredOnly = !starredOnly;
      rebuildVisibleOrder(resetPosition: true);
      resetFlip();
    });
  }

  void toggleProgressMode() {
    setState(() {
      progressTracking = !progressTracking;
    });
  }

  void restartStudy() {
    setState(() {
      currentPos = 0;
      showCompletion = false;
      rebuildVisibleOrder(resetPosition: true);
      resetFlip();
    });
  }

  void showFlashMessage(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppColors.border,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget settingRow({
              required String title,
              required bool value,
              required VoidCallback onTap,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    onTap();
                    setSheetState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.panel2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 26,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: value ? AppColors.border : AppColors.muted,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment:
                              value ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const Text(
                      "Cài đặt Flash Card",
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    settingRow(
                      title: "Theo dõi tiến độ",
                      value: progressTracking,
                      onTap: toggleProgressMode,
                    ),
                    settingRow(
                      title: "Chỉ học thẻ đã gắn sao",
                      value: starredOnly,
                      onTap: toggleStarredOnly,
                    ),
                    settingRow(
                      title: "Trộn thẻ",
                      value: shuffleEnabled,
                      onTap: toggleShuffle,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteCurrentCard() async {
    final card = currentCard;
    if (card == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Xóa thẻ"),
          content: Text("Xóa thẻ \"${card.term}\"?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Xóa"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        'cards',
        {
          'deletedAt': now,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [card.id],
      );

      await loadCardsForCourse(selectedCourseId);
      showFlashMessage("Đã xóa thẻ");
    } catch (e) {
      showFlashMessage("Xóa thẻ thất bại");
      debugPrint("DELETE CARD ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = currentCard;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                buildTopBar(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.border,
                          ),
                        )
                      : courseList.isEmpty
                          ? buildEmptyState(
                              title: "Chưa có học phần",
                              message: "Hãy tạo học phần trước rồi quay lại Flash Card.",
                            )
                          : allCards.isEmpty
                              ? buildEmptyState(
                                  title: "Học phần chưa có thẻ",
                                  message: "Hãy thêm thuật ngữ và định nghĩa cho học phần.",
                                )
                              : visibleOrder.isEmpty
                                  ? buildEmptyState(
                                      title: "Không có thẻ phù hợp",
                                      message:
                                          "Tắt chế độ chỉ học thẻ gắn sao hoặc gắn sao thêm thẻ.",
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              18,
                                              16,
                                              18,
                                              8,
                                            ),
                                            child: Stack(
  children: [
    buildPeekCard(),

    buildFlashCard(card!),

    // hiệu ứng bay/lật nằm trên thẻ chính
    buildGhostCard(),

    if (showCompletion)
      buildCompletionOverlay(),
  ],
),
                                          ),
                                        ),
                                        buildBottomBar(),
                                      ],
                                    ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: Colors.white,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedCourseId,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  hint: const Text("Chọn học phần"),
                  items: courseList.map((course) {
                    return DropdownMenuItem<int>(
                      value: course.id,
                      child: Text(
                        "${course.title} (${course.cardCount})",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCourseId = value;
                    });
                    loadCardsForCourse(value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: Colors.white,
            onTap: openSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState({
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 8),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style_outlined, size: 54, color: AppColors.border),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  StudyCardItem? getPeekCard() {
  if (visibleOrder.isEmpty) return null;

  int peekPos;

  if (cardDragDx > 0) {
    peekPos = currentPos - 1;
  } else {
    peekPos = currentPos + 1;
  }

  if (peekPos < 0 || peekPos >= visibleOrder.length) return null;

  final realIndex = visibleOrder[peekPos];
  if (realIndex < 0 || realIndex >= allCards.length) return null;

  return allCards[realIndex];
}

Widget buildPeekCard() {
  final peekCard = getPeekCard();

  if (peekCard == null) return const SizedBox.shrink();

  final dragPercent = (cardDragDx.abs() / 180).clamp(0.0, 1.0);

  return IgnorePointer(
    child: AnimatedOpacity(
      duration: isDraggingCard
          ? Duration.zero
          : const Duration(milliseconds: 180),
      opacity: dragPercent,
      child: AnimatedScale(
        duration: isDraggingCard
            ? Duration.zero
            : const Duration(milliseconds: 180),
        scale: 0.94 + (0.04 * dragPercent),
        curve: Curves.easeOut,
        child: Transform.translate(
          offset: Offset(
            cardDragDx > 0 ? -22 * (1 - dragPercent) : 22 * (1 - dragPercent),
            18 * (1 - dragPercent),
          ),
          child: buildCardFace(
            label: cardDragDx > 0 ? "Thẻ trước" : "Thẻ sau",
            mainText: peekCard.term,
            subText: peekCard.pronunciation,
            isBack: false,
            isStarred: peekCard.isFavorite,
          ),
        ),
      ),
    ),
  );
}

  Widget buildFlashCard(StudyCardItem card) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,

    onTap: () {
      if (cardDragDx.abs() < 6) {
        toggleFlip();
      }
    },

    onHorizontalDragStart: (_) {
      ghostController.stop();

      setState(() {
        isDraggingCard = true;
        cardDragDx = 0;
      });
    },

    onHorizontalDragUpdate: (details) {
  setState(() {
    cardDragDx = (cardDragDx + details.delta.dx).clamp(-260.0, 260.0);
  });
},

    onHorizontalDragEnd: (details) {
      final velocity = details.primaryVelocity ?? 0;
      final shouldNext = cardDragDx < -110 || velocity < -450;
      final shouldPrev = cardDragDx > 110 || velocity > 450;

      setState(() {
        isDraggingCard = false;
      });

      if (shouldNext) {
        setState(() {
          cardDragDx = 0;
        });
        moveCard(1);
        return;
      }

      if (shouldPrev) {
        setState(() {
          cardDragDx = 0;
        });
        moveCard(-1);
        return;
      }

      setState(() {
        cardDragDx = 0;
      });
    },

    onHorizontalDragCancel: () {
      setState(() {
        isDraggingCard = false;
        cardDragDx = 0;
      });
    },

    child: AnimatedContainer(
      duration: isDraggingCard
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(cardDragDx)
        ..rotateZ(cardDragDx * 0.0009),
      child: AnimatedBuilder(
        animation: flipController,
        builder: (context, child) {
          final angle = flipController.value * math.pi;
          final showBack = angle > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: buildCardFace(
                      label: "Mặt sau",
                      mainText: card.definition,
                      subText: card.pronunciation,
                      isBack: true,
                      isStarred: card.isFavorite,
                    ),
                  )
                : buildCardFace(
                    label: "Mặt trước",
                    mainText: card.term,
                    subText: card.pronunciation,
                    isBack: false,
                    isStarred: card.isFavorite,
                  ),
          );
        },
      ),
    ),
  );
}
  Widget buildCardFace({
    required String label,
    required String mainText,
    required String subText,
    required bool isBack,
    required bool isStarred,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 8),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 18),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isBack ? AppColors.yellow : AppColors.red,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.border,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  buildCardIcon(Icons.edit, openEditCardDialog),
                  buildCardIcon(Icons.volume_up_outlined, () {
                    showFlashMessage("TTS sẽ nối vào nút này");
                  }),
                  buildCardIcon(Icons.mic_none, () {
                    showFlashMessage("Luyện phát âm sẽ nối vào nút này");
                  }),
                  buildCardIcon(
                    isStarred ? Icons.star : Icons.star_border,
                    toggleStar,
                    active: isStarred,
                  ),
                  buildCardIcon(Icons.delete_outline, deleteCurrentCard),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    mainText.isEmpty ? "Chưa có thẻ" : mainText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: mainText.length > 40 ? 34 : 48,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: subText.trim().isEmpty
                  ? const SizedBox(height: 48)
                  : Container(
                      key: ValueKey(subText),
                      height: 56,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        subText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCardIcon(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 21,
            color: active ? const Color(0xffffb020) : AppColors.border,
          ),
        ),
      ),
    );
  }

  Widget buildGhostCard() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: ghostController,
        builder: (context, child) {
          final t = ghostController.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();

          final direction = ghostReverse ? 1.0 : -1.0;
          final dx = direction * (60 + 760 * t);
          final dy = -28 * math.sin(t * math.pi);
          final rot = direction * math.pi * t;
          final opacity = (1 - t).clamp(0.0, 1.0);
          final scale = 1 - (0.5 * t);

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(rot)
                    ..rotateZ(direction * 0.18 * (1 - t)),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border, width: 1.3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          offset: Offset(0, 8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Text(
                      ghostText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildCompletionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_outlined, size: 64, color: AppColors.border),
            const SizedBox(height: 14),
            const Text(
              "Hoàn thành bộ thẻ",
              style: TextStyle(
                color: AppColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Bạn đã đi hết $displayTotal thẻ.",
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: restartStudy,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border, width: 1.4),
                ),
              ),
              child: const Text(
                "Học lại",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomBar() {
    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: toggleProgressMode,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: progressTracking ? AppColors.border : AppColors.muted,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: progressTracking
                        ? [
                            BoxShadow(
                              color: AppColors.border.withOpacity(0.25),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  alignment: progressTracking
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Tiến độ",
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          buildRoundNavButton(
            icon: progressTracking ? Icons.close : Icons.chevron_left,
            onTap: canPrev ? () => moveCard(-1) : null,
            color: progressTracking ? AppColors.red : Colors.white,
          ),
          Container(
            width: 76,
            alignment: Alignment.center,
            child: Text(
              "$displayIndex / $displayTotal",
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          buildRoundNavButton(
            icon: progressTracking ? Icons.check : Icons.chevron_right,
            onTap: () => moveCard(1),
            color: progressTracking ? AppColors.green : Colors.white,
          ),
          const Spacer(),
          buildSmallBottomIcon(
            icon: Icons.shuffle,
            active: shuffleEnabled,
            onTap: toggleShuffle,
          ),
          buildSmallBottomIcon(
            icon: starredOnly ? Icons.star : Icons.star_border,
            active: starredOnly,
            onTap: toggleStarredOnly,
          ),
          buildSmallBottomIcon(
            icon: Icons.refresh,
            active: false,
            onTap: restartStudy,
          ),
        ],
      ),
    );
  }

  Widget buildRoundNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.42 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.border, size: 30),
        ),
      ),
    );
  }

  Widget buildSmallBottomIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active ? const Color(0xffffb020) : AppColors.border,
      ),
    );
  }
}



class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );
  }
}

class LightInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final double height;

  const LightInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.border,
              width: 1.4,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.border,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

class MiniInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const MiniInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.border,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class SmallIcon3DButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SmallIcon3DButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<SmallIcon3DButton> createState() => _SmallIcon3DButtonState();
}

class _SmallIcon3DButtonState extends State<SmallIcon3DButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: AppColors.border,
          size: 24,
        ),
      ),
    );
  }
}

class BigPopupButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BigPopupButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<BigPopupButton> createState() => _BigPopupButtonState();
}

class _BigPopupButtonState extends State<BigPopupButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, isPressed ? 5 : 0, 0),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: AppColors.border,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              widget.text,
              style: const TextStyle(
                color: AppColors.border,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Big3DButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const Big3DButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<Big3DButton> createState() => _Big3DButtonState();
}

class _Big3DButtonState extends State<Big3DButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          isPressed ? 7 : 0,
          0,
        ),
        width: screenW * 0.7,
        height: screenH * 0.13,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 8),
              blurRadius: 0,
            ),
            BoxShadow(
              color: const Color(0x22000000),
              offset: Offset(0, isPressed ? 5 : 18),
              blurRadius: isPressed ? 8 : 28,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: AppColors.border,
                size: 34,
              ),
              const SizedBox(width: 14),
              Text(
                widget.text,
                style: const TextStyle(
                  color: AppColors.border,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactSelectItem {
  final String value;
  final String label;

  const CompactSelectItem({
    required this.value,
    required this.label,
  });
}

class CompactSelectBox extends StatelessWidget {

  final String title;
  final String value;
  final List<CompactSelectItem> items;
  final ValueChanged<String> onChanged;
  final TextEditingController customController;
  final String customHint;
  final bool showCustomInput;
  final ValueChanged<String> onCustomChanged;

  const CompactSelectBox({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.customController,
    required this.customHint,
    required this.showCustomInput,
    required this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              final selected = item.value == value;

              return GestureDetector(
                onTap: () => onChanged(item.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.yellow : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.4,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.border,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (showCustomInput) ...[
            const SizedBox(height: 14),
            MiniInput(
              controller: customController,
              enabled: true,
              hintText: customHint,
              onChanged: onCustomChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class ParsedDefinition {
  final String definition;
  final String pronunciation;

  ParsedDefinition({
    required this.definition,
    required this.pronunciation,
  });
}
