import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/app_database.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MyApp());
}

class AppColors {
  static Map<String, Color> _lightDefaults = {
    'bg': Color(0xffeef1f4),
    'panel': Color(0xffffffff),
    'panel2': Color(0xfff7f9fc),
    'border': Color(0xff1f3b63),
    'text': Color(0xff183153),
    'muted': Color(0xff6d7890),
    'yellow': Color(0xfff5c400),
    'green': Color(0xff8ee88b),
    'red': Color(0xffff9f9f),
    'blue': Color(0xffa1a7fb),
  };

  static Map<String, Color> _darkDefaults = {
    'bg': Color(0xff0f172a),
    'panel': Color(0xff182235),
    'panel2': Color(0xff23314a),
    'border': Color(0xff8fb3e8),
    'text': Color(0xfff8fbff),
    'muted': Color(0xffb8c5dc),
    'yellow': Color(0xfff2c94c),
    'green': Color(0xff78e08f),
    'red': Color(0xffff8f9b),
    'blue': Color(0xff9fa8ff),
  };

  static Color bg = _lightDefaults['bg']!;
  static Color panel = _lightDefaults['panel']!;
  static Color panel2 = _lightDefaults['panel2']!;
  static Color border = _lightDefaults['border']!;
  static Color text = _lightDefaults['text']!;
  static Color muted = _lightDefaults['muted']!;
  static Color yellow = _lightDefaults['yellow']!;
  static Color green = _lightDefaults['green']!;
  static Color red = _lightDefaults['red']!;
  static Color blue = _lightDefaults['blue']!;
  static Color buttonInk = Color(0xff183153);
  static Color get overlay => Colors.black.withOpacity(activeIsDark ? 0.42 : 0.25);
  static bool activeIsDark = false;

  static Color readableOn(Color bg) {
    return bg.computeLuminance() > 0.45 ? Color(0xff183153) : Color(0xffffffff);
  }

  static Map<String, Color> get editableColors => {
        'bg': bg,
        'panel': panel,
        'panel2': panel2,
        'border': border,
        'text': text,
        'muted': muted,
        'yellow': yellow,
        'green': green,
        'red': red,
        'blue': blue,
      };

  static Color getByKey(String key) => editableColors[key] ?? text;

  static void setByKey(String key, Color value) {
    switch (key) {
      case 'bg': bg = value; break;
      case 'panel': panel = value; break;
      case 'panel2': panel2 = value; break;
      case 'border': border = value; break;
      case 'text': text = value; break;
      case 'muted': muted = value; break;
      case 'yellow': yellow = value; break;
      case 'green': green = value; break;
      case 'red': red = value; break;
      case 'blue': blue = value; break;
    }
  }

  static int toInt(Color color) => color.value;

