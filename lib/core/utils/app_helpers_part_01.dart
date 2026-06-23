part of flutterflashcard_main;

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

  Future<void> deleteCourseAudioCache({required int courseId}) async {
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
    final hash = _safeHash(
      '${normalizeLanguageCode(languageCode)}|${text.trim()}',
    );

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

    await _speakDirect(text: value, languageCode: languageCode);
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


int _dbInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}


double _dbDouble(Object? value, double fallback) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}


class ReviewScheduler {
  ReviewScheduler._();

  static const int masteredLevel = 5;
  static const List<int> _intervalsByLevel = [1, 2, 4, 7, 15, 30, 60, 120];

  static int intervalDaysForLevel(int level) {
    if (level <= 0) return 0;
    if (level <= _intervalsByLevel.length) {
      return _intervalsByLevel[level - 1];
    }

    final extraLevel = level - _intervalsByLevel.length;
    return (_intervalsByLevel.last * math.pow(1.55, extraLevel)).round();
  }

  static Map<String, Object?> nextState({
    required int cardId,
    required Map<String, Object?>? previous,
    required bool isCorrect,
    required DateTime now,
  }) {
    final nowIso = now.toIso8601String();

    // Check if the card is not yet due (nextReviewAt is in the future).
    // If so, do NOT advance the SRS level — return previous state unchanged
    // (only update lastReviewedAt and repetitionCount).
    if (previous != null && isCorrect) {
      final nextReviewAtStr = previous['nextReviewAt']?.toString();
      if (nextReviewAtStr != null && nextReviewAtStr.isNotEmpty) {
        final nextReviewAt = DateTime.tryParse(nextReviewAtStr);
        final tomorrowStart = DateTime(now.year, now.month, now.day).add(
          Duration(days: 1),
        );
        if (nextReviewAt != null && !nextReviewAt.isBefore(tomorrowStart)) {
          // Card is not due today yet - keep existing state, only bump counts.
          return <String, Object?>{
            'cardId': cardId,
            'level': _dbInt(previous['level']),
            'easeFactor': _dbDouble(previous['easeFactor'], 2.5),
            'intervalDays': _dbInt(previous['intervalDays']),
            'repetitionCount': _dbInt(previous['repetitionCount']) + 1,
            'correctCount': _dbInt(previous['correctCount']) + 1,
            'wrongCount': _dbInt(previous['wrongCount']),
            'lastReviewedAt': nowIso,
            'nextReviewAt': nextReviewAtStr,
            'updatedAt': nowIso,
          };
        }
      }
    }

    final previousLevel = _dbInt(previous?['level']);
    final previousEase = _dbDouble(previous?['easeFactor'], 2.5);
    final int nextLevel;
    if (isCorrect) {
      nextLevel = math.min(previousLevel + 1, _intervalsByLevel.length);
    } else {
      // Wrong answers are tracked, but SRS level never goes down.
      nextLevel = previousLevel;
    }
    final nextEase = isCorrect
        ? math.min(previousEase + 0.08, 3.0)
        : math.max(previousEase - 0.2, 1.3);
    final intervalDays = nextLevel > 0 ? intervalDaysForLevel(nextLevel) : 0;
    final today = DateTime(now.year, now.month, now.day);
    final nextReviewAt = nextLevel > 0
        ? today.add(Duration(days: intervalDays))
        : now;

    final values = <String, Object?>{
      'cardId': cardId,
      'level': nextLevel,
      'easeFactor': nextEase,
      'intervalDays': intervalDays,
      'repetitionCount': _dbInt(previous?['repetitionCount']) + 1,
      'correctCount': _dbInt(previous?['correctCount']) + (isCorrect ? 1 : 0),
      'wrongCount': _dbInt(previous?['wrongCount']) + (isCorrect ? 0 : 1),
      'lastReviewedAt': nowIso,
      'nextReviewAt': nextReviewAt.toIso8601String(),
      'updatedAt': nowIso,
    };

    if (previous == null) {
      values['createdAt'] = nowIso;
    }

    return values;
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

