part of flutterflashcard_main;

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
  static const Color white = Color(0xffffffff);
  static Color get onAccentButton => activeIsDark ? white : buttonInk;
  static Color get onIconButton => activeIsDark ? white : border;
  static Color get onSolidButton => activeIsDark ? white : border;
  static Color get inputFill => activeIsDark ? panel2 : white;
  static Color get dropdownFill => activeIsDark ? panel2 : white;
  static Color get popupFill => activeIsDark ? panel : Color(0xfff6f1fb);
  static Color get overlay =>
      Colors.black.withOpacity(activeIsDark ? 0.42 : 0.25);
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
      case 'bg':
        bg = value;
        break;
      case 'panel':
        panel = value;
        break;
      case 'panel2':
        panel2 = value;
        break;
      case 'border':
        border = value;
        break;
      case 'text':
        text = value;
        break;
      case 'muted':
        muted = value;
        break;
      case 'yellow':
        yellow = value;
        break;
      case 'green':
        green = value;
        break;
      case 'red':
        red = value;
        break;
      case 'blue':
        blue = value;
        break;
    }
  }

  static int toInt(Color color) => color.value;

  static Color fromText(String? value, Color fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    final cleaned = value.replaceAll('#', '').replaceAll('0x', '').trim();
    final parsed = int.tryParse(
      cleaned.length == 6 ? 'ff$cleaned' : cleaned,
      radix: 16,
    );
    return parsed == null ? fallback : Color(parsed);
  }

  static Future<void> load({required BuildContext context}) async {
    final mode =
        await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final platformBrightness =
        MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final isDark =
        mode == 'dark' ||
        (mode == 'system' && platformBrightness == Brightness.dark);
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
    await AppSettingsStore.setString(
      'color.$key',
      toInt(color).toRadixString(16).padLeft(8, '0'),
    );
    AppThemeController.instance.bump();
  }

  static Future<void> resetColors({required BuildContext context}) async {
    final mode =
        await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final platformBrightness =
        MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final isDark =
        mode == 'dark' ||
        (mode == 'system' && platformBrightness == Brightness.dark);
    activeIsDark = isDark;
    buttonInk = Color(0xff183153);
    final base = isDark ? _darkDefaults : _lightDefaults;
    for (final key in base.keys) {
      setByKey(key, base[key]!);
      await AppSettingsStore.setString(
        'color.$key',
        toInt(base[key]!).toRadixString(16).padLeft(8, '0'),
      );
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
      'value TEXT NOT NULL, '
      'updatedAt TEXT'
      ')',
    );
    final columns = await db.rawQuery('PRAGMA table_info(app_settings)');
    if (!columns.any((row) => row['name'] == 'updatedAt')) {
      await db.execute('ALTER TABLE app_settings ADD COLUMN updatedAt TEXT');
    }
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

    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (SupabaseConfig.isLoggedIn &&
        key != GeminiFlashLiteClient.apiKeySettingKey &&
        !key.startsWith('sync.')) {
      unawaited(SupabaseSyncService.instance.syncPendingChanges());
    }
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


Widget geminiColorIcon({double size = 21}) {
  return SvgPicture.asset(
    'assets/icon/gemini-color.svg',
    width: size,
    height: size,
  );
}


class GeminiFlashLiteClient {
  GeminiFlashLiteClient._();

  static const String defaultApiKey = 'AIzaSyAy7tpyPpnGt5PTXkO_ryFes7aAuk5uHFk';
  static const String apiKeySettingKey = 'gemini.apiKey';
  static const String model = 'gemini-flash-lite-latest';

  static Future<String> _apiKey() async {
    final saved = await AppSettingsStore.getString(apiKeySettingKey);
    final key = saved?.trim().isNotEmpty == true
        ? saved!.trim()
        : defaultApiKey;
    if (key.isEmpty) {
      throw Exception('Chưa cấu hình API key Gemini.');
    }
    return key;
  }

  static Future<String> generateText(
    String prompt, {
    int maxOutputTokens = 900,
    String? responseMimeType,
  }) async {
    final apiKey = await _apiKey();
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': apiKey},
    );

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      final generationConfig = <String, Object>{
        'temperature': 0.45,
        'topP': 0.9,
        'maxOutputTokens': maxOutputTokens,
      };
      if (responseMimeType != null) {
        generationConfig['responseMimeType'] = responseMimeType;
      }

      request.write(
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': generationConfig,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = body;
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          message = data['error']?['message']?.toString() ?? body;
        } catch (_) {}
        throw Exception(message);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      final parts = candidates?.isNotEmpty == true
          ? (candidates!.first['content']?['parts'] as List<dynamic>?)
          : null;
      final generated =
          parts?.map((e) => e['text']?.toString() ?? '').join('\n').trim() ??
          '';
      if (generated.isEmpty) throw Exception('Gemini không trả về nội dung.');
      return generated;
    } finally {
      client.close(force: true);
    }
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