  static Color fromText(String? value, Color fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    final cleaned = value.replaceAll('#', '').replaceAll('0x', '').trim();
    final parsed = int.tryParse(cleaned.length == 6 ? 'ff$cleaned' : cleaned, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  static Future<void> load({required BuildContext context}) async {
    final mode = await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final platformBrightness = MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final isDark = mode == 'dark' || (mode == 'system' && platformBrightness == Brightness.dark);
    activeIsDark = isDark;
    buttonInk = Color(0xff183153);
    final base = isDark ? _darkDefaults : _lightDefaults;

    for (final key in base.keys) {
      final saved = await AppSettingsStore.getString('color.$key');
      setByKey(key, fromText(saved, base[key]!));
    }
  }

  static Future<void> saveColor(String key, Color color) async {
    setByKey(key, color);
    await AppSettingsStore.setString('color.$key', toInt(color).toRadixString(16).padLeft(8, '0'));
    AppThemeController.instance.bump();
  }

  static Future<void> resetColors({required BuildContext context}) async {
    final mode = await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final platformBrightness = MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final isDark = mode == 'dark' || (mode == 'system' && platformBrightness == Brightness.dark);
    activeIsDark = isDark;
    buttonInk = Color(0xff183153);
    final base = isDark ? _darkDefaults : _lightDefaults;
    for (final key in base.keys) {
      setByKey(key, base[key]!);
      await AppSettingsStore.setString('color.$key', toInt(base[key]!).toRadixString(16).padLeft(8, '0'));
    }
    AppThemeController.instance.bump();
  }
}

class AppThemeController extends ValueNotifier<int> {
  AppThemeController._() : super(0);
  static final AppThemeController instance = AppThemeController._();
  void bump() => value++;
}


class AppSettingsStore {
  AppSettingsStore._();

  static Future<void> _ensureTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_settings ('
      'key TEXT PRIMARY KEY, '
      'value TEXT NOT NULL'
      ')',
    );
  }

  static Future<String?> getString(String key) async {
    final db = await AppDatabase.instance.database;
    await _ensureTable(db);

    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  static Future<void> setString(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await _ensureTable(db);

    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool?> getBool(String key) async {
    final value = await getString(key);
    if (value == null) return null;
    return value == '1' || value.toLowerCase() == 'true';
  }

  static Future<void> setBool(String key, bool value) {
    return setString(key, value ? '1' : '0');
  }

  static Future<int?> getInt(String key) async {
    final value = await getString(key);
    return value == null ? null : int.tryParse(value);
  }

  static Future<void> setInt(String key, int value) {
    return setString(key, value.toString());
  }
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

class TtsAudioCache {
  TtsAudioCache._();

  static final TtsAudioCache instance = TtsAudioCache._();

  final AudioPlayer _player = AudioPlayer();
  FlutterTts _flutterTts = FlutterTts();
  bool _ready = false;

  bool get _disableSoundOnWindows => Platform.isWindows;

  bool get _canCacheAudioFile =>
      !_disableSoundOnWindows &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _resetTtsEngine() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}

    _flutterTts = FlutterTts();
    _ready = false;
  }

  Future<void> _init() async {
    if (_ready) return;

    // Android TTS bind chậm, nhất là sau hot reload/emulator vừa mở.
    // Delay ngắn để engine kịp bind, tránh lỗi: not bound to TTS engine.
    if (Platform.isAndroid) {
      await Future.delayed(Duration(milliseconds: 350));
    }

    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('TTS awaitSpeakCompletion ignored: $e');
    }

    if (_canCacheAudioFile) {
      try {
        await _flutterTts.awaitSynthCompletion(true);
      } catch (e) {
        debugPrint('TTS awaitSynthCompletion ignored: $e');
      }
    }

    if (Platform.isIOS) {
      try {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (e) {
        debugPrint('TTS iOS audio category ignored: $e');
      }
    }

    _ready = true;
  }

  String normalizeLanguageCode(String languageCode) {
    final code = languageCode.trim();

    if (code.startsWith('de')) return 'de-DE';
    if (code == 'zh-CN' || code.startsWith('zh-Hans')) return 'zh-CN';
    if (code == 'zh-TW' || code.startsWith('zh-Hant')) return 'zh-TW';
    if (code.startsWith('en')) return 'en-US';
    if (code.startsWith('ja')) return 'ja-JP';
    if (code.startsWith('ko')) return 'ko-KR';
    if (code.startsWith('vi')) return 'vi-VN';

    return code.isEmpty ? 'en-US' : code;
  }

  String _safeHash(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<Directory> _courseAudioDir({
    required int courseId,
    required String languageCode,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final lang = normalizeLanguageCode(languageCode).replaceAll('-', '_');
    final dir = Directory('${baseDir.path}/tts_cache/course_$courseId/$lang');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<void> deleteCourseAudioCache({
    required int courseId,
  }) async {
    if (!_canCacheAudioFile) return;

    try {
      await _player.stop();
      await _flutterTts.stop();
    } catch (_) {}

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final courseDir = Directory('${baseDir.path}/tts_cache/course_$courseId');

      if (await courseDir.exists()) {
        await courseDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('DELETE TTS COURSE CACHE ERROR: courseId=$courseId => $e');
    }
  }

  Future<File> getAudioFile({
    required String text,
    required String languageCode,
    required int courseId,
  }) async {
    final dir = await _courseAudioDir(
      courseId: courseId,
      languageCode: languageCode,
    );

    final lang = normalizeLanguageCode(languageCode).replaceAll('-', '_');
    final hash = _safeHash('${normalizeLanguageCode(languageCode)}|${text.trim()}');

    return File('${dir.path}/${lang}_$hash.wav');
  }

  Future<bool> _setupVoice(String languageCode) async {
    final lang = normalizeLanguageCode(languageCode);

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await _init();

        if (Platform.isAndroid) {
          // Gọi nhẹ để ép plugin chạm vào engine sau khi bind.
          await _flutterTts.isLanguageAvailable(lang);
        }

        await _flutterTts.setLanguage(lang);
        await _flutterTts.setSpeechRate(0.45);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setVolume(1.0);
        return true;
      } catch (e) {
        debugPrint('TTS setup retry ${attempt + 1}: $lang => $e');
        await Future.delayed(Duration(milliseconds: 250 + attempt * 250));
        await _resetTtsEngine();
      }
    }

    return false;
  }

  Future<File?> ensureAudioForText({
    required String text,
    required String languageCode,
    required int courseId,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return null;

    if (!_canCacheAudioFile) return null;

    final file = await getAudioFile(
      text: value,
      languageCode: languageCode,
      courseId: courseId,
    );

    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    // Android emulator hay lỗi synthesizeToFile khi TTS engine chưa bind.
    // Không cache được thì bỏ qua, lát nữa phát trực tiếp bằng speak().
    if (!await _setupVoice(languageCode)) return null;

    try {
      final result = await _flutterTts.synthesizeToFile(value, file.path, true);

      if (result == 1 && await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (e) {
      debugPrint('TTS synthesizeToFile ignored: $e');
    }

    return null;
  }

  Future<void> prepareCourseAudio({
    required List<FlashCardItem> items,
    required String languageCode,
    required int courseId,
  }) async {
    if (!_canCacheAudioFile) return;

    for (final item in items) {
      try {
        await ensureAudioForText(
          text: item.term,
          languageCode: languageCode,
          courseId: courseId,
        );
      } catch (e) {
        debugPrint('CREATE TTS CACHE ERROR: ${item.term} => $e');
      }
    }
  }

  Future<void> _speakDirect({
    required String text,
    required String languageCode,
  }) async {
    if (_disableSoundOnWindows) return;

    final value = text.trim();
    if (value.isEmpty) return;

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final ready = await _setupVoice(languageCode);
        if (!ready) continue;

        await _player.stop();
        await _flutterTts.stop();
        await Future.delayed(Duration(milliseconds: 80));

        final result = await _flutterTts.speak(value);
        if (result == 1) return;

        debugPrint('TTS speak retry ${attempt + 1}: result=$result');
      } catch (e) {
        debugPrint('TTS speak retry ${attempt + 1}: $e');
      }

      await Future.delayed(Duration(milliseconds: 300 + attempt * 300));
      await _resetTtsEngine();
    }

    throw Exception(
      'Không phát được âm thanh. Android chưa bind được TTS engine hoặc máy chưa cài Speech Services.',
    );
  }

  Future<void> playText({
    required String text,
    required String languageCode,
    required int courseId,
  }) async {
    if (_disableSoundOnWindows) return;

    final value = text.trim();
    if (value.isEmpty) return;

    try {
      final file = await ensureAudioForText(
        text: value,
        languageCode: languageCode,
        courseId: courseId,
      );

      if (file != null && await file.exists() && await file.length() > 0) {
        await _flutterTts.stop();
        await _player.stop();
        await _player.setFilePath(file.path);
        await _player.play();
        return;
      }
    } catch (e) {
      debugPrint('PLAY CACHE AUDIO ignored: $e');
    }

    await _speakDirect(
      text: value,
      languageCode: languageCode,
    );
  }
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

OverlayEntry? _activeAppToastEntry;

void showAppToast(
  BuildContext context,
  String text, {
  IconData? icon,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeAppToastEntry?.remove();
  _activeAppToastEntry = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SlideToast(
      text: text,
      icon: icon,
      duration: duration,
      onDismissed: () {
        if (_activeAppToastEntry == entry) {
          _activeAppToastEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _activeAppToastEntry = entry;
  overlay.insert(entry);
}

class _SlideToast extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismissed;

  _SlideToast({
    required this.text,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_SlideToast> createState() => _SlideToastState();
}

class _SlideToastState extends State<_SlideToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320),
      reverseDuration: Duration(milliseconds: 220),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _closed) return;
    _closed = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final toastWidth = math.min(media.size.width - 24, 380.0);
    final bg = AppColors.border;
    final fg = AppColors.readableOn(bg);

    return Positioned(
      top: media.padding.top + 14,
      right: 12,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final value = _curve.value;
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset((1 - value) * 120, 0),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              width: toastWidth,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: fg.withOpacity(0.18), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    offset: Offset(0, 8),
                    blurRadius: 22,
                  ),
                  BoxShadow(
                    color: AppColors.green.withOpacity(0.18),
                    offset: Offset(-4, 0),
                    blurRadius: 0,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeController.instance,
      builder: (context, _, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.bg,
            fontFamily: 'Arial',
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.border,
              contentTextStyle: TextStyle(
                color: AppColors.readableOn(AppColors.border),
                fontWeight: FontWeight.w800,
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.bg,
            fontFamily: 'Arial',
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.border,
              contentTextStyle: TextStyle(
                color: AppColors.readableOn(AppColors.border),
                fontWeight: FontWeight.w800,
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          home: AppThemeLoader(child: HomePage()),
        );
      },
    );
  }
}

class AppThemeLoader extends StatefulWidget {
  final Widget child;
  AppThemeLoader({super.key, required this.child});

  @override
  State<AppThemeLoader> createState() => _AppThemeLoaderState();
}

class _AppThemeLoaderState extends State<AppThemeLoader> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      AppColors.load(context: context).then((_) {
        if (mounted) AppThemeController.instance.bump();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOpen = false;
  double _homeDragStartX = 0;
  bool _openedByEdgeSwipe = false;

  bool isLoadingCourses = false;
  List<CourseListItem> courses = [];
  CourseListItem? selectedHomeCourse;
  final TextEditingController courseSearchController = TextEditingController();
  String courseSortType = "updatedDesc";
  String courseLanguageFilter = "all";

  List<String> get courseLanguageFilters {
    final languages = courses
        .map((course) => course.languageCode.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
    languages.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return languages;
  }

  List<CourseListItem> get visibleCourses {
    final keyword = courseSearchController.text.trim().toLowerCase();
    final filtered = courses.where((course) {
      final courseLanguage = course.languageCode.trim();
      final matchesLanguage = courseLanguageFilter == "all" ||
          courseLanguage.toLowerCase() == courseLanguageFilter.toLowerCase();

      if (!matchesLanguage) return false;
      if (keyword.isEmpty) return true;

      return course.title.toLowerCase().contains(keyword) ||
          courseLanguage.toLowerCase().contains(keyword) ||
          languageNameFromCode(courseLanguage).toLowerCase().contains(keyword);
    }).toList();

    switch (courseSortType) {
      case "az":
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case "za":
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case "cardsDesc":
        filtered.sort((a, b) => b.cardCount.compareTo(a.cardCount));
        break;
      case "cardsAsc":
        filtered.sort((a, b) => a.cardCount.compareTo(b.cardCount));
        break;
      default:
        break;
    }

    return filtered;
  }

  String get courseSortLabel {
    switch (courseSortType) {
      case "az":
        return "A-Z";
      case "za":
        return "Z-A";
      case "cardsDesc":
        return "Nhiều thẻ";
      case "cardsAsc":
        return "Ít thẻ";
      default:
        return "Mới nhất";
    }
  }

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  @override
  void dispose() {
    courseSearchController.dispose();
    super.dispose();
  }

  Future<void> toggleMenu() async {
  if (isOpen) {
    closeMenu();
    return;
  }

  await openMenu();
}

Future<void> openMenu() async {
  if (isOpen) return;

  setState(() {
    isOpen = true;
  });

  await loadCourses();
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
      builder: (_) => CreateCoursePage(),
    ),
  );

  if (result == true) {
    await loadCourses();
  }
}

Future<void> openReviewPractice([CourseListItem? course]) async {
  CourseListItem? targetCourse = course ?? selectedHomeCourse;

  if (targetCourse == null) {
    if (courses.isEmpty) {
      await loadCourses();
    }

    if (courses.length == 1) {
      targetCourse = courses.first;
    }
  }

  if (targetCourse == null) {
    setState(() {
      isOpen = true;
    });
    showHomeMessage("Hãy chọn học phần trong danh sách trước");
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
    MaterialPageRoute(
      builder: (_) => StatisticsPage(),
    ),
  );
}

Future<void> openSettingsPage() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SettingsPage(),
    ),
  );
  if (mounted) setState(() {});
}

Future<void> openFlashCards([CourseListItem? course]) async {
  CourseListItem? targetCourse = course ?? selectedHomeCourse;

  if (targetCourse == null) {
    if (courses.isEmpty) {
      await loadCourses();
    }

    if (courses.length == 1) {
      targetCourse = courses.first;
    }
  }

  if (targetCourse == null) {
    setState(() {
      isOpen = true;
    });
    showHomeMessage("Hãy chọn học phần trong danh sách trước");
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
        AND cards.isHidden = 0
      WHERE c.deletedAt IS NULL
      GROUP BY c.id, c.title, c.languageCode
      ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
    ''');

    debugPrint("DRAWER COURSES COUNT: ${rows.length}");
    debugPrint("DRAWER COURSES DATA: $rows");

    if (!mounted) return;

    setState(() {
      courses = rows.map((e) => CourseListItem.fromMap(e)).toList();
      final currentLanguages = courses
          .map((course) => course.languageCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet();
      if (courseLanguageFilter != "all" &&
          !currentLanguages.contains(courseLanguageFilter.toLowerCase())) {
        courseLanguageFilter = "all";
      }
      if (selectedHomeCourse != null) {
        final stillExists = courses.where((e) => e.id == selectedHomeCourse!.id);
        selectedHomeCourse = stillExists.isEmpty ? null : stillExists.first;
      }
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
    DropdownMenuItem(
      value: "Tiếng Việt (Vietnamese)",
      child: Text("Tiếng Việt"),
    ),
  ];
}

Future<void> openEditCourseDialog(CourseListItem course) async {
  final controller = TextEditingController(text: course.title);
  String selectedLanguage = languageNameFromCode(course.languageCode);

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
                        dropdownColor: Colors.white,
                        iconEnabledColor: AppColors.border,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        items: buildLanguageItems(),
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
                  final oldLanguageCode = course.languageCode;
                  final newLanguageCode = languageCodeFromName(selectedLanguage);
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
                    showHomeMessage("Đang tạo lại âm thanh cho ngôn ngữ mới...");

                    final cardRows = await db.query(
                      'cards',
                      where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
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
                  await loadCourses();
                  showHomeMessage(
                    languageChanged
                        ? "Đã đổi ngôn ngữ và tạo lại âm thanh"
                        : "Đã sửa học phần",
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.buttonInk,
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

    await TtsAudioCache.instance.deleteCourseAudioCache(
      courseId: course.id,
    );

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
      await txn.delete(
        'courses',
        where: 'id = ?',
        whereArgs: [course.id],
      );
    });

    await loadCourses();
    showHomeMessage("Đã xóa học phần khỏi app và DB");
  } catch (e) {
    showHomeMessage("Xóa thất bại");
    debugPrint("DELETE COURSE ERROR: $e");
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _homeDragStartX = details.globalPosition.dx;
          _openedByEdgeSwipe = false;
        },
        onHorizontalDragUpdate: (details) async {
          final isEdgeSwipe = _homeDragStartX <= 38;
          final dragRightEnough = details.delta.dx > 4;
          final distanceEnough = details.globalPosition.dx - _homeDragStartX > 24;

          if (!isOpen && !_openedByEdgeSwipe && isEdgeSwipe && dragRightEnough && distanceEnough) {
            _openedByEdgeSwipe = true;
            await openMenu();
          }
        },
        onHorizontalDragEnd: (details) async {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 260 && !isOpen && _homeDragStartX <= 90) {
            await openMenu();
          } else if (velocity < -260 && isOpen) {
            closeMenu();
          }
        },
        child: Stack(
        children: [
          Container(
            color: AppColors.bg,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 110),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Big3DButton(
                          text: "Tạo Cards",
                          icon: Icons.create,
                          color: AppColors.yellow,
                          onTap: openCreateCourse,
                        ),
                        SizedBox(height: 28),
                        Big3DButton(
                          text: "Flash Card",
                          icon: Icons.style_outlined,
                          color: AppColors.red,
                          onTap: openFlashCards,
                        ),
                        SizedBox(height: 28),
                        Big3DButton(
                          text: "Ôn Tập",
                          icon: Icons.school,
                          color: AppColors.green,
                          onTap: openReviewPractice,
                        ),
                        SizedBox(height: 28),
                        Big3DButton(
                          text: "Thống Kê",
                          icon: Icons.insights_rounded,
                          color: AppColors.blue,
                          onTap: openStatistics,
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
    duration: Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    opacity: isOpen ? 1 : 0,
    child: GestureDetector(
      onTap: closeMenu,
      child: Container(
        color: AppColors.overlay,
      ),
    ),
  ),
),
          AnimatedPositioned(
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
                                        color: AppColors.muted.withOpacity(0.75),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      filled: true,
                                      fillColor: AppColors.panel,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                          width: 1.2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
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
                                    setState(() {
                                      courseLanguageFilter = value;
                                    });
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: "all", child: Text("Tất cả ngôn ngữ")),
                                    ...courseLanguageFilters.map(
                                      (code) => PopupMenuItem(
                                        value: code,
                                        child: Text("${languageNameFromCode(code)} • $code"),
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: courseLanguageFilter == "all"
                                          ? AppColors.green
                                          : AppColors.blue,
                                      borderRadius: BorderRadius.circular(14),
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
                                        color: AppColors.border,
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
                                    setState(() {
                                      courseSortType = value;
                                    });
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: "updatedDesc", child: Text("Mới nhất")),
                                    PopupMenuItem(value: "az", child: Text("A-Z")),
                                    PopupMenuItem(value: "za", child: Text("Z-A")),
                                    PopupMenuItem(value: "cardsDesc", child: Text("Nhiều thẻ nhất")),
                                    PopupMenuItem(value: "cardsAsc", child: Text("Ít thẻ nhất")),
                                  ],
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.yellow,
                                      borderRadius: BorderRadius.circular(14),
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
                                        color: AppColors.border,
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
      ? Center(
          child: CircularProgressIndicator(),
        )
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
              separatorBuilder: (_, __) => SizedBox(height: 2),
              itemBuilder: (context, index) {
                final course = visibleCourses[index];

                final isSelected = selectedHomeCourse?.id == course.id;

                return Padding(
                  padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() {
                        selectedHomeCourse = course;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.green : AppColors.panel2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 1.25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.border.withOpacity(isSelected ? 1 : 0.18),
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
                              if (value == "edit") {
                                openEditCourseDialog(course);
                              }

                              if (value == "delete") {
                                confirmDeleteCourse(course);
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
            onPressed: openCreateCourse,
            child: Text("Thêm học phần"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.buttonInk,
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
          onPressed: closeMenu,
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
          ),
          Positioned(
  left: 16,
  right: 16,
  bottom: 20,
  child: IgnorePointer(
    ignoring: isOpen,
    child: AnimatedSlide(
      duration: Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      offset: isOpen ? Offset(0, 1.35) : Offset.zero,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 260),
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
                color: AppColors.panel.withOpacity(0.78),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.panel.withOpacity(0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: toggleMenu,
                    icon: Icon(
                      Icons.menu,
                      size: 30,
                      color: AppColors.muted,
                    ),
                  ),
                  IconButton(
                    onPressed: openSettingsPage,
                    icon: Icon(
                      Icons.settings_rounded,
                      size: 30,
                      color: AppColors.muted,
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
      ),
    );
  }
}



class BackupManager {
  BackupManager._();

  static Future<Directory> _backupRoot() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/flashcard_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  static Future<String> exportAll() async {
    final db = await AppDatabase.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');

    final root = await _backupRoot();
    final backupDir = Directory('${root.path}/backup_${_stamp()}');
    await backupDir.create(recursive: true);

    final dbPath = await getDatabasesPath();
    final dbFile = File('$dbPath/list_card.db');
    if (await dbFile.exists()) {
      await dbFile.copy('${backupDir.path}/list_card.db');
    }

    final docDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docDir.path}/tts_cache');
    if (await audioDir.exists()) {
      await _copyDirectory(audioDir, Directory('${backupDir.path}/tts_cache'));
    }

    await File('${backupDir.path}/README.txt').writeAsString(
      'Flashcard backup\n'
      'Tao luc: ${DateTime.now().toIso8601String()}\n\n'
      'Muon giu du lieu khi app mat chung chi: copy ca thu muc Documents cua app, hoac giu thu muc flashcard_backups nay.\n'
      'Backup gom list_card.db va tts_cache audio.\n',
    );

    await db.insert(
      'import_exports',
      {
        'type': 'export',
        'fileName': backupDir.uri.pathSegments.isNotEmpty ? backupDir.uri.pathSegments.last : 'backup',
        'filePath': backupDir.path,
        'format': 'folder',
        'courseId': null,
        'status': 'success',
        'message': 'Export toàn bộ học phần kèm audio',
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final zipFile = await zipBackupDirectory(backupDir);

    await db.insert(
      'import_exports',
      {
        'type': 'export',
        'fileName': zipFile.uri.pathSegments.isNotEmpty ? zipFile.uri.pathSegments.last : 'backup.zip',
        'filePath': zipFile.path,
        'format': 'zip',
        'courseId': null,
        'status': 'success',
        'message': 'Export file zip toàn bộ học phần kèm audio',
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await shareBackupZip(zipFile);
    return zipFile.path;
  }

  static Future<File> zipBackupDirectory(Directory backupDir) async {
    final zipPath = '${backupDir.path}.zip';
    final zipFile = File(zipPath);
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(backupDir, includeDirName: false);
    encoder.close();

    return zipFile;
  }

  static Future<void> shareBackupZip(File zipFile) async {
    if (kIsWeb) return;

    if (Platform.isIOS || Platform.isAndroid) {
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        subject: 'FlashCard Backup',
        text: 'Backup FlashCard gồm toàn bộ học phần, database và audio.',
      );
      return;
    }

    await openFolderIfPossible(zipFile.parent.path);
  }


  static Future<void> openFolderIfPossible(String path) async {
    try {
      if (kIsWeb) return;
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  static Future<String> importLatest() async {
    final root = await _backupRoot();
    if (!await root.exists()) {
      throw Exception('Chưa có thư mục backup');
    }

    final backups = await root
        .list()
        .where((e) => e is Directory && e.path.split(Platform.pathSeparator).last.startsWith('backup_'))
        .cast<Directory>()
        .toList();

    if (backups.isEmpty) {
      throw Exception('Chưa có bản export nào để import');
    }

    backups.sort((a, b) => b.path.compareTo(a.path));
    final latest = backups.first;
    final sourceDb = File('${latest.path}/list_card.db');
    if (!await sourceDb.exists()) {
      throw Exception('Backup không có file list_card.db');
    }

    await AppDatabase.instance.close();
    final dbPath = await getDatabasesPath();
    await sourceDb.copy('$dbPath/list_card.db');

    final docDir = await getApplicationDocumentsDirectory();
    final targetAudio = Directory('${docDir.path}/tts_cache');
    if (await targetAudio.exists()) await targetAudio.delete(recursive: true);

    final sourceAudio = Directory('${latest.path}/tts_cache');
    if (await sourceAudio.exists()) {
      await _copyDirectory(sourceAudio, targetAudio);
    }

    final db = await AppDatabase.instance.database;
    await db.insert(
      'import_exports',
      {
        'type': 'import',
        'fileName': latest.uri.pathSegments.isNotEmpty ? latest.uri.pathSegments.last : 'backup',
        'filePath': latest.path,
        'format': 'folder',
        'courseId': null,
        'status': 'success',
        'message': 'Import toàn bộ học phần kèm audio',
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await openFolderIfPossible(latest.path);
    return latest.path;
  }

  static Future<String> appDataPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    return docDir.path;
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final newPath = '${target.path}${Platform.pathSeparator}$name';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}

class SettingsPage extends StatefulWidget {
  SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String themeMode = 'light';
  bool busy = false;
  String appPath = '';
  String message = '';

  final Map<String, String> colorNames = {
    'bg': 'Nền app',
    'panel': 'Nền card',
    'panel2': 'Nền phụ',
    'border': 'Viền / chữ đậm',
    'text': 'Chữ chính',
    'muted': 'Chữ phụ',
    'yellow': 'Nút tạo học phần',
    'green': 'Nút ôn tập / đúng',
    'red': 'Nút Flash Card / sai',
    'blue': 'Nút thống kê / phụ',
  };

  final List<Color> presets = [
    Color(0xffeef1f4),
    Color(0xffffffff),
    Color(0xff183153),
    Color(0xff1f3b63),
    Color(0xff6d7890),
    Color(0xfff5c400),
    Color(0xff8ee88b),
    Color(0xffff9f9f),
    Color(0xffa1a7fb),
    Color(0xff111827),
    Color(0xff1f2937),
    Color(0xff78e08f),
    Color(0xffffb020),
    Color(0xff38bdf8),
    Color(0xfff472b6),
  ];

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final mode = await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final path = await BackupManager.appDataPath();
    if (!mounted) return;
    setState(() {
      themeMode = mode;
      appPath = path;
    });
  }

  Future<void> changeThemeMode(String value) async {
    await AppSettingsStore.setString('appearance.themeMode', value);
    await AppColors.load(context: context);
    AppThemeController.instance.bump();
    if (!mounted) return;
    setState(() => themeMode = value);
  }

  Future<void> runTask(Future<String> Function() task, String doneText) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final path = await task();
      if (!mounted) return;
      setState(() => message = '$doneText\n$path');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context, true),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cài Đặt',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _roundIconButton(
                    icon: Icons.restart_alt_rounded,
                    onTap: () async {
                      await AppColors.resetColors(context: context);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              _sectionCard(
                title: 'Giao diện',
                icon: Icons.dark_mode_rounded,
                child: Column(
                  children: [
                    _modeTile('system', 'Theo điện thoại', Icons.phone_iphone_rounded),
                    _modeTile('light', 'Sáng', Icons.light_mode_rounded),
                    _modeTile('dark', 'Tối', Icons.nightlight_round),
                  ],
                ),
              ),
              SizedBox(height: 14),
              _sectionCard(
                title: 'Export / Import toàn bộ app',
                icon: Icons.folder_zip_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export sẽ tạo backup .zip gồm list_card.db và thư mục audio tts_cache. Trên iPhone/Android sẽ tự mở bảng chia sẻ, có AirDrop nếu thiết bị hỗ trợ.',
                      style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    SizedBox(height: 12),
                    _pathBox(appPath),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            text: 'Backup',
                            icon: Icons.ios_share_rounded,
                            color: AppColors.green,
                            onTap: () => runTask(BackupManager.exportAll, 'Đã export xong'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _actionButton(
                            text: 'Import',
                            icon: Icons.download_rounded,
                            color: AppColors.yellow,
                            onTap: () => runTask(BackupManager.importLatest, 'Đã import xong, hãy mở lại app nếu dữ liệu chưa refresh'),
                          ),
                        ),
                      ],
                    ),
                    if (busy) ...[
                      SizedBox(height: 12),
                      LinearProgressIndicator(color: AppColors.green, backgroundColor: AppColors.panel2),
                    ],
                    if (message.isNotEmpty) ...[
                      SizedBox(height: 12),
                      _pathBox(message),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 14),
              _sectionCard(
                title: 'Chỉnh màu toàn bộ giao diện',
                icon: Icons.palette_rounded,
                child: Column(
                  children: colorNames.entries.map((entry) => _colorRow(entry.key, entry.value)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [BoxShadow(color: AppColors.border.withOpacity(0.14), blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Icon(icon, color: AppColors.border),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [BoxShadow(color: AppColors.border.withOpacity(0.20), blurRadius: 0, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _modeTile(String value, String text, IconData icon) {
    final active = themeMode == value;
    return InkWell(
      onTap: () => changeThemeMode(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.panel2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: active ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900))),
            if (active) Text("Đang chọn", style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required String text, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [BoxShadow(color: AppColors.border.withOpacity(0.35), blurRadius: 0, offset: Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }

  Widget _pathBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _colorRow(String key, String label) {
    final current = AppColors.getByKey(key);
    return Container(
      margin: EdgeInsets.only(bottom: 13),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
              ),
              Text('#${current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((color) {
              return InkWell(
                onTap: () async {
                  await AppColors.saveColor(key, color);
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.value == current.value ? AppColors.text : AppColors.border.withOpacity(0.35),
                      width: color.value == current.value ? 2.4 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class StatisticsData {
  final int totalCourses;
  final int totalCards;
  final int masteredCards;
  final int needReviewCards;
  final int favoriteCards;
  final int totalSessions;
  final int totalCorrect;
  final int totalWrong;
  final int totalAnswered;
  final List<CourseStatisticsItem> courseItems;
  final List<ReviewDueItem> dueItems;

  StatisticsData({
    required this.totalCourses,
    required this.totalCards,
    required this.masteredCards,
    required this.needReviewCards,
    required this.favoriteCards,
    required this.totalSessions,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalAnswered,
    required this.courseItems,
    required this.dueItems,
  });

  int get completionPercent {
    if (totalCards <= 0) return 0;
    return ((masteredCards / totalCards) * 100).round().clamp(0, 100).toInt();
  }

  int get accuracyPercent {
    final sum = totalCorrect + totalWrong;
    if (sum <= 0) return 0;
    return ((totalCorrect / sum) * 100).round().clamp(0, 100).toInt();
  }
}

class CourseStatisticsItem {
  final int id;
  final String title;
  final String languageCode;
  final int totalCards;
  final int masteredCards;
  final int correctCount;
  final int wrongCount;
  final int sessionCount;

  CourseStatisticsItem({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.totalCards,
    required this.masteredCards,
    required this.correctCount,
    required this.wrongCount,
    required this.sessionCount,
  });

  int get progressPercent {
    if (totalCards <= 0) return 0;
    return ((masteredCards / totalCards) * 100).round().clamp(0, 100).toInt();
  }
}

class ReviewDueItem {
  final String term;
  final String definition;
  final String courseTitle;
  final int level;

  ReviewDueItem({
    required this.term,
    required this.definition,
    required this.courseTitle,
    required this.level,
  });
}

class StatisticsPage extends StatefulWidget {
  StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<StatisticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = loadStatistics();
  }

  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> _purgeSoftDeletedCourses(Database db) async {
    final rows = await db.query(
      'courses',
      columns: ['id'],
      where: 'deletedAt IS NOT NULL',
    );

    if (rows.isEmpty) return;

    final ids = rows
        .map((row) => _asInt(row['id']))
        .where((id) => id > 0)
        .toList();

    if (ids.isEmpty) return;

    await db.transaction((txn) async {
      for (final courseId in ids) {
        await txn.delete(
          'study_results',
          where:
              'sessionId IN (SELECT id FROM study_sessions WHERE courseId = ?) OR cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId, courseId],
        );
        await txn.delete(
          'study_sessions',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'review_states',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId],
        );
        await txn.delete(
          'card_examples',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId],
        );
        await txn.delete(
          'cards',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'course_tags',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'import_exports',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'courses',
          where: 'id = ?',
          whereArgs: [courseId],
        );
      }
    });

    for (final courseId in ids) {
      await TtsAudioCache.instance.deleteCourseAudioCache(courseId: courseId);
    }
  }

  Future<StatisticsData> loadStatistics() async {
    final db = await AppDatabase.instance.database;
    await _purgeSoftDeletedCourses(db);
    final now = DateTime.now().toIso8601String();

    final overviewRows = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM courses WHERE deletedAt IS NULL) AS totalCourses,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND c.deletedAt IS NULL
        ) AS totalCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          INNER JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND c.deletedAt IS NULL AND COALESCE(rs.level, 0) >= 1
        ) AS masteredCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          LEFT JOIN review_states rs ON rs.cardId = ca.id
          WHERE ca.deletedAt IS NULL
            AND ca.isHidden = 0
            AND c.deletedAt IS NULL
            AND (rs.id IS NULL OR COALESCE(rs.level, 0) < 1 OR rs.nextReviewAt IS NULL OR rs.nextReviewAt <= ?)
        ) AS needReviewCards,
        (SELECT COUNT(*)
          FROM cards ca
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND ca.isHidden = 0 AND ca.isFavorite = 1 AND c.deletedAt IS NULL
        ) AS favoriteCards,
        (SELECT COUNT(*)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalSessions,
        (SELECT COALESCE(SUM(ss.correctCount), 0)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalCorrect,
        (SELECT COALESCE(SUM(ss.wrongCount), 0)
          FROM study_sessions ss
          INNER JOIN courses c ON c.id = ss.courseId
          WHERE c.deletedAt IS NULL
        ) AS totalWrong,
        (SELECT COUNT(*)
          FROM study_results sr
          INNER JOIN cards ca ON ca.id = sr.cardId
          INNER JOIN courses c ON c.id = ca.courseId
          WHERE ca.deletedAt IS NULL AND c.deletedAt IS NULL
        ) AS totalAnswered
    ''', [now]);

    final overview = overviewRows.isEmpty ? <String, Object?>{} : overviewRows.first;

    final courseRows = await db.rawQuery('''
      SELECT
        c.id,
        c.title,
        c.languageCode,
        COUNT(ca.id) AS totalCards,
        COALESCE(SUM(CASE WHEN COALESCE(rs.level, 0) >= 1 THEN 1 ELSE 0 END), 0) AS masteredCards,
        COALESCE(SUM(rs.correctCount), 0) AS correctCount,
        COALESCE(SUM(rs.wrongCount), 0) AS wrongCount,
        (SELECT COUNT(*) FROM study_sessions ss WHERE ss.courseId = c.id) AS sessionCount
      FROM courses c
      LEFT JOIN cards ca
        ON ca.courseId = c.id
        AND ca.deletedAt IS NULL
        AND ca.isHidden = 0
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE c.deletedAt IS NULL
      GROUP BY c.id, c.title, c.languageCode
      ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
    ''');

    final dueRows = await db.rawQuery('''
      SELECT
        ca.term,
        ca.definition,
        c.title AS courseTitle,
        COALESCE(rs.level, 0) AS level,
        rs.nextReviewAt
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
        AND (rs.id IS NULL OR COALESCE(rs.level, 0) < 1 OR rs.nextReviewAt IS NULL OR rs.nextReviewAt <= ?)
      ORDER BY
        CASE WHEN rs.nextReviewAt IS NULL THEN 0 ELSE 1 END,
        rs.nextReviewAt ASC,
        ca.position ASC,
        ca.id ASC
      LIMIT 12
    ''', [now]);

    return StatisticsData(
      totalCourses: _asInt(overview['totalCourses']),
      totalCards: _asInt(overview['totalCards']),
      masteredCards: _asInt(overview['masteredCards']),
      needReviewCards: _asInt(overview['needReviewCards']),
      favoriteCards: _asInt(overview['favoriteCards']),
      totalSessions: _asInt(overview['totalSessions']),
      totalCorrect: _asInt(overview['totalCorrect']),
      totalWrong: _asInt(overview['totalWrong']),
      totalAnswered: _asInt(overview['totalAnswered']),
      courseItems: courseRows.map((row) {
        return CourseStatisticsItem(
          id: _asInt(row['id']),
          title: row['title']?.toString() ?? '',
          languageCode: row['languageCode']?.toString() ?? '',
          totalCards: _asInt(row['totalCards']),
          masteredCards: _asInt(row['masteredCards']),
          correctCount: _asInt(row['correctCount']),
          wrongCount: _asInt(row['wrongCount']),
          sessionCount: _asInt(row['sessionCount']),
        );
      }).toList(),
      dueItems: dueRows.map((row) {
        return ReviewDueItem(
          term: row['term']?.toString() ?? '',
          definition: row['definition']?.toString() ?? '',
          courseTitle: row['courseTitle']?.toString() ?? '',
          level: _asInt(row['level']),
        );
      }).toList(),
    );
  }

  void reloadStatistics() {
    setState(() {
      _future = loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: FutureBuilder<StatisticsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.border),
              );
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final data = snapshot.data;
            if (data == null) return _buildError('Không có dữ liệu thống kê');

            return RefreshIndicator(
              onRefresh: () async => reloadStatistics(),
              color: AppColors.border,
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(data)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        SizedBox(height: 16),
                        _buildOverviewGrid(data),
                        SizedBox(height: 16),
                        _buildChartPanel(data),
                        SizedBox(height: 16),
                        _buildCourseProgress(data),
                        SizedBox(height: 16),
                        _buildDueCards(data),
                        SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String text) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            _buildTopBar(),
            Spacer(),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: [
                  BoxShadow(color: AppColors.border, offset: Offset(0, 5), blurRadius: 0),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 42),
                  SizedBox(height: 10),
                  Text(
                    'Không tải được thống kê',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: reloadStatistics,
                    icon: Icon(Icons.refresh_rounded),
                    label: Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.buttonInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StatisticsData data) {
    return Container(
      margin: EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(onDark: true),
          SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: StatisticsDonutPainter(
                    percent: data.completionPercent / 100,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    progressColor: AppColors.green,
                    strokeWidth: 13,
                  ),
                  child: Center(
                    child: Text(
                      '${data.completionPercent}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng thống kê',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      data.totalCards == 0
                          ? 'Chưa có thẻ để thống kê'
                          : '${data.masteredCards}/${data.totalCards} thẻ đã ghi nhớ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildMiniHeaderPill(
                      icon: Icons.local_fire_department_rounded,
                      text: '${data.needReviewCards} thẻ cần ôn',
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

  Widget _buildTopBar({bool onDark = false}) {
    final color = onDark ? Colors.white : AppColors.text;
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withOpacity(0.13) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onDark ? Colors.white.withOpacity(0.25) : AppColors.border),
            ),
            child: Icon(Icons.arrow_back_rounded, color: color),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Thống Kê',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: reloadStatistics,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withOpacity(0.13) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onDark ? Colors.white.withOpacity(0.25) : AppColors.border),
            ),
            child: Icon(Icons.refresh_rounded, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniHeaderPill({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.yellow),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(StatisticsData data) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.22,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Học phần', data.totalCourses.toString(), Icons.folder_copy_rounded, AppColors.yellow),
        _buildStatCard('Tổng thẻ', data.totalCards.toString(), Icons.style_rounded, AppColors.red),
        _buildStatCard('Đã nhớ', data.masteredCards.toString(), Icons.check_circle_rounded, AppColors.green),
        _buildStatCard('Buổi học', data.totalSessions.toString(), Icons.event_note_rounded, AppColors.blue),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 46,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel(StatisticsData data) {
    final correct = data.totalCorrect;
    final wrong = data.totalWrong;
    final maxValue = math.max(1, math.max(correct, wrong));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.query_stats_rounded, color: AppColors.border),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kết quả luyện tập',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Độ chính xác ${data.accuracyPercent}% • ${data.totalAnswered} lượt trả lời',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildBarRow('Đúng', correct, maxValue, AppColors.green),
          SizedBox(height: 12),
          _buildBarRow('Sai', wrong, maxValue, AppColors.red),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.accuracyPercent / 100,
              minHeight: 14,
              backgroundColor: AppColors.bg,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, int value, int maxValue, Color color) {
    final widthFactor = (value / maxValue).clamp(0.04, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withOpacity(0.25)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseProgress(StatisticsData data) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiến độ từng học phần',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          if (data.courseItems.isEmpty)
            _buildEmptyBox('Chưa có học phần nào')
          else
            ...data.courseItems.take(8).map(_buildCourseProgressItem),
        ],
      ),
    );
  }

  Widget _buildCourseProgressItem(CourseStatisticsItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${item.progressPercent}%',
                  style: TextStyle(
                    color: AppColors.border,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '${item.masteredCards}/${item.totalCards} thẻ nhớ • ${item.sessionCount} buổi • ${item.languageCode}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.progressPercent / 100,
              minHeight: 12,
              backgroundColor: Colors.white,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueCards(StatisticsData data) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.replay_circle_filled_rounded, color: AppColors.border),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thẻ cần ôn lại',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (data.dueItems.isEmpty)
            _buildEmptyBox('Chưa có thẻ cần ôn, quá ổn')
          else
            ...data.dueItems.map(_buildDueItem),
        ],
      ),
    );
  }

  Widget _buildDueItem(ReviewDueItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.level >= 2 ? AppColors.yellow : AppColors.red,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'L${item.level}',
                style: TextStyle(
                  color: AppColors.border,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${item.definition} • ${item.courseTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatisticsDonutPainter extends CustomPainter {
  final double percent;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  StatisticsDonutPainter({
    required this.percent,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * percent.clamp(0.0, 1.0).toDouble(),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StatisticsDonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class CreateCoursePage extends StatefulWidget {
  CreateCoursePage({super.key});

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
  void initState() {
    super.initState();
    loadCreateCourseSettings();
  }

  Future<void> loadCreateCourseSettings() async {
    final savedTermSep = await AppSettingsStore.getString('create.termSeparatorType');
    final savedCardSep = await AppSettingsStore.getString('create.cardSeparatorType');
    final savedCustomTermSep = await AppSettingsStore.getString('create.customTermSeparator');
    final savedCustomCardSep = await AppSettingsStore.getString('create.customCardSeparator');
    final savedLanguage = await AppSettingsStore.getString('create.selectedLanguage');

    if (!mounted) return;

    setState(() {
      if (savedTermSep != null && savedTermSep.isNotEmpty) {
        termSeparatorType = savedTermSep == 'comma' ? 'underscore' : savedTermSep;
      }
      if (savedCardSep != null && savedCardSep.isNotEmpty) {
        cardSeparatorType = savedCardSep;
      }
      if (savedCustomTermSep != null) {
        customTermSepController.text = savedCustomTermSep;
      }
      if (savedCustomCardSep != null) {
        customCardSepController.text = savedCustomCardSep;
      }
      if (savedLanguage != null && savedLanguage.isNotEmpty) {
        selectedLanguage = savedLanguage;
      }
    });
  }

  Future<void> saveCreateCourseSettings() async {
    await Future.wait([
      AppSettingsStore.setString('create.termSeparatorType', termSeparatorType),
      AppSettingsStore.setString('create.cardSeparatorType', cardSeparatorType),
      AppSettingsStore.setString('create.customTermSeparator', customTermSepController.text),
      AppSettingsStore.setString('create.customCardSeparator', customCardSepController.text),
      AppSettingsStore.setString('create.selectedLanguage', selectedLanguage),
    ]);
  }

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
    if (termSeparatorType == "underscore") return "_";
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

  // Nhận phiên âm đặt trong ngoặc cuối dòng.
  // Fix IPA có ngoặc con như: [ˈɑːftə(r)]
  final regex = RegExp(r'^(.*?)\s*\((.*)\)\s*$');
  final match = regex.firstMatch(text);

  if (match == null) {
    return ParsedDefinition(
      definition: text,
      pronunciation: '',
    );
  }

  final definition = match.group(1)?.trim() ?? '';
  final pronunciation = match.group(2)?.trim() ?? '';

  if (definition.isEmpty || pronunciation.isEmpty) {
    return ParsedDefinition(
      definition: text,
      pronunciation: '',
    );
  }

  return ParsedDefinition(
    definition: definition,
    pronunciation: pronunciation,
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

  int? savedCourseId;

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

      savedCourseId = courseId;

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

    final courseId = savedCourseId;
    if (courseId != null) {
      if (mounted) {
        showMessage("Đang tạo âm thanh cho ${items.length} thẻ...");
      }

      await TtsAudioCache.instance.prepareCourseAudio(
        items: items,
        languageCode: getLanguageCode(),
        courseId: courseId,
      );
    }

    if (!mounted) return;

    showMessage("Đã lưu học phần: $title (${items.length} thẻ)");

    // Lưu xong tự quay về Home
    Navigator.pop(context, true);
  } catch (e) {
    showMessage("Lưu thất bại, vui lòng thử lại");
    debugPrint("SAVE COURSE ERROR: $e");
  }
}
  void showMessage(String text) {
    showAppToast(context, text);
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
              margin: EdgeInsets.all(14),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.4,
                ),
                boxShadow: [
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
                          Icon(
                            Icons.settings,
                            color: AppColors.border,
                            size: 26,
                          ),
                          SizedBox(width: 10),
                          Expanded(
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
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      CompactSelectBox(
                        title: "GIỮA THUẬT NGỮ VÀ ĐỊNH NGHĨA",
                        value: termSeparatorType,
                        items: [
                          CompactSelectItem(value: "tab", label: "Tab"),
                          CompactSelectItem(value: "underscore", label: "Gạch dưới _"),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          termSeparatorType = value == "comma" ? "underscore" : value;
                          saveCreateCourseSettings();
                          refresh();
                        },
                        customController: customTermSepController,
                        customHint: "vd: |",
                        showCustomInput: termSeparatorType == "custom",
                        onCustomChanged: (_) {
                          saveCreateCourseSettings();
                          refresh();
                        },
                      ),

                      SizedBox(height: 14),

                      CompactSelectBox(
                        title: "GIỮA CÁC THẺ",
                        value: cardSeparatorType,
                        items: [
                          CompactSelectItem(value: "newline", label: "Dòng mới"),
                          CompactSelectItem(
                              value: "semicolon", label: "Chấm phẩy ;"),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          cardSeparatorType = value;
                          saveCreateCourseSettings();
                          refresh();
                        },
                        customController: customCardSepController,
                        customHint: "vd: ###",
                        showCustomInput: cardSeparatorType == "custom",
                        onCustomChanged: (_) {
                          saveCreateCourseSettings();
                          refresh();
                        },
                      ),

                      SizedBox(height: 14),

                      buildLanguageSetting(modalSetState),

                      SizedBox(height: 18),

                      BigPopupButton(
                        text: "Xong",
                        icon: Icons.check,
                        color: AppColors.green,
                        onTap: () {
                          saveCreateCourseSettings();
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
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle("NGÔN NGỮ HỌC PHẦN"),
          SizedBox(height: 10),
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 14),
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
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                items: [
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
                  DropdownMenuItem(
                    value: "Tiếng Việt (Vietnamese)",
                    child: Text("Tiếng Việt"),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  modalSetState(() {
                    selectedLanguage = value;
                  });
                  saveCreateCourseSettings();
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
                padding: EdgeInsets.fromLTRB(12, 12, 12, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      "NHẬP DỮ LIỆU",
                    ),
                    SizedBox(height: 8),
                    buildDataInput(),

                    if (showPreview) ...[
                      SizedBox(height: 16),
                      buildPreviewTitle(),
                      SizedBox(height: 8),
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
      padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: AppColors.red,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Expanded(
            child: LightInput(
              controller: titleController,
              hintText: "Tên học phần...",
              height: 48,
            ),
          ),
          SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: AppColors.blue,
            onTap: openSettingPopup,
          ),
          SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.visibility,
            color: AppColors.yellow,
            onTap: updatePreview,
          ),
          SizedBox(width: 8),
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
        boxShadow: [
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
        style: TextStyle(
          color: AppColors.text,
          fontSize: 15,
          height: 1.6,
          fontFamily: "monospace",
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
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
        SectionTitle("XEM TRƯỚC"),
        SizedBox(width: 8),
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
      constraints: BoxConstraints(minHeight: 230),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: previewItems.isEmpty
          ? Center(
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
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: AppColors.border,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.term,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              item.definition,
                              style: TextStyle(
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

  StudyCardItem({
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

class ProgressUndoItem {
  final int cardId;
  final int previousPos;
  final bool previousCompletion;
  final bool known;
  final Map<String, Object?>? previousReviewState;
  final int? studyResultId;

  ProgressUndoItem({
    required this.cardId,
    required this.previousPos,
    required this.previousCompletion,
    required this.known,
    required this.previousReviewState,
    required this.studyResultId,
  });
}

class FlashCardsPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  FlashCardsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class _FlashCardsPageState extends State<FlashCardsPage> {
  List<CourseListItem> courseList = [];
  List<StudyCardItem> allCards = [];
  List<int> visibleOrder = [];

  int? selectedCourseId;
  int currentPos = 0;
  String _languageCode = 'zh-TW';

  bool isLoading = true;
  bool progressTracking = false;
  bool shuffleEnabled = false;
  bool starredOnly = false;
  bool autoPlayAudio = false;
  bool isFlipped = false;
  bool showCompletion = false;

  double cardDragDx = 0;
  double cardDragDy = 0;
  double cardDragStartLocalY = 0;
  double cardDragHeight = 1;
  bool isDraggingCard = false;

  int progressKnownCount = 0;
  int progressUnknownCount = 0;
  int? _studySessionId;
  String? _selectedListeningAnswer;
  bool _isPlayingListeningAudio = false;
  bool _studySessionFinished = true;

  // lịch sử để undo khi bật tiến độ
  final List<ProgressUndoItem> _progressHistory = [];
  final Set<int> _sessionUnknownCardIds = {};

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

    loadInitialData();
  }

  @override
  void dispose() {
    _finishStudySession();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    await loadFlashSettings();
    setState(() {
      isLoading = true;
      selectedCourseId = widget.courseId;
    });

    await loadCardsForCourse(widget.courseId);
  }

  Future<void> loadFlashSettings() async {
    final savedStarredOnly = await AppSettingsStore.getBool('flash.starredOnly');
    final savedShuffle = await AppSettingsStore.getBool('flash.shuffleEnabled');
    final savedProgress = await AppSettingsStore.getBool('flash.progressTracking');
    final savedAutoPlay = await AppSettingsStore.getBool('flash.autoPlayAudio');

    if (!mounted) return;

    setState(() {
      starredOnly = savedStarredOnly ?? starredOnly;
      shuffleEnabled = savedShuffle ?? shuffleEnabled;
      progressTracking = savedProgress ?? progressTracking;
      autoPlayAudio = savedAutoPlay ?? autoPlayAudio;
    });
  }

  Future<void> saveFlashSettings() async {
    await Future.wait([
      AppSettingsStore.setBool('flash.starredOnly', starredOnly),
      AppSettingsStore.setBool('flash.shuffleEnabled', shuffleEnabled),
      AppSettingsStore.setBool('flash.progressTracking', progressTracking),
      AppSettingsStore.setBool('flash.autoPlayAudio', autoPlayAudio),
    ]);
  }

  Future<void> _startStudySessionIfNeeded() async {
    if (!progressTracking || selectedCourseId == null || visibleOrder.isEmpty) return;

    await _finishStudySession();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    _studySessionId = await db.insert('study_sessions', {
      'courseId': selectedCourseId,
      'mode': 'flashcard_progress',
      'totalCards': visibleOrder.length,
      'correctCount': 0,
      'wrongCount': 0,
      'startedAt': now,
      'endedAt': null,
    });
    _studySessionFinished = false;
  }

  Future<void> _finishStudySession() async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'study_sessions',
        {
          'correctCount': progressKnownCount,
          'wrongCount': progressUnknownCount,
          'endedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      _studySessionFinished = true;
    } catch (e) {
      debugPrint('FINISH FLASH SESSION ERROR: $e');
    }
  }

  Future<int?> _insertFlashStudyResult({
    required StudyCardItem card,
    required bool known,
  }) async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return null;

    try {
      final db = await AppDatabase.instance.database;
      return await db.insert('study_results', {
        'sessionId': sessionId,
        'cardId': card.id,
        'answerText': known ? 'known' : 'unknown',
        'isCorrect': known ? 1 : 0,
        'responseTimeMs': null,
        'reviewedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('INSERT FLASH RESULT ERROR: $e');
      return null;
    }
  }

  Future<void> _deleteFlashStudyResult(int? resultId, bool known) async {
    final sessionId = _studySessionId;
    if (resultId == null || sessionId == null) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.delete('study_results', where: 'id = ?', whereArgs: [resultId]);
      await db.update(
        'study_sessions',
        {
          'correctCount': progressKnownCount,
          'wrongCount': progressUnknownCount,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('DELETE FLASH RESULT ERROR: $e');
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

      // Load languageCode from course
      final courseRows = await db.query(
        'courses',
        columns: ['languageCode'],
        where: 'id = ?',
        whereArgs: [courseId],
        limit: 1,
      );
      final langCode = courseRows.isNotEmpty
          ? (courseRows.first['languageCode']?.toString() ?? 'zh-TW')
          : 'zh-TW';

      if (!mounted) return;

      setState(() {
        allCards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        _languageCode = langCode;
        currentPos = 0;
        isFlipped = false;
        progressKnownCount = 0;
        progressUnknownCount = 0;
        _progressHistory.clear();
        _sessionUnknownCardIds.clear();
        rebuildVisibleOrder(resetPosition: true);
        isLoading = false;
      });

      await _startStudySessionIfNeeded();
      _playAutoAudioIfNeeded();
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
  }

  void toggleFlip() {
    if (currentCard == null) return;

    setState(() {
      isFlipped = !isFlipped;
    });
  }

  Future<void> moveCard(int delta, {bool playSwipeEffect = true, bool resetSwipeState = false}) async {
    if (currentCard == null) return;

    if (progressTracking) {
      await answerProgress(known: delta > 0, playSwipeEffect: playSwipeEffect, resetSwipeState: resetSwipeState);
      return;
    }

    final nextPos = currentPos + delta;

    if (nextPos < 0) {
      if (resetSwipeState) {
        setState(() {
          isDraggingCard = false;
          cardDragDx = 0;
          cardDragDy = 0;
        });
      }
      showFlashMessage("Đang ở thẻ đầu tiên");
      return;
    }

    if (nextPos >= visibleOrder.length) {
      setState(() {
        showCompletion = true;
        if (resetSwipeState) {
          isDraggingCard = false;
          cardDragDx = 0;
          cardDragDy = 0;
        }
      });
      return;
    }

    setState(() {
      currentPos = nextPos;
      isFlipped = false;
      showCompletion = false;
      if (resetSwipeState) {
        isDraggingCard = false;
        cardDragDx = 0;
        cardDragDy = 0;
      }
    });

    _playAutoAudioIfNeeded();
  }

  Future<void> answerProgress({required bool known, bool playSwipeEffect = true, bool resetSwipeState = false}) async {
    final card = currentCard;
    if (card == null) return;

    final previousPos = currentPos;
    final previousCompletion = showCompletion;
    final previousReviewState = await markCurrentCard(known);
    final studyResultId = await _insertFlashStudyResult(card: card, known: known);
    final nextPos = currentPos + 1;
    final isDone = nextPos >= visibleOrder.length;

    setState(() {
      _progressHistory.add(
        ProgressUndoItem(
          cardId: card.id,
          previousPos: previousPos,
          previousCompletion: previousCompletion,
          known: known,
          previousReviewState: previousReviewState,
          studyResultId: studyResultId,
        ),
      );

      if (known) {
        progressKnownCount++;
      } else {
        progressUnknownCount++;
        _sessionUnknownCardIds.add(card.id);
      }

      isFlipped = false;

      if (isDone) {
        showCompletion = true;
      } else {
        currentPos = nextPos;
        showCompletion = false;
      }

      if (resetSwipeState) {
        isDraggingCard = false;
        cardDragDx = 0;
        cardDragDy = 0;
      }
    });

    if (isDone) {
      await _finishStudySession();
    } else {
      _playAutoAudioIfNeeded();
    }

  }

  void playGhost(bool reverse) {}

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

  Future<Map<String, Object?>?> markCurrentCard(bool known) async {
    final card = currentCard;
    if (card == null) return null;

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(
      'review_states',
      where: 'cardId = ?',
      whereArgs: [card.id],
      limit: 1,
    );

    final previousState = rows.isEmpty ? null : Map<String, Object?>.from(rows.first);

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

    return previousState;
  }

  Future<void> playCurrentCardAudio() async {
    final card = currentCard;
    final courseId = selectedCourseId ?? widget.courseId;

    if (card == null) return;

    try {
      await TtsAudioCache.instance.playText(
        text: card.term,
        languageCode: _languageCode,
        courseId: courseId,
      );
    } catch (e) {
      showFlashMessage("Không phát được âm thanh");
      debugPrint("PLAY TTS ERROR: $e");
    }
  }

  void _playAutoAudioIfNeeded() {
    if (!autoPlayAudio || currentCard == null || showCompletion) return;
    Future.microtask(playCurrentCardAudio);
  }

  Future<void> openEditCardDialog() async {
  final card = currentCard;
  if (card == null) return;

  final termController = TextEditingController(text: card.term);
  final definitionController = TextEditingController(text: card.definition);
  final pronunciationController =
      TextEditingController(text: card.pronunciation);

  String? errorText;

  final result = await showDialog<StudyCardItem>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.48),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget editInput({
            required TextEditingController controller,
            required String label,
            required IconData icon,
            int maxLines = 1,
          }) {
            return TextField(
              controller: controller,
              maxLines: maxLines,
              minLines: maxLines,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, color: AppColors.border, size: 21),
                filled: true,
                fillColor: AppColors.panel,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.border.withOpacity(0.45),
                    width: 1.3,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: 1.8,
                  ),
                ),
              ),
            );
          }

          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Color(0xfff6f1fb),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.14),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Sửa thẻ",
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    editInput(
                      controller: termController,
                      label: "Thuật ngữ",
                      icon: Icons.text_fields_rounded,
                    ),
                    SizedBox(height: 12),
                    editInput(
                      controller: definitionController,
                      label: "Định nghĩa",
                      icon: Icons.menu_book_rounded,
                      maxLines: 3,
                    ),
                    SizedBox(height: 12),
                    editInput(
                      controller: pronunciationController,
                      label: "Phiên âm",
                      icon: Icons.record_voice_over_rounded,
                    ),
                    if (errorText != null) ...[
                      SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Color(0xffb3261e),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.buttonInk,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(
                                color: AppColors.border,
                                width: 1.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "Hủy",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final term = termController.text.trim();
                              final definition =
                                  definitionController.text.trim();
                              final pronunciation =
                                  pronunciationController.text.trim();

                              if (term.isEmpty) {
                                setDialogState(() {
                                  errorText = "Vui lòng nhập thuật ngữ";
                                });
                                return;
                              }

                              if (definition.isEmpty) {
                                setDialogState(() {
                                  errorText = "Vui lòng nhập định nghĩa";
                                });
                                return;
                              }

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
                              foregroundColor: AppColors.buttonInk,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppColors.border,
                                  width: 1.3,
                                ),
                              ),
                            ),
                            child: Text(
                              "Lưu",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
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

  termController.dispose();
  definitionController.dispose();
  pronunciationController.dispose();

  if (result == null) return;

  try {
    final db = await AppDatabase.instance.database;

    final rawText = result.pronunciation.trim().isEmpty
        ? '${result.term}\t${result.definition}'
        : '${result.term}\t${result.definition} (${result.pronunciation})';

    await db.update(
      'cards',
      {
        'term': result.term,
        'definition': result.definition,
        'pronunciation': result.pronunciation,
        'rawText': rawText,
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

    await TtsAudioCache.instance.ensureAudioForText(
      text: result.term,
      languageCode: _languageCode,
      courseId: result.courseId,
    );

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
    saveFlashSettings();
  }

  void toggleStarredOnly() {
    setState(() {
      starredOnly = !starredOnly;
      rebuildVisibleOrder(resetPosition: true);
      resetFlip();
    });
    saveFlashSettings();
  }

  Future<void> toggleProgressMode() async {
    final nextValue = !progressTracking;

    await _finishStudySession();

    setState(() {
      progressTracking = nextValue;
      currentPos = 0;
      showCompletion = false;
      progressKnownCount = 0;
      progressUnknownCount = 0;
      _progressHistory.clear();
      _sessionUnknownCardIds.clear();
      rebuildVisibleOrder(resetPosition: true);
      resetFlip();
    });

    await saveFlashSettings();

    if (progressTracking) {
      await _startStudySessionIfNeeded();
    }
  }

  void toggleAutoPlayAudio() {
    setState(() {
      autoPlayAudio = !autoPlayAudio;
    });
    saveFlashSettings();
    _playAutoAudioIfNeeded();
  }

  Future<void> restartStudy() async {
  await _finishStudySession();
  setState(() {
    currentPos = 0;
    showCompletion = false;
    progressKnownCount = 0;
    progressUnknownCount = 0;
    _progressHistory.clear();
    _sessionUnknownCardIds.clear();
    rebuildVisibleOrder(resetPosition: true);
    resetFlip();
  });
  await _startStudySessionIfNeeded();
}
Future<void> restartUnknownCards() async {
  if (_sessionUnknownCardIds.isEmpty) {
    showFlashMessage("Không có thẻ chưa thuộc để học lại");
    return;
  }

  final unknownIndices = <int>[];

  for (int i = 0; i < allCards.length; i++) {
    if (_sessionUnknownCardIds.contains(allCards[i].id)) {
      unknownIndices.add(i);
    }
  }

  if (unknownIndices.isEmpty) {
    showFlashMessage("Không tìm thấy thẻ chưa thuộc");
    return;
  }

  await _finishStudySession();

  setState(() {
    visibleOrder = unknownIndices;
    currentPos = 0;
    showCompletion = false;
    progressKnownCount = 0;
    progressUnknownCount = 0;
    _progressHistory.clear();
    _sessionUnknownCardIds.clear();
    isFlipped = false;
  });
  await _startStudySessionIfNeeded();
}

Future<void> resetMemorizedCards() async {
  try {
    final db = await AppDatabase.instance.database;

    await db.delete(
      'review_states',
      where: '''
        cardId IN (
          SELECT id FROM cards
          WHERE courseId = ? AND deletedAt IS NULL
        )
      ''',
      whereArgs: [selectedCourseId],
    );

    if (!mounted) return;

    setState(() {
      progressKnownCount = 0;
      progressUnknownCount = 0;
      _progressHistory.clear();
      _sessionUnknownCardIds.clear();
      currentPos = 0;
      showCompletion = false;
      isFlipped = false;
      rebuildVisibleOrder(resetPosition: true);
    });

    await _finishStudySession();
    await _startStudySessionIfNeeded();

    showFlashMessage("Đã đặt lại thẻ ghi nhớ");
  } catch (e) {
    showFlashMessage("Không đặt lại được thẻ ghi nhớ");
    debugPrint("RESET MEMORY ERROR: $e");
  }
}

void exitFlashCards() {
  _finishStudySession();
  Navigator.pop(context, true);
}
  Future<void> undoLastCard() async {
    if (_progressHistory.isEmpty) return;

    final undoItem = _progressHistory.removeLast();

    try {
      final db = await AppDatabase.instance.database;

      if (undoItem.previousReviewState == null) {
        await db.delete(
          'review_states',
          where: 'cardId = ?',
          whereArgs: [undoItem.cardId],
        );
      } else {
        final restored = Map<String, Object?>.from(undoItem.previousReviewState!);
        restored.remove('id');
        await db.update(
          'review_states',
          restored,
          where: 'cardId = ?',
          whereArgs: [undoItem.cardId],
        );
      }
    } catch (e) {
      debugPrint("UNDO ERROR: $e");
    }

    setState(() {
      if (undoItem.known && progressKnownCount > 0) {
        progressKnownCount--;
      }
      if (!undoItem.known && progressUnknownCount > 0) {
  progressUnknownCount--;
  _sessionUnknownCardIds.remove(undoItem.cardId);
}

      currentPos = undoItem.previousPos;
      showCompletion = undoItem.previousCompletion;
      isFlipped = false;
    });

    await _deleteFlashStudyResult(undoItem.studyResultId, undoItem.known);

  }

  void openMicOverlay() {
    final card = currentCard;
    if (card == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => PronunciationOverlay(
        targetText: card.term,
        subText: card.pronunciation.isNotEmpty
            ? card.pronunciation
            : card.definition,
        languageCode: _getCourseLanguageCode(),
      ),
    );
  }

  String _getCourseLanguageCode() {
    return _languageCode;
  }

  void showFlashMessage(String text) {
    showAppToast(context, text);
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
                padding: EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    onTap();
                    setSheetState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(14),
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
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 48,
                          height: 26,
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: value ? AppColors.border : AppColors.muted,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment:
                              value ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
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
              padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
              decoration: BoxDecoration(
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
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Text(
                      "Cài đặt Flash Card",
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18),
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
                    settingRow(
                      title: "Theo dõi tiến độ",
                      value: progressTracking,
                      onTap: toggleProgressMode,
                    ),
                    settingRow(
                      title: "Tự động phát âm",
                      value: autoPlayAudio,
                      onTap: toggleAutoPlayAudio,
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
          title: Text("Xóa thẻ"),
          content: Text("Xóa thẻ \"${card.term}\"?"),
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
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.border,
                          ),
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
                                            padding: EdgeInsets.fromLTRB(
                                              18,
                                              16,
                                              18,
                                              8,
                                            ),
                                            child: Stack(
  children: [
    buildPeekCard(),
    buildFlashCard(card!),

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
      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: AppColors.panel,
            onTap: () => Navigator.pop(context, true),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.panel,
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
              child: Center(
                child: Text(
                  widget.courseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: AppColors.panel,
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
        padding: EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
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
              Icon(Icons.style_outlined, size: 54, color: AppColors.border),
              SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
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
    if (visibleOrder.isEmpty || cardDragDx.abs() < 1) return null;

    // Khi bật theo dõi tiến độ: chỉ preview thẻ sau, không preview thẻ trước.
    final peekPos = progressTracking
        ? currentPos + 1
        : (cardDragDx > 0 ? currentPos - 1 : currentPos + 1);
    if (peekPos < 0 || peekPos >= visibleOrder.length) return null;

    final realIndex = visibleOrder[peekPos];
    if (realIndex < 0 || realIndex >= allCards.length) return null;

    return allCards[realIndex];
  }

  Widget buildPeekCard() {
    if (!isDraggingCard || cardDragDx.abs() < 1) {
      return SizedBox.shrink();
    }

    final peekCard = getPeekCard();
    if (peekCard == null) return SizedBox.shrink();

    return IgnorePointer(
      child: buildCardFace(
        label: "",
        mainText: peekCard.term,
        subText: peekCard.pronunciation,
        isBack: false,
        isStarred: peekCard.isFavorite,
        showLabelChip: false,
      ),
    );
  }

  Future<void> finishSwipeCard(int delta) async {
    await moveCard(delta, playSwipeEffect: false, resetSwipeState: true);
  }

  Widget buildFlipCardFace(StudyCardItem card) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isFlipped ? math.pi : 0),
      duration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final showBack = value > math.pi / 2;
        final face = showBack
            ? buildCardFace(
                label: "Mặt sau",
                mainText: card.definition,
                subText: card.pronunciation,
                isBack: true,
                isStarred: card.isFavorite,
              )
            : buildCardFace(
                label: "Mặt trước",
                mainText: card.term,
                subText: card.pronunciation,
                isBack: false,
                isStarred: card.isFavorite,
              );

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showBack ? value - math.pi : value),
          child: face,
        );
      },
    );
  }

  Widget buildFlashCard(StudyCardItem card) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
        final cardHeight = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
        final double verticalTouchFactor =
            (((cardDragStartLocalY / cardDragHeight) - 0.5).clamp(-0.5, 0.5) * 2).toDouble();
        final double dragPercent =
            (cardDragDx / cardWidth).clamp(-1.0, 1.0).toDouble();
        final double rotate = dragPercent * 0.35 * verticalTouchFactor;
        final double progressDragAbs =
            (cardDragDx.abs() / (cardWidth * 0.5)).clamp(0.0, 1.0).toDouble();
        final showProgressDragState = progressTracking && isDraggingCard && cardDragDx.abs() > 14;
        final progressDragKnown = cardDragDx > 0;
        final progressDragColor = progressDragKnown ? AppColors.green : AppColors.red;
        final progressDragText = progressDragKnown ? 'Đã thuộc' : 'Chưa thuộc';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (cardDragDx.abs() < 6 && cardDragDy.abs() < 6) {
              toggleFlip();
            }
          },
          onPanStart: (details) {
            setState(() {
              isDraggingCard = true;
              cardDragDx = 0;
              cardDragDy = 0;
              cardDragHeight = cardHeight;
              cardDragStartLocalY = details.localPosition.dy.clamp(0.0, cardHeight);
            });
          },
          onPanUpdate: (details) {
            setState(() {
              cardDragDx = (cardDragDx + details.delta.dx).clamp(-cardWidth * 0.86, cardWidth * 0.86);
              cardDragDy = (cardDragDy + details.delta.dy).clamp(-cardHeight * 0.34, cardHeight * 0.34);
            });
          },
          onPanEnd: (details) async {
            final velocityX = details.velocity.pixelsPerSecond.dx;
            final double swipeLimit = progressTracking ? cardWidth * 0.5 : cardWidth * 0.28;
            final shouldSwipeLeft = cardDragDx < -swipeLimit || velocityX < -650;
            final shouldSwipeRight = cardDragDx > swipeLimit || velocityX > 650;

            if (shouldSwipeLeft) {
              await finishSwipeCard(progressTracking ? -1 : 1);
              return;
            }

            if (shouldSwipeRight) {
              await finishSwipeCard(progressTracking ? 1 : -1);
              return;
            }

            setState(() {
              isDraggingCard = false;
              cardDragDx = 0;
              cardDragDy = 0;
            });
          },
          onPanCancel: () {
            setState(() {
              isDraggingCard = false;
              cardDragDx = 0;
              cardDragDy = 0;
            });
          },
          child: Transform.translate(
            offset: Offset(cardDragDx, cardDragDy),
            child: Transform.rotate(
              angle: rotate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildFlipCardFace(card),
                  if (showProgressDragState)
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: progressDragColor.withOpacity(0.65 + 0.35 * progressDragAbs),
                            width: 2.2 + 2.4 * progressDragAbs,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: progressDragColor.withOpacity(0.28 + 0.32 * progressDragAbs),
                              blurRadius: 18 + 18 * progressDragAbs,
                              spreadRadius: 1 + 3 * progressDragAbs,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showProgressDragState)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            color: progressDragColor.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.78), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: progressDragColor.withOpacity(0.42),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            progressDragText,
                            style: TextStyle(
                              color: AppColors.readableOn(progressDragColor),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCardFace({
    required String label,
    required String mainText,
    required String subText,
    required bool isBack,
    required bool isStarred,
    bool showLabelChip = true,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
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
              padding: EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Row(
                children: [
                  if (showLabelChip)
                    Container(
                      padding: EdgeInsets.symmetric(
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
                        style: TextStyle(
                          color: AppColors.border,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Spacer(),
                  buildCardIcon(Icons.edit, openEditCardDialog),
                  buildCardIcon(Icons.volume_up_outlined, playCurrentCardAudio),
                  buildCardIcon(Icons.mic_none, openMicOverlay),
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
                  padding: EdgeInsets.symmetric(horizontal: 24),
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
            subText.trim().isEmpty
                ? SizedBox(height: 48)
                : Container(
                    height: 56,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
            color: active ? Color(0xffffb020) : AppColors.border,
          ),
        ),
      ),
    );
  }


  Widget buildCompletionOverlay() {
  return Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.panel.withOpacity(0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: AppColors.border,
            ),
            SizedBox(height: 14),
            Text(
              "Hoàn thành bộ thẻ",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              progressTracking
                  ? "Đã thuộc $progressKnownCount thẻ, chưa thuộc $progressUnknownCount thẻ."
                  : "Bạn đã đi hết $displayTotal thẻ.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                buildFinishButton(
                  text: "Học lại",
                  icon: Icons.refresh_rounded,
                  color: AppColors.yellow,
                  onTap: restartStudy,
                ),
                buildFinishButton(
                  text: "Thẻ chưa thuộc",
                  icon: Icons.school_outlined,
                  color: AppColors.red,
                  onTap: restartUnknownCards,
                ),
                buildFinishButton(
                  text: "Đặt lại ghi nhớ",
                  icon: Icons.restart_alt_rounded,
                  color: Colors.white,
                  onTap: resetMemorizedCards,
                ),
                buildFinishButton(
                  text: "Thoát",
                  icon: Icons.logout_rounded,
                  color: AppColors.blue,
                  onTap: exitFlashCards,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
Widget buildFinishButton({
  required String text,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.border),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.border,
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
      padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.panel.withOpacity(0.94),
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          Spacer(),
          buildRoundNavButton(
            icon: progressTracking ? Icons.close : Icons.chevron_left,
            onTap: showCompletion
    ? null
    : progressTracking
        ? () => moveCard(-1)
        : (canPrev ? () => moveCard(-1) : null),
            color: progressTracking ? AppColors.red : AppColors.panel,
          ),
          Container(
            width: 76,
            alignment: Alignment.center,
            child: Text(
              progressTracking
                  ? "✓$progressKnownCount  ✕$progressUnknownCount\n$displayIndex / $displayTotal"
                  : "$displayIndex / $displayTotal",
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          buildRoundNavButton(
            icon: progressTracking ? Icons.check : Icons.chevron_right,
            onTap: showCompletion ? null : () => moveCard(1),
            color: progressTracking ? AppColors.green : AppColors.panel,
          ),
          Spacer(),
          if (progressTracking)
            Opacity(
              opacity: _progressHistory.isNotEmpty ? 1.0 : 0.28,
              child: GestureDetector(
                onTap: _progressHistory.isNotEmpty ? undoLastCard : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.undo_rounded,
                    color: AppColors.border,
                    size: 22,
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 44),
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
            boxShadow: [
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
        color: active ? Color(0xffffb020) : AppColors.border,
      ),
    );
  }
}




class ReviewPracticePage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String courseLanguageCode;

  ReviewPracticePage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseLanguageCode,
  });

  @override
  State<ReviewPracticePage> createState() => _ReviewPracticePageState();
}

class _ReviewPracticePageState extends State<ReviewPracticePage> {
  final math.Random _random = math.Random();
  final TextEditingController _essayController = TextEditingController();
  final ScrollController _mcScrollController = ScrollController();
  final Map<int, GlobalKey> _questionKeys = {};

  List<StudyCardItem> _cards = [];
  List<StudyCardItem> _quizCards = [];
  Map<int, List<String>> _choiceMap = {};
  Set<int> _answeredCards = {};
  Map<int, bool> _correctMap = {};
  Map<int, String> _selectedAnswerMap = {};

  bool _isLoading = true;
  bool _showSetup = true;
  bool _multipleChoice = true;
  bool _essay = false;
  bool _listening = false;
  bool _answerByDefinition = true;
  bool _finished = false;
  int _questionLimit = 0;
  int _currentEssayIndex = 0;
  int? _studySessionId;
  String? _selectedListeningAnswer;
  bool _isPlayingListeningAudio = false;
  bool _studySessionFinished = true;
  DateTime? _sessionStartedAt;
  DateTime _essayQuestionStartedAt = DateTime.now();
  final Set<int> _recordedResultCardIds = {};
  final Map<int, DateTime> _cardStartedAtMap = {};

  int get _total => _quizCards.length;
  int get _done => _answeredCards.length;
  int get _correct => _correctMap.values.where((e) => e).length;
  int get _wrong => _done - _correct;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _finishStudySession();
    _essayController.dispose();
    _mcScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    try {
      await _loadReviewSettings();
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'cards',
        where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
        whereArgs: [widget.courseId],
        orderBy: 'position ASC, id ASC',
      );

      if (!mounted) return;

      setState(() {
        _cards = rows.map((e) => StudyCardItem.fromMap(e)).toList();
        _questionLimit = _cards.isEmpty
            ? 0
            : (_questionLimit <= 0
                ? _cards.length
                : _questionLimit.clamp(1, _cards.length).toInt());
        _isLoading = false;
      });

      if (_cards.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openSetupSheet();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Không tải được thẻ ôn tập');
      debugPrint('LOAD REVIEW CARDS ERROR: $e');
    }
  }

  Future<void> _loadReviewSettings() async {
    final savedMultipleChoice = await AppSettingsStore.getBool('review.multipleChoice');
    final savedEssay = await AppSettingsStore.getBool('review.essay');
    final savedListening = await AppSettingsStore.getBool('review.listening');
    final savedAnswerByDefinition = await AppSettingsStore.getBool('review.answerByDefinition');
    final savedQuestionLimit = await AppSettingsStore.getInt('review.questionLimit');

    if (!mounted) return;

    setState(() {
      _multipleChoice = savedMultipleChoice ?? _multipleChoice;
      _essay = savedEssay ?? _essay;
      _listening = savedListening ?? _listening;

      final activeModes = [_multipleChoice, _essay, _listening].where((e) => e).length;
      if (activeModes == 0) {
        _multipleChoice = true;
      }
      if (activeModes > 1) {
        _essay = false;
        _listening = false;
        _multipleChoice = true;
      }

      _answerByDefinition = savedAnswerByDefinition ?? _answerByDefinition;
      if (savedQuestionLimit != null && savedQuestionLimit > 0) {
        _questionLimit = savedQuestionLimit;
      }
    });
  }

  Future<void> _saveReviewSettings() async {
    await Future.wait([
      AppSettingsStore.setBool('review.multipleChoice', _multipleChoice),
      AppSettingsStore.setBool('review.essay', _essay),
      AppSettingsStore.setBool('review.listening', _listening),
      AppSettingsStore.setBool('review.answerByDefinition', _answerByDefinition),
      AppSettingsStore.setInt('review.questionLimit', _questionLimit),
    ]);
  }

  Future<void> _startStudySession({required String mode, required int totalCards}) async {
    await _finishStudySession();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    _sessionStartedAt = now;

    _studySessionId = await db.insert('study_sessions', {
      'courseId': widget.courseId,
      'mode': mode,
      'totalCards': totalCards,
      'correctCount': 0,
      'wrongCount': 0,
      'startedAt': now.toIso8601String(),
      'endedAt': null,
    });

    _studySessionFinished = false;
    _recordedResultCardIds.clear();
    _cardStartedAtMap
      ..clear()
      ..addEntries(_quizCards.map((card) => MapEntry(card.id, now)));
  }

  Future<void> _finishStudySession() async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;

    try {
      final db = await AppDatabase.instance.database;
      await db.update(
        'study_sessions',
        {
          'correctCount': _correct,
          'wrongCount': _wrong,
          'endedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      _studySessionFinished = true;
    } catch (e) {
      debugPrint('FINISH REVIEW SESSION ERROR: $e');
    }
  }

  Future<void> _markReviewStateForCard({
    required int cardId,
    required bool isCorrect,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(
      'review_states',
      where: 'cardId = ?',
      whereArgs: [cardId],
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('review_states', {
        'cardId': cardId,
        'level': isCorrect ? 1 : 0,
        'easeFactor': 2.5,
        'intervalDays': isCorrect ? 1 : 0,
        'repetitionCount': 1,
        'correctCount': isCorrect ? 1 : 0,
        'wrongCount': isCorrect ? 0 : 1,
        'lastReviewedAt': now,
        'nextReviewAt': now,
        'createdAt': now,
        'updatedAt': now,
      });
      return;
    }

    final row = rows.first;
    await db.update(
      'review_states',
      {
        'level': isCorrect ? 1 : 0,
        'repetitionCount': (row['repetitionCount'] as int? ?? 0) + 1,
        'correctCount': (row['correctCount'] as int? ?? 0) + (isCorrect ? 1 : 0),
        'wrongCount': (row['wrongCount'] as int? ?? 0) + (isCorrect ? 0 : 1),
        'lastReviewedAt': now,
        'updatedAt': now,
      },
      where: 'cardId = ?',
      whereArgs: [cardId],
    );
  }

  Future<void> _recordStudyResult({
    required StudyCardItem card,
    required String answerText,
    required bool isCorrect,
  }) async {
    final sessionId = _studySessionId;
    if (sessionId == null || _studySessionFinished) return;
    if (_recordedResultCardIds.contains(card.id)) return;

    final now = DateTime.now();
    final startedAt = _cardStartedAtMap[card.id] ?? _essayQuestionStartedAt;
    final responseMs = now.difference(startedAt).inMilliseconds.clamp(0, 2147483647);

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('study_results', {
        'sessionId': sessionId,
        'cardId': card.id,
        'answerText': answerText,
        'isCorrect': isCorrect ? 1 : 0,
        'responseTimeMs': responseMs,
        'reviewedAt': now.toIso8601String(),
      });

      await _markReviewStateForCard(cardId: card.id, isCorrect: isCorrect);

      _recordedResultCardIds.add(card.id);

      await db.update(
        'study_sessions',
        {
          'correctCount': _correctMap.values.where((e) => e).length,
          'wrongCount': _answeredCards.length - _correctMap.values.where((e) => e).length,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('INSERT REVIEW RESULT ERROR: $e');
    }
  }

  void _showMessage(String text) {
    showAppToast(context, text);
  }

  String _promptOf(StudyCardItem card) {
    return _answerByDefinition ? card.term : card.definition;
  }

  String _subPromptOf(StudyCardItem card) {
    // Ôn tập/kiểm tra không hiện phiên âm trong câu hỏi.
    return '';
  }

  String _answerOf(StudyCardItem card) {
    return _answerByDefinition ? card.definition : card.term;
  }

  String _optionLabelOf(StudyCardItem card) {
    // Đáp án trắc nghiệm chỉ hiện nội dung đáp án, không kèm phiên âm.
    return _answerOf(card);
  }

  String _normalizeAnswer(String value) {
    return normalizeText(value)
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _splitAnswerParts(String rawAnswer) {
    final seen = <String>{};
    final parts = <String>[];

    // Tách từng nghĩa riêng để chip không bị dính kiểu:
    // "chẳng bao lâu nữa, chẳng mấy chốc, sắp; ngay".
    // Không tách dấu cách thường, vì cụm từ như "xin chào" phải giữ nguyên.
    final cleaned = rawAnswer.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final separators = RegExp(r'[,/;；、，|\n\r]+');

    for (final item in cleaned.split(separators)) {
      final text = item.trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = _normalizeAnswer(text);
      if (text.isEmpty || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      parts.add(text);
    }

    return parts;
  }

  List<String> _acceptedEssayAnswersOf(StudyCardItem card) {
    final rawAnswer = _answerOf(card);
    final parts = _splitAnswerParts(rawAnswer)
        .map(_normalizeAnswer)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final fullAnswer = _normalizeAnswer(rawAnswer);
    if (fullAnswer.isNotEmpty && !parts.contains(fullAnswer)) {
      parts.add(fullAnswer);
    }

    return parts;
  }

  List<String> _acceptedListeningAnswersOf(StudyCardItem card) {
    final parts = _splitAnswerParts(card.definition)
        .map(_normalizeAnswer)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final fallback = _normalizeAnswer(card.definition);
    return parts.isNotEmpty ? parts : (fallback.isEmpty ? <String>[] : <String>[fallback]);
  }

  List<String> _splitListeningChoiceParts(String rawAnswer) {
    final seen = <String>{};
    final chips = <String>[];

    // Riêng chế độ nghe: tách thêm dấu cách để người dùng ghép nhiều chip
    // thành cụm nghĩa, ví dụ: "xin chào" -> "xin" + "chào".
    final meanings = _splitAnswerParts(rawAnswer);
    final sourceParts = meanings.isNotEmpty ? meanings : [rawAnswer.trim()];

    for (final meaning in sourceParts) {
      for (final item in meaning.split(RegExp(r'\s+'))) {
        final text = item.trim();
        final key = _normalizeAnswer(text);
        if (text.isEmpty || key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        chips.add(text);
      }
    }

    return chips;
  }

  bool _isEssayAnswerCorrect(StudyCardItem card, String typed) {
    final answer = _normalizeAnswer(typed);
    if (answer.isEmpty) return false;
    return _acceptedEssayAnswersOf(card).contains(answer);
  }

  List<String> _buildChoices(StudyCardItem target) {
    final correct = _optionLabelOf(target);
    final wrongPool = _cards
        .where((e) => e.id != target.id)
        .map(_optionLabelOf)
        .where((e) => e.trim().isNotEmpty && e.trim() != correct.trim())
        .toSet()
        .toList();

    wrongPool.shuffle(_random);
    final options = <String>[correct, ...wrongPool.take(3)];

    while (options.length < 4) {
      options.add('Đáp án ${options.length + 1}');
    }

    options.shuffle(_random);
    return options;
  }

  Future<void> _startQuiz() async {
    if (_cards.isEmpty) return;

    final copied = List<StudyCardItem>.from(_cards)..shuffle(_random);
    final limit = _questionLimit.clamp(1, _cards.length).toInt();
    final selected = copied.take(limit).toList();
    final now = DateTime.now();

    setState(() {
      _quizCards = selected;
      _choiceMap = {
        for (final card in selected)
          card.id: _listening ? _buildListeningChoices(card) : _buildChoices(card),
      };
      _questionKeys
        ..clear()
        ..addEntries(
          selected.map((card) => MapEntry(card.id, GlobalKey())),
        );
      _answeredCards.clear();
      _correctMap.clear();
      _selectedAnswerMap.clear();
      _selectedListeningAnswer = null;
      _recordedResultCardIds.clear();
      _cardStartedAtMap
        ..clear()
        ..addEntries(selected.map((card) => MapEntry(card.id, now)));
      _finished = false;
      _showSetup = false;
      _currentEssayIndex = 0;
      _essayQuestionStartedAt = now;
      _essayController.clear();
    });

    await _startStudySession(
      mode: _listening
          ? 'review_listening'
          : (_multipleChoice ? 'review_multiple_choice' : 'review_essay'),
      totalCards: selected.length,
    );

    if (_listening) {
      Future.delayed(Duration(milliseconds: 260), () {
        if (mounted && _listening) _playListeningAudio();
      });
    }
  }

  Future<void> _restart() async {
    await _finishStudySession();
    setState(() {
      _showSetup = true;
      _finished = false;
    });
    _openSetupSheet();
  }

  Future<void> _answerCard(StudyCardItem card, String selected) async {
    if (_answeredCards.contains(card.id) || _finished) return;

    final correctText = _optionLabelOf(card);
    final isCorrect = _normalizeAnswer(selected) == _normalizeAnswer(correctText);

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = isCorrect;
      _selectedAnswerMap[card.id] = selected;
    });

    await _recordStudyResult(
      card: card,
      answerText: selected,
      isCorrect: isCorrect,
    );

    _scrollToNextUnanswered(card);
  }

  Future<void> _skipCard(StudyCardItem card) async {
    await _answerCard(card, '');
  }

  void _scrollToNextUnanswered(StudyCardItem currentCard) {
    final currentIndex = _quizCards.indexWhere((e) => e.id == currentCard.id);
    if (currentIndex < 0) return;

    final nextIndex = _quizCards.indexWhere(
      (e) => !_answeredCards.contains(e.id),
      currentIndex + 1,
    );

    if (nextIndex < 0) return;
    _scrollToQuestion(_quizCards[nextIndex].id);
  }

  void _scrollToFirstWrong() {
    StudyCardItem? wrongCard;

    for (final card in _quizCards) {
      if (_correctMap[card.id] != true) {
        wrongCard = card;
        break;
      }
    }

    if (wrongCard == null) return;
    _scrollToQuestion(wrongCard.id);
  }

  List<StudyCardItem> get _wrongReviewCards {
    return _quizCards.where((card) => _correctMap[card.id] != true).toList();
  }

  void _openWrongReviewFromResult() {
    final wrongCards = _wrongReviewCards;
    if (wrongCards.isEmpty) {
      _showMessage('Không có câu sai để xem lại');
      return;
    }

    Navigator.pop(context);
    final firstWrong = wrongCards.first;
    final firstWrongIndex = _quizCards.indexWhere((e) => e.id == firstWrong.id);

    setState(() {
      if ((_essay || _listening) && !_multipleChoice && firstWrongIndex >= 0) {
        _currentEssayIndex = firstWrongIndex;
        _selectedListeningAnswer = null;
        _essayController.clear();
      }
    });

    _showWrongReviewSheet(initialIndex: 0);
  }

  Future<void> _showWrongReviewSheet({int initialIndex = 0}) async {
    final wrongCards = _wrongReviewCards;
    if (wrongCards.isEmpty) return;

    var reviewIndex = initialIndex.clamp(0, wrongCards.length - 1).toInt();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final wrongCard = wrongCards[reviewIndex];
            final realIndex = _quizCards.indexWhere((e) => e.id == wrongCard.id);
            final yourAnswer = (_selectedAnswerMap[wrongCard.id] ?? '').trim();
            final promptText = _listening ? wrongCard.term.trim() : _promptOf(wrongCard).trim();
            final correctAnswer = (_listening ? wrongCard.definition : _answerOf(wrongCard)).trim();
            final promptTitle = _listening
                ? 'Âm thanh đã phát'
                : (_answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa');

            void moveReview(int delta) {
              final nextIndex = (reviewIndex + delta).clamp(0, wrongCards.length - 1).toInt();
              if (nextIndex == reviewIndex) return;

              setSheetState(() {
                reviewIndex = nextIndex;
              });

              final nextCard = wrongCards[nextIndex];
              final nextRealIndex = _quizCards.indexWhere((e) => e.id == nextCard.id);
              if ((_essay || _listening) && !_multipleChoice && nextRealIndex >= 0) {
                setState(() {
                  _currentEssayIndex = nextRealIndex;
                  _selectedListeningAnswer = null;
                  _essayController.clear();
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 760),
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                  child: SingleChildScrollView(
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
                                    'Câu sai ${reviewIndex + 1}/${wrongCards.length}',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    realIndex >= 0 ? 'Câu ${realIndex + 1}/$_total' : 'Xem lại câu sai',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(Icons.close_rounded, color: AppColors.border),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        Text(
                          promptTitle,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1.2),
                          ),
                          child: Text(
                            promptText.isEmpty ? 'Không có nội dung' : promptText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: promptText.length > 22 ? 24 : 30,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Bạn trả lời',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        _reviewAnswerBox(
                          text: yourAnswer.isEmpty ? 'Đã bỏ qua' : yourAnswer,
                          icon: yourAnswer.isEmpty ? Icons.skip_next_rounded : Icons.close_rounded,
                          color: AppColors.red,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Đáp án đúng',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        _reviewAnswerBox(
                          text: correctAnswer.isEmpty ? 'Chưa có đáp án' : correctAnswer,
                          icon: Icons.check_rounded,
                          color: AppColors.green,
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 54,
                              child: _outlineButton(
                                text: '',
                                icon: Icons.chevron_left_rounded,
                                onTap: reviewIndex <= 0 ? () {} : () => moveReview(-1),
                              ),
                            ),
                            Spacer(),
                            _statChip(text: '${reviewIndex + 1}/${wrongCards.length}', color: AppColors.blue),
                            Spacer(),
                            SizedBox(
                              width: 54,
                              child: _outlineButton(
                                text: '',
                                icon: Icons.chevron_right_rounded,
                                onTap: reviewIndex >= wrongCards.length - 1 ? () {} : () => moveReview(1),
                              ),
                            ),
                          ],
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
  }

  void _scrollToQuestion(int cardId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _questionKeys[cardId]?.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  Future<void> _submitMultipleChoice() async {
    if (_quizCards.isEmpty) return;

    final skippedCards = <StudyCardItem>[];

    setState(() {
      for (final card in _quizCards) {
        if (!_answeredCards.contains(card.id)) {
          skippedCards.add(card);
          _answeredCards.add(card.id);
          _correctMap[card.id] = false;
          _selectedAnswerMap[card.id] = '';
        }
      }
      _finished = true;
    });

    for (final card in skippedCards) {
      await _recordStudyResult(
        card: card,
        answerText: '',
        isCorrect: false,
      );
    }

    await _finishStudySession();
    _scrollToFirstWrong();
  }

  void _moveEssayPrevious() {
    if (_currentEssayIndex <= 0 || _finished) return;

    final previousIndex = _currentEssayIndex - 1;
    final previousCard = _quizCards[previousIndex];

    setState(() {
      _currentEssayIndex = previousIndex;
      _essayController.text = _selectedAnswerMap[previousCard.id] ?? '';
      _essayQuestionStartedAt = DateTime.now();
    });
  }

  Future<void> _submitEssay({bool allowEmptyAsSkip = false}) async {
    if (_quizCards.isEmpty) return;
    final card = _quizCards[_currentEssayIndex];
    final typed = _essayController.text.trim();

    if (typed.isEmpty && !allowEmptyAsSkip) {
      _showMessage('Nhập câu trả lời trước');
      return;
    }

    final ok = _isEssayAnswerCorrect(card, typed);
    final wasLast = _currentEssayIndex + 1 >= _quizCards.length;

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = ok;
      _selectedAnswerMap[card.id] = typed;

      if (wasLast) {
        _finished = true;
        _essayController.clear();
      } else {
        _currentEssayIndex++;
        final nextCard = _quizCards[_currentEssayIndex];
        _essayController.text = _selectedAnswerMap[nextCard.id] ?? '';
        _essayQuestionStartedAt = DateTime.now();
      }
    });

    await _recordStudyResult(
      card: card,
      answerText: typed,
      isCorrect: ok,
    );

    if (_finished) {
      await _finishStudySession();
      _showResultSheet();
    }
  }


  List<String> _buildListeningChoices(StudyCardItem target) {
    final correctOptions = _splitListeningChoiceParts(target.definition);
    final correctKeys = correctOptions.map(_normalizeAnswer).where((e) => e.isNotEmpty).toSet();
    final seenWrongKeys = <String>{};

    final wrongPool = _cards
        .where((e) => e.id != target.id)
        .expand((e) => _splitListeningChoiceParts(e.definition))
        .where((e) {
          final key = _normalizeAnswer(e);
          if (key.isEmpty || correctKeys.contains(key) || seenWrongKeys.contains(key)) return false;
          seenWrongKeys.add(key);
          return true;
        })
        .toList();

    wrongPool.shuffle(_random);
    final targetCount = correctOptions.length >= 6 ? correctOptions.length + 2 : 6;
    final options = <String>[
      ...correctOptions.where((e) => e.trim().isNotEmpty),
      ...wrongPool.take(targetCount - correctOptions.length),
    ];

    while (options.length < 4) {
      options.add('Lựa chọn ${options.length + 1}');
    }

    options.shuffle(_random);
    return options;
  }

  Future<void> _playListeningAudio() async {
    if (_quizCards.isEmpty || _finished || _isPlayingListeningAudio) return;

    final card = _quizCards[_currentEssayIndex];
    setState(() => _isPlayingListeningAudio = true);

    try {
      await TtsAudioCache.instance.playText(
        text: card.term,
        languageCode: widget.courseLanguageCode.isNotEmpty ? widget.courseLanguageCode : 'zh-TW',
        courseId: widget.courseId,
      );
    } catch (e) {
      _showMessage('Không phát được âm thanh');
      debugPrint('PLAY LISTENING TTS ERROR: $e');
    } finally {
      if (mounted) setState(() => _isPlayingListeningAudio = false);
    }
  }

  Future<void> _submitListeningAnswer() async {
    if (_quizCards.isEmpty || _finished) return;

    final selected = (_selectedListeningAnswer ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (selected.isEmpty) {
      _showMessage('Hãy chọn đáp án trước');
      return;
    }

    final card = _quizCards[_currentEssayIndex];
    final ok = _acceptedListeningAnswersOf(card).contains(_normalizeAnswer(selected));
    final wasLast = _currentEssayIndex + 1 >= _quizCards.length;

    setState(() {
      _answeredCards.add(card.id);
      _correctMap[card.id] = ok;
      _selectedAnswerMap[card.id] = selected;
      _finished = wasLast;
      if (!wasLast) {
        _currentEssayIndex++;
        _selectedListeningAnswer = null;
        _essayQuestionStartedAt = DateTime.now();
        _cardStartedAtMap[_quizCards[_currentEssayIndex].id] = _essayQuestionStartedAt;
      }
    });

    await _recordStudyResult(
      card: card,
      answerText: selected,
      isCorrect: ok,
    );

    if (_finished) {
      await _finishStudySession();
      _showResultSheet();
    } else {
      Future.delayed(Duration(milliseconds: 220), () {
        if (mounted && _listening) _playListeningAudio();
      });
    }
  }

  Future<void> _openSetupSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetContext) {
        int localLimit = _questionLimit.clamp(1, _cards.length).toInt();
        bool localMc = _multipleChoice;
        bool localEssay = _essay;
        bool localListening = _listening;
        bool localAnswerByDefinition = _answerByDefinition;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setMode({bool? mc, bool? essay, bool? listening}) {
              setSheetState(() {
                if (mc == true) {
                  localMc = true;
                  localEssay = false;
                  localListening = false;
                  return;
                }

                if (essay == true) {
                  localEssay = true;
                  localMc = false;
                  localListening = false;
                  return;
                }

                if (listening == true) {
                  localListening = true;
                  localMc = false;
                  localEssay = false;
                  return;
                }

                localMc = true;
                localEssay = false;
                localListening = false;
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
                                  widget.courseTitle,
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
                            icon: Icon(Icons.close_rounded, color: AppColors.border),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _setupRow(
                        label: 'Câu hỏi tối đa ${_cards.length}',
                        child: _numberStepper(
                          value: localLimit,
                          min: 1,
                          max: _cards.length,
                          onChanged: (value) => setSheetState(() => localLimit = value),
                        ),
                      ),
                      SizedBox(height: 12),
                      _setupRow(
                        label: 'Trả lời bằng',
                        child: Container(
                          height: 48,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1.3),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: localAnswerByDefinition,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded),
                              items: [
                                DropdownMenuItem(value: true, child: Text('Tiếng Việt')),
                                DropdownMenuItem(value: false, child: Text('Thuật ngữ')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() => localAnswerByDefinition = value);
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Divider(color: AppColors.border.withOpacity(0.18)),
                      _switchTile(
                        text: 'Trắc nghiệm 4 đáp án',
                        value: localMc,
                        onChanged: (v) => setMode(mc: v),
                      ),
                      _switchTile(
                        text: 'Tự luận',
                        value: localEssay,
                        onChanged: (v) => setMode(essay: v),
                      ),
                      _switchTile(
                        text: 'Nghe',
                        value: localListening,
                        onChanged: (v) => setMode(listening: v),
                      ),
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _solidButton(
                          text: 'Bắt đầu ôn tập',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.green,
                          onTap: () {
                            setState(() {
                              _questionLimit = localLimit;
                              _multipleChoice = localMc;
                              _essay = !localMc && localEssay;
                              _listening = !localMc && !localEssay && localListening;
                              if (!_multipleChoice && !_essay && !_listening) {
                                _multipleChoice = true;
                              }
                              _answerByDefinition = localAnswerByDefinition;
                            });
                            _saveReviewSettings();
                            Navigator.pop(sheetContext);
                            _startQuiz();
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

  Future<void> _showResultSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 460),
              padding: EdgeInsets.all(18),
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
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, color: AppColors.border, size: 54),
                  SizedBox(height: 10),
                  Text(
                    'Kết quả ôn tập',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _resultBox('Đúng', '$_correct', AppColors.green)),
                      SizedBox(width: 10),
                      Expanded(child: _resultBox('Sai', '$_wrong', AppColors.red)),
                      SizedBox(width: 10),
                      Expanded(child: _resultBox('Tổng', '$_total', AppColors.blue)),
                    ],
                  ),
                  SizedBox(height: 14),
                  if ((_essay || _listening) && !_multipleChoice && _wrong > 0) ...[
                    SizedBox(
                      width: double.infinity,
                      child: _solidButton(
                        text: 'Xem lại câu sai',
                        icon: Icons.fact_check_rounded,
                        color: AppColors.blue,
                        onTap: _openWrongReviewFromResult,
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _outlineButton(
                          text: 'Thoát',
                          icon: Icons.logout_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pop(this.context);
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _solidButton(
                          text: 'Ôn lại',
                          icon: Icons.refresh_rounded,
                          color: AppColors.yellow,
                          onTap: () {
                            Navigator.pop(context);
                            _restart();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
            children: [
              labelWidget,
              SizedBox(height: 8),
              child,
            ],
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

  Widget _outlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.border, size: 20),
            if (text.trim().isNotEmpty) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _reviewAnswerBox({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.45), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.border, size: 23),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBox(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.3),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.border,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: AppColors.border,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({required String text, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.border,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(StudyCardItem card, int index) {
    final answered = _answeredCards.contains(card.id);
    final selected = _selectedAnswerMap[card.id];
    final correctAnswer = _optionLabelOf(card);
    final isCorrect = _correctMap[card.id] == true;
    final choices = _choiceMap[card.id] ?? <String>[];

    return Container(
      key: _questionKeys[card.id],
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 14),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border, width: 1.1),
                ),
                child: Text(
                  '${index + 1}/$_total',
                  style: TextStyle(
                    color: AppColors.border,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 14),
          Text(
            _answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              _promptOf(card),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: _promptOf(card).length > 20 ? 27 : 36,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ),
          if (_subPromptOf(card).trim().isNotEmpty) ...[
            SizedBox(height: 6),
            Center(
              child: Text(
                _subPromptOf(card),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          Text(
            'Chọn đáp án đúng',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 520;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: choices.map((choice) {
                  final isSelected = selected == choice;
                  final isCorrectChoice = _normalizeAnswer(choice) == _normalizeAnswer(correctAnswer);
                  Color bg = Color(0xfff7f9fc);
                  if (_finished && isCorrectChoice) bg = AppColors.green;
                  if (_finished && isSelected && !isCorrectChoice) bg = AppColors.red;
                  if (!_finished && isSelected) bg = AppColors.blue.withOpacity(0.35);

                  return SizedBox(
                    width: twoCols ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth,
                    child: GestureDetector(
                      onTap: (answered || _finished) ? null : () => _answerCard(card, choice),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 160),
                        constraints: BoxConstraints(minHeight: 52),
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.25),
                          boxShadow: (answered || _finished)
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.border,
                                    offset: Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                        ),
                        child: Text(
                          choice,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: (answered || _finished) ? null : () => _skipCard(card),
              child: Text(
                _finished && answered && !isCorrect ? 'Đáp án: $correctAnswer' : 'Bạn không biết?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.border,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEssayMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 720),
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statChip(text: '$displayIndex/$_total', color: AppColors.blue),
                  Spacer(),
                ],
              ),
              SizedBox(height: 24),
              Text(
                _answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  _promptOf(card),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: _promptOf(card).length > 18 ? 34 : 46,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
              if (_subPromptOf(card).trim().isNotEmpty) ...[
                SizedBox(height: 8),
                Center(
                  child: Text(
                    _subPromptOf(card),
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              TextField(
                controller: _essayController,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: _answerByDefinition ? 'Nhập Tiếng Việt' : 'Nhập thuật ngữ',
                  filled: true,
                  fillColor: Color(0xfff7f9fc),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.border, width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.border, width: 1.8),
                  ),
                ),
                onSubmitted: (_) => _submitEssay(),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _outlineButton(
                      text: 'Trước',
                      icon: Icons.arrow_back_rounded,
                      onTap: _currentEssayIndex <= 0 ? () {} : _moveEssayPrevious,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _solidButton(
                      text: 'Sau',
                      icon: Icons.arrow_forward_rounded,
                      color: AppColors.green,
                      onTap: () => _submitEssay(allowEmptyAsSkip: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _listeningChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border, width: 1.25),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, selected ? 5 : 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildListeningMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;
    final choices = _choiceMap[card.id] ?? _buildListeningChoices(card);
    final selected = (_selectedListeningAnswer ?? '').trim();
    final selectedParts = selected.isEmpty
        ? <String>[]
        : selected.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: Offset(0, 0.18),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Center(
            key: ValueKey('listening-card-${card.id}'),
            child: Container(
            constraints: BoxConstraints(maxWidth: 560),
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.border,
                  offset: Offset(0, 7),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 16),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _statChip(text: '$displayIndex/$_total', color: AppColors.blue),
                    Spacer(),
                    Text(
                      'Nghe và chọn nghĩa đúng',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22),
                Center(
                  child: GestureDetector(
                    onTap: _playListeningAudio,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 180),
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: _isPlayingListeningAudio ? AppColors.yellow : AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1.7),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.border,
                            offset: Offset(0, 7),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlayingListeningAudio ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                        color: AppColors.border,
                        size: 52,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Ấn loa để nghe lại',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 20),
                AnimatedContainer(
                  duration: Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 62),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xfff7f9fc),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withOpacity(0.35), width: 1.25),
                  ),
                  child: selectedParts.isEmpty
                      ? Center(
                          child: Text(
                            'Chọn nhiều chip để ghép đáp án',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: selectedParts.map((part) {
                              return _listeningChip(
                                text: part,
                                selected: true,
                                onTap: () {
                                  final next = List<String>.from(selectedParts)..remove(part);
                                  setState(() {
                                    _selectedListeningAnswer = next.isEmpty ? null : next.join(' ');
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: choices.map((choice) {
                    final isSelected = selectedParts.contains(choice);
                    return AnimatedOpacity(
                      duration: Duration(milliseconds: 180),
                      opacity: isSelected ? 0.28 : 1,
                      child: IgnorePointer(
                        ignoring: isSelected,
                        child: _listeningChip(
                          text: choice,
                          selected: false,
                          onTap: () {
                            final next = [...selectedParts, choice];
                            setState(() {
                              _selectedListeningAnswer = next.join(' ');
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 22),
                _solidButton(
                  text: displayIndex >= _total ? 'Hoàn thành' : 'Kiểm tra',
                  icon: Icons.check_rounded,
                  color: AppColors.green,
                  onTap: _submitListeningAnswer,
                ),
              ],
            ),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceMode() {
    return ListView.builder(
      controller: _mcScrollController,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: _quizCards.length,
      itemBuilder: (context, index) => _buildQuestionCard(_quizCards[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.buttonInk,
          title: Text('Ôn tập'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Học phần này chưa có thẻ để ôn tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    border: Border(
                      bottom: BorderSide(color: AppColors.border.withOpacity(0.12)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SmallIcon3DButton(
                        icon: Icons.arrow_back_rounded,
                        color: Colors.white,
                        onTap: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$_done / ${_total == 0 ? _cards.length : _total}',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                            ),
                            Text(
                              widget.courseTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      SmallIcon3DButton(
                        icon: Icons.tune_rounded,
                        color: AppColors.yellow,
                        onTap: _openSetupSheet,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _showSetup || _quizCards.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(22),
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 460),
                              padding: EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.border,
                                    offset: Offset(0, 7),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_outlined, color: AppColors.border, size: 56),
                                  SizedBox(height: 12),
                                  Text(
                                    'Sẵn sàng ôn tập',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Có ${_cards.length} thẻ. Chọn kiểu câu hỏi rồi bắt đầu.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  _solidButton(
                                    text: 'Thiết lập ôn tập',
                                    icon: Icons.tune_rounded,
                                    color: AppColors.green,
                                    onTap: _openSetupSheet,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _listening
                          ? _buildListeningMode()
                          : (_essay && !_multipleChoice
                              ? _buildEssayMode()
                              : _buildMultipleChoiceMode()),
                ),
              ],
            ),
            if (!_showSetup && _quizCards.isNotEmpty && _multipleChoice)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      if (!_finished)
                        _statChip(text: 'Đã chọn $_done/$_total', color: AppColors.blue),
                      Spacer(),
                      _solidButton(
                        text: _finished ? 'Xem kết quả' : 'Nộp bài',
                        icon: Icons.flag_rounded,
                        color: AppColors.yellow,
                        onTap: _finished ? _showResultSheet : _submitMultipleChoice,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ─── Pronunciation helpers ────────────────────────────────────────────────────

String normalizeText(String s) {
  return s
      .toLowerCase()
      .replaceAll(
          RegExp(
              r"""[.,!?;:'"()\[\]{}，。！？；：''"「」『』（）【】、《》〈〉]"""),
          '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double calcSimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a == b) return 1.0;

  final la = a.split('');
  final lb = b.split('');
  final m = la.length;
  final n = lb.length;

  final dp = List.generate(m + 1, (i) => List.generate(n + 1, (j) {
        if (i == 0) return j;
        if (j == 0) return i;
        return 0;
      }));

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (la[i - 1] == lb[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] = 1 +
            [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((a, b) => a < b ? a : b);
      }
    }
  }

  final dist = dp[m][n];
  final maxLen = math.max(m, n);
  return maxLen == 0 ? 1.0 : math.max(0.0, 1.0 - dist / maxLen);
}

bool _isCJKLang(String lang) =>
    lang.startsWith('zh') || lang.startsWith('ja');

List<_WordResult> buildWordResults(String spoken, String target, String lang) {
  final spokenNorm = normalizeText(spoken);
  final targetNorm = normalizeText(target);

  if (_isCJKLang(lang)) {
    final targetChars = targetNorm.split('');
    return spokenNorm.split('').map((ch) {
      return _WordResult(text: ch, ok: targetChars.contains(ch));
    }).toList();
  } else {
    final targetWords = targetNorm.split(' ');
    return spokenNorm.split(' ').map((w) {
      final ok = targetWords.any(
          (tw) => tw == w || tw.contains(w) || w.contains(tw));
      return _WordResult(text: w, ok: ok);
    }).toList();
  }
}

class _WordResult {
  final String text;
  final bool ok;
  _WordResult({required this.text, required this.ok});
}

// ─── Pronunciation Overlay ────────────────────────────────────────────────────

class PronunciationOverlay extends StatefulWidget {
  final String targetText;
  final String subText;
  final String languageCode;

  PronunciationOverlay({
    super.key,
    required this.targetText,
    required this.subText,
    required this.languageCode,
  });

  @override
  State<PronunciationOverlay> createState() => _PronunciationOverlayState();
}

class _PronunciationOverlayState extends State<PronunciationOverlay>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isRecording = false;
  bool _hasResult = false;
  bool _listenStarted = false;

  String _statusText = 'Nhấn nút để bắt đầu';
  List<_WordResult> _wordResults = [];
  double _score = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onError: (e) {
        setState(() {
          _isRecording = false;
          _pulseController.stop();
          _pulseController.reset();
          if (e.errorMsg.contains('permission')) {
            _statusText = 'Vui lòng cho phép truy cập Microphone.';
          } else if (e.errorMsg.contains('no-speech') ||
              e.errorMsg.contains('no_match')) {
            _statusText = 'Không phát hiện giọng nói. Thử lại nhé!';
          } else {
            _statusText = 'Lỗi: ${e.errorMsg}';
          }
        });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!_listenStarted) return;
          if (mounted && _isRecording && !_hasResult) {
            setState(() {
              _isRecording = false;
              _pulseController.stop();
              _pulseController.reset();
              _statusText = 'Không nhận được giọng nói. Thử lại nhé!';
            });
          }
        }
      },
    );

    if (!_isAvailable && mounted) {
      setState(() {
        _statusText = 'Thiết bị không hỗ trợ nhận diện giọng nói.';
      });
    }
  }

  void _micReset() {
    _speech.stop();
    setState(() {
      _isRecording = false;
      _hasResult = false;
      _wordResults = [];
      _score = 0.0;
      _statusText = 'Nhấn nút để bắt đầu';
    });
    _pulseController.stop();
    _pulseController.reset();
  }

  Future<void> _micStartAgain() async {
    _micReset();

    await Future.delayed(Duration(milliseconds: 120));

    if (!mounted) return;

    await _micToggle();
  }

 Future<void> _micToggle() async {
  if (_isRecording) {
    await _speech.stop();
    setState(() {
      _isRecording = false;
      _pulseController.stop();
      _pulseController.reset();
      _statusText = 'Đã dừng. Nhấn lại để thử.';
    });
    return;
  }

  // Windows desktop thường không nhận ổn với speech_to_text
  if (Platform.isWindows) {
    setState(() {
      _statusText =
          'Windows không hỗ trợ nhận diện giọng ổn định. Hãy test trên Android/iOS hoặc Web.';
    });
    return;
  }

  bool available = false;

try {
  available = await _speech.initialize(
    onError: (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _pulseController.stop();
        _pulseController.reset();
        _statusText = 'Lỗi nhận diện: ${e.errorMsg}';
      });
    },
    onStatus: (status) {
      debugPrint('SPEECH STATUS: $status');
    },
  );
} catch (e) {
  if (!mounted) return;

  setState(() {
    _isRecording = false;
    _pulseController.stop();
    _pulseController.reset();
    _statusText =
        'Thiết bị này không có dịch vụ nhận diện giọng nói. Hãy test bằng Chrome hoặc điện thoại thật.';
  });

  debugPrint('SPEECH INIT ERROR: $e');
  return;
}

if (!available) {
  setState(() {
    _statusText =
        'Thiết bị không hỗ trợ nhận diện giọng nói. BlueStacks thường thiếu Google Speech Service.';
  });
  return;
}

  if (!available) {
    setState(() {
      _statusText = 'Thiết bị không hỗ trợ nhận diện giọng nói.';
    });
    return;
  }

  String lastWords = '';

  setState(() {
    _hasResult = false;
    _wordResults = [];
    _score = 0;
    _isRecording = true;
    _statusText = 'Đang nghe...';
  });

  _pulseController.repeat(reverse: true);

  await _speech.listen(
    localeId: widget.languageCode.isNotEmpty ? widget.languageCode : 'zh-TW',
    listenFor: Duration(seconds: 20),
    pauseFor: Duration(seconds: 3),
    partialResults: true,
    cancelOnError: false,
    listenMode: stt.ListenMode.dictation,
    onResult: (result) {
      lastWords = result.recognizedWords.trim();
      debugPrint('SPEECH WORDS: $lastWords');

      if (lastWords.isNotEmpty) {
        _micStop();
        _micShowResult(lastWords);
      }
    },
  );

  Future.delayed(Duration(seconds: 8), () {
    if (!mounted) return;
    if (_isRecording && lastWords.isEmpty) {
      _micStop();
      setState(() {
        _statusText = 'Không nhận được giọng nói. Thử lại nhé!';
      });
    }
  });
}
  void _micStop() {
    _speech.stop();
    setState(() => _isRecording = false);
    _pulseController.stop();
    _pulseController.reset();
  }

  void _micShowResult(String spoken) {
    if (spoken.isEmpty) {
      setState(() => _statusText = 'Không nhận được giọng nói. Thử lại nhé!');
      return;
    }

    final spokenNorm = normalizeText(spoken);
    final targetNorm = normalizeText(widget.targetText);
    final score = calcSimilarity(spokenNorm, targetNorm);
    final wordResults = buildWordResults(spoken, widget.targetText, widget.languageCode);

    setState(() {
      _statusText = '';
      _wordResults = wordResults;
      _score = score;
      _hasResult = true;
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_score * 100).round();
    final isHigh = pct >= 70;
    final isLow = pct < 40;
    final scoreColor = isHigh
        ? AppColors.green
        : isLow
            ? AppColors.red
            : AppColors.blue;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      child: Container(
        constraints: BoxConstraints(maxWidth: 420),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Color(0xfff6f1fb),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.border.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 18),
              blurRadius: 30,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Luyện phát âm',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.border,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (!_hasResult) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 7),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x18000000),
                        offset: Offset(0, 16),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: Text(
                          'Nhận diện phát âm',
                          style: TextStyle(
                            color: AppColors.border,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        widget.targetText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: widget.targetText.length > 8 ? 30 : 40,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                      if (widget.subText.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          widget.subText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        width: _isRecording ? 88 : 76,
                        height: _isRecording ? 88 : 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? AppColors.red : AppColors.panel2,
                          border: Border.all(color: AppColors.border, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, _isRecording ? 4 : 7),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) {
                            return Transform.scale(
                              scale: _isRecording ? _pulseAnim.value.clamp(1.0, 1.12) : 1.0,
                              child: Icon(
                                Icons.mic_rounded,
                                color: AppColors.border,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 180),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasResult && _wordResults.isNotEmpty) ...[
                SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BẠN NÓI',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 6,
                        children: _wordResults.map((w) {
                          return Text(
                            w.text,
                            style: TextStyle(
                              color: w.ok ? AppColors.text : Color(0xffc0392b),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasResult) ...[
                SizedBox(height: 14),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐỘ CHÍNH XÁC',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _score),
                          duration: Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => LinearProgressIndicator(
                            value: v,
                            minHeight: 12,
                            backgroundColor: AppColors.panel2,
                            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 18),
              Row(
                children: [
                  if (_hasResult) ...[
                    Expanded(
                      child: _MicButton(
                        label: 'Làm lại',
                        color: Colors.white,
                        onTap: _micReset,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _MicButton(
                        label: 'Bắt đầu',
                        color: AppColors.yellow,
                        onTap: _micStartAgain,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: _MicButton(
                        label: _isRecording ? 'Dừng lại' : 'Bắt đầu',
                        color: _isRecording ? AppColors.red : AppColors.yellow,
                        onTap: _micToggle,
                      ),
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  _MicButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 5),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0x18000000),
              offset: Offset(0, isPressed ? 4 : 12),
              blurRadius: isPressed ? 6 : 18,
            ),
          ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: AppColors.border,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}


class SectionTitle extends StatelessWidget {
  final String text;

  SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
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

  LightInput({
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
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.border,
              width: 1.4,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
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

  MiniInput({
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
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
          ),
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
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

  SmallIcon3DButton({
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
        duration: Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.buttonInk,
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

  BigPopupButton({
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
        duration: Duration(milliseconds: 90),
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
            SizedBox(width: 10),
            Text(
              widget.text,
              style: TextStyle(
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

  Big3DButton({
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
        duration: Duration(milliseconds: 90),
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
              color: AppColors.buttonInk.withOpacity(0.95),
              offset: Offset(0, isPressed ? 1 : 8),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0x22000000),
              offset: Offset(0, isPressed ? 5 : 18),
              blurRadius: isPressed ? 8 : 28,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.buttonInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CompactSelectItem {
  final String value;
  final String label;

  CompactSelectItem({
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

  CompactSelectBox({
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
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              final selected = item.value == value;

              return GestureDetector(
                onTap: () => onChanged(item.value),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 120),
                  padding: EdgeInsets.symmetric(
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
                        ? [
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
                    style: TextStyle(
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
            SizedBox(height: 14),
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
