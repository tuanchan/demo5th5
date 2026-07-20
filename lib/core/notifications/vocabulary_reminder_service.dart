import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';

const String vocabularyReminderKnownAction = 'vocabulary_reminder_known';
const String vocabularyReminderUnknownAction = 'vocabulary_reminder_unknown';
const String vocabularyReminderCategory = 'vocabulary_reminder_actions';

@pragma('vm:entry-point')
void vocabularyReminderNotificationTapBackground(
  NotificationResponse response,
) {
  DartPluginRegistrant.ensureInitialized();
  VocabularyReminderService.instance.handleNotificationResponse(response);
}

class VocabularyReminderConfig {
  const VocabularyReminderConfig({
    required this.courseId,
    this.enabled = false,
    this.intervalMinutes = 0.5,
    this.notificationsPerDay = 8,
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    this.includePronunciation = true,
    this.includeDefinition = true,
    this.skipSrsMastered = true,
    this.randomOrder = true,
    this.soundEnabled = true,
    this.showInForeground = false,
  });

  final int courseId;
  final bool enabled;
  final double intervalMinutes;
  final int notificationsPerDay;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool includePronunciation;
  final bool includeDefinition;
  final bool skipSrsMastered;
  final bool randomOrder;
  final bool soundEnabled;
  final bool showInForeground;

  factory VocabularyReminderConfig.fromMap(Map<String, Object?> row) {
    bool flag(String key, bool fallback) {
      final value = row[key];
      if (value == null) return fallback;
      return (value as num).toInt() == 1;
    }

    int number(String key, int fallback) =>
        (row[key] as num?)?.toInt() ?? fallback;
    double decimal(String key, double fallback) =>
        (row[key] as num?)?.toDouble() ?? fallback;
    final storedEndHour = number('endHour', 22);

    return VocabularyReminderConfig(
      courseId: number('courseId', 0),
      enabled: flag('enabled', false),
      intervalMinutes: decimal('intervalMinutes', 0.5),
      notificationsPerDay: number('notificationsPerDay', 8),
      startHour: number('startHour', 8),
      startMinute: number('startMinute', 0),
      endHour: storedEndHour >= 24 ? 23 : storedEndHour,
      endMinute: storedEndHour >= 24 ? 59 : number('endMinute', 0),
      includePronunciation: flag('includePronunciation', true),
      includeDefinition: flag('includeDefinition', true),
      skipSrsMastered: flag('skipSrsMastered', true),
      randomOrder: flag('randomOrder', true),
      soundEnabled: flag('soundEnabled', true),
      showInForeground: flag('showInForeground', false),
    );
  }

  VocabularyReminderConfig copyWith({
    bool? enabled,
    double? intervalMinutes,
    int? notificationsPerDay,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    bool? includePronunciation,
    bool? includeDefinition,
    bool? skipSrsMastered,
    bool? randomOrder,
    bool? soundEnabled,
    bool? showInForeground,
  }) {
    return VocabularyReminderConfig(
      courseId: courseId,
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      notificationsPerDay: notificationsPerDay ?? this.notificationsPerDay,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      includePronunciation:
          includePronunciation ?? this.includePronunciation,
      includeDefinition: includeDefinition ?? this.includeDefinition,
      skipSrsMastered: skipSrsMastered ?? this.skipSrsMastered,
      randomOrder: randomOrder ?? this.randomOrder,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      showInForeground: showInForeground ?? this.showInForeground,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'courseId': courseId,
        'enabled': enabled ? 1 : 0,
        'intervalMinutes': intervalMinutes.clamp(0.1, 1440).toDouble(),
        'notificationsPerDay': notificationsPerDay.clamp(1, 100000).toInt(),
        'startHour': startHour.clamp(0, 23).toInt(),
        'startMinute': startMinute.clamp(0, 59).toInt(),
        'endHour': endHour.clamp(0, 23).toInt(),
        'endMinute': endMinute.clamp(0, 59).toInt(),
        'includePronunciation': includePronunciation ? 1 : 0,
        'includeDefinition': includeDefinition ? 1 : 0,
        'skipSrsMastered': skipSrsMastered ? 1 : 0,
        'randomOrder': randomOrder ? 1 : 0,
        'soundEnabled': soundEnabled ? 1 : 0,
        'showInForeground': showInForeground ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      };
}

class VocabularyReminderStatus {
  const VocabularyReminderStatus({
    required this.totalCards,
    required this.learnedCards,
    required this.eligibleCards,
    required this.scheduledNotifications,
  });

  final int totalCards;
  final int learnedCards;
  final int eligibleCards;
  final int scheduledNotifications;
}

class VocabularyReminderService {
  VocabularyReminderService._();

  static final VocabularyReminderService instance =
      VocabularyReminderService._();

  static const int _rollingQueueSize = 60;
  static const int _masteredSrsLevel = 5;
  static const String _channelId = 'vocabulary_reminders';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _initializing = false;

  Future<void> initialize() async {
    if (_initialized || _initializing || kIsWeb) return;
    _initializing = true;
    try {
      tz_data.initializeTimeZones();
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      final category = DarwinNotificationCategory(
        vocabularyReminderCategory,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            vocabularyReminderKnownAction,
            'Đã thuộc',
          ),
          DarwinNotificationAction.plain(
            vocabularyReminderUnknownAction,
            'Chưa thuộc',
          ),
        ],
      );
      final darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[category],
      );
      final settings = InitializationSettings(
        android: const AndroidInitializationSettings('notification_icon'),
        iOS: darwin,
        macOS: darwin,
        linux: const LinuxInitializationSettings(
          defaultActionName: 'Mở Flash Cat',
        ),
        windows: WindowsInitializationSettings(
          appName: 'Flash Cat',
          appUserModelId: 'FlutterFlashCard.FlashCat',
          guid: 'f3d41d46-2cb7-4d89-9e48-b0ae376f3439',
        ),
      );
      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            vocabularyReminderNotificationTapBackground,
      );
      await AppDatabase.instance.ensureVocabularyReminderSchema();
      _initialized = true;
      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        await handleNotificationResponse(launchResponse);
      }
    } finally {
      _initializing = false;
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    return Platform.isWindows;
  }

  Future<VocabularyReminderConfig> loadConfig(int courseId) async {
    await AppDatabase.instance.ensureVocabularyReminderSchema();
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'vocabulary_reminder_configs',
      where: 'courseId = ?',
      whereArgs: <Object?>[courseId],
      limit: 1,
    );
    return rows.isEmpty
        ? VocabularyReminderConfig(courseId: courseId)
        : VocabularyReminderConfig.fromMap(rows.first);
  }

  Future<void> saveConfig(VocabularyReminderConfig config) async {
    await initialize();
    final db = await AppDatabase.instance.database;
    await db.insert(
      'vocabulary_reminder_configs',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (config.enabled) {
      // iOS has one global limit of 64 pending notifications per app. Keep a
      // single selected course active so one course cannot evict another
      // course's queue unpredictably.
      await db.update(
        'vocabulary_reminder_configs',
        <String, Object?>{
          'enabled': 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'courseId <> ?',
        whereArgs: <Object?>[config.courseId],
      );
      await _cancelEveryScheduledReminder();
      await rescheduleCourse(config.courseId);
    } else {
      await cancelCourse(config.courseId);
    }
  }

  Future<void> refreshEnabledSchedule() async {
    if (kIsWeb) return;
    await AppDatabase.instance.ensureVocabularyReminderSchema();
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'vocabulary_reminder_configs',
      columns: const <String>['courseId'],
      where: 'enabled = 1',
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    final courseId = (rows.first['courseId'] as num?)?.toInt();
    if (courseId != null) await rescheduleCourse(courseId);
  }

  Future<void> _cancelEveryScheduledReminder() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'vocabulary_reminder_schedule',
      columns: const <String>['notificationId'],
    );
    for (final row in rows) {
      final id = (row['notificationId'] as num?)?.toInt();
      if (id != null) await _notifications.cancel(id: id);
    }
    await db.delete('vocabulary_reminder_schedule');
  }

  Future<VocabularyReminderStatus> loadStatus(int courseId) async {
    await AppDatabase.instance.ensureVocabularyReminderSchema();
    final config = await loadConfig(courseId);
    final db = await AppDatabase.instance.database;
    final totals = await db.rawQuery(
      '''
      SELECT
        COUNT(ca.id) AS totalCards,
        COALESCE(SUM(CASE WHEN COALESCE(vrs.learned, 0) = 1 THEN 1 ELSE 0 END), 0)
          AS learnedCards,
        COALESCE(SUM(CASE
          WHEN COALESCE(vrs.learned, 0) = 0
            AND (? = 0 OR COALESCE(rs.level, 0) < ?)
          THEN 1 ELSE 0 END), 0) AS eligibleCards
      FROM cards ca
      LEFT JOIN vocabulary_reminder_states vrs ON vrs.cardId = ca.id
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.courseId = ?
        AND ca.deletedAt IS NULL
        AND ca.isHidden = 0
      ''',
      <Object?>[
        config.skipSrsMastered ? 1 : 0,
        _masteredSrsLevel,
        courseId,
      ],
    );
    final scheduleRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM vocabulary_reminder_schedule '
      'WHERE courseId = ? AND scheduledAt > ?',
      <Object?>[courseId, DateTime.now().toIso8601String()],
    );
    int value(Object? source) => (source as num?)?.toInt() ?? 0;
    final row = totals.first;
    return VocabularyReminderStatus(
      totalCards: value(row['totalCards']),
      learnedCards: value(row['learnedCards']),
      eligibleCards: value(row['eligibleCards']),
      scheduledNotifications: value(scheduleRows.first['count']),
    );
  }

  Future<void> cancelCourse(int courseId) async {
    await initialize();
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'vocabulary_reminder_schedule',
      columns: const <String>['notificationId'],
      where: 'courseId = ?',
      whereArgs: <Object?>[courseId],
    );
    for (final row in rows) {
      final id = (row['notificationId'] as num?)?.toInt();
      if (id != null) await _notifications.cancel(id: id);
    }
    await db.delete(
      'vocabulary_reminder_schedule',
      where: 'courseId = ?',
      whereArgs: <Object?>[courseId],
    );
  }

  Future<int> rescheduleCourse(int courseId) async {
    await initialize();
    final config = await loadConfig(courseId);
    await cancelCourse(courseId);
    if (!config.enabled) return 0;

    final db = await AppDatabase.instance.database;
    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM cards '
      'WHERE courseId = ? AND deletedAt IS NULL AND isHidden = 0',
      <Object?>[courseId],
    );
    final courseVocabularyCount =
        (totalRows.first['count'] as num?)?.toInt() ?? 0;
    final cards = await db.rawQuery(
      '''
      SELECT ca.id, ca.term, ca.definition, COALESCE(ca.pronunciation, '') AS pronunciation
      FROM cards ca
      LEFT JOIN vocabulary_reminder_states vrs ON vrs.cardId = ca.id
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.courseId = ?
        AND ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND COALESCE(vrs.learned, 0) = 0
        AND (? = 0 OR COALESCE(rs.level, 0) < ?)
      ORDER BY ca.position ASC, ca.id ASC
      ''',
      <Object?>[
        courseId,
        config.skipSrsMastered ? 1 : 0,
        _masteredSrsLevel,
      ],
    );
    if (cards.isEmpty) return 0;

    final queue = cards.map(Map<String, Object?>.from).toList();
    if (config.randomOrder) queue.shuffle(Random());
    final effectiveConfig = config.copyWith(
      notificationsPerDay: max(1, courseVocabularyCount),
    );
    final slots = _buildScheduleSlots(effectiveConfig, _rollingQueueSize);
    final usedIds = <int>{};
    final batch = db.batch();
    for (var index = 0; index < slots.length; index++) {
      if (config.randomOrder && index > 0 && index % queue.length == 0) {
        final previousCardId =
            (queue[(index - 1) % queue.length]['id'] as num).toInt();
        queue.shuffle(Random());
        if (queue.length > 1 &&
            (queue.first['id'] as num).toInt() == previousCardId) {
          final first = queue.first;
          queue[0] = queue[1];
          queue[1] = first;
        }
      }
      final card = queue[index % queue.length];
      final cardId = (card['id'] as num).toInt();
      final scheduledAt = slots[index];
      var notificationId = _notificationId(courseId, cardId, scheduledAt);
      while (!usedIds.add(notificationId)) {
        notificationId = (notificationId + 1) & 0x7fffffff;
      }
      await _notifications.zonedSchedule(
        id: notificationId,
        title: card['term']?.toString() ?? 'Từ vựng',
        body: _notificationBody(card, config),
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: _notificationDetails(
          config,
          courseId: courseId,
          cardId: cardId,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode(<String, Object?>{
          'type': 'vocabularyReminder',
          'courseId': courseId,
          'cardId': cardId,
        }),
      );
      batch.insert('vocabulary_reminder_schedule', <String, Object?>{
        'notificationId': notificationId,
        'courseId': courseId,
        'cardId': cardId,
        'scheduledAt': scheduledAt.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
    return slots.length;
  }

  Future<void> showTestNotification(int courseId) async {
    await initialize();
    final config = await loadConfig(courseId);
    final db = await AppDatabase.instance.database;
    final cards = await db.query(
      'cards',
      columns: const <String>['id', 'term', 'definition', 'pronunciation'],
      where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
      whereArgs: <Object?>[courseId],
      limit: 30,
    );
    if (cards.isEmpty) throw StateError('Học phần chưa có từ vựng');
    final card = cards[Random().nextInt(cards.length)];
    await _notifications.show(
      id: _notificationId(courseId, (card['id'] as num).toInt(), DateTime.now()),
      title: card['term']?.toString() ?? 'Từ vựng',
      body: _notificationBody(card, config),
      notificationDetails: _notificationDetails(
        config,
        preview: true,
        courseId: courseId,
        cardId: (card['id'] as num).toInt(),
      ),
      payload: jsonEncode(<String, Object?>{
        'type': 'vocabularyReminder',
        'courseId': courseId,
        'cardId': (card['id'] as num).toInt(),
      }),
    );
  }

  Future<void> resetLearnedCards(int courseId) async {
    await AppDatabase.instance.ensureVocabularyReminderSchema();
    final db = await AppDatabase.instance.database;
    await db.delete(
      'vocabulary_reminder_states',
      where: 'courseId = ?',
      whereArgs: <Object?>[courseId],
    );
    await rescheduleCourse(courseId);
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    var actionId = response.actionId;
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map || decoded['type'] != 'vocabularyReminder') return;
      // Windows returns the button's `arguments` as both actionId and payload,
      // so its action identifier is embedded in the JSON arguments.
      actionId = decoded['actionId']?.toString() ?? actionId;
      if (actionId != vocabularyReminderKnownAction &&
          actionId != vocabularyReminderUnknownAction) {
        return;
      }
      final courseId = (decoded['courseId'] as num?)?.toInt();
      final cardId = (decoded['cardId'] as num?)?.toInt();
      if (courseId == null || cardId == null) return;
      await initialize();
      final db = await AppDatabase.instance.database;
      final known = actionId == vocabularyReminderKnownAction;
      final now = DateTime.now().toIso8601String();
      await db.insert(
        'vocabulary_reminder_states',
        <String, Object?>{
          'cardId': cardId,
          'courseId': courseId,
          'learned': known ? 1 : 0,
          // An answer starts a fresh reminder cycle. Unknown cards remain in
          // the pool; known cards are permanently excluded until reset.
          'timesShown': 0,
          'lastResponse': known ? 'known' : 'unknown',
          'lastNotifiedAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await rescheduleCourse(courseId);
    } catch (error) {
      debugPrint('VOCABULARY REMINDER ACTION ERROR: $error');
    }
  }

  List<DateTime> _buildScheduleSlots(
    VocabularyReminderConfig config,
    int maximum,
  ) {
    final result = <DateTime>[];
    final startHour = config.startHour.clamp(0, 23).toInt();
    final startMinute = config.startMinute.clamp(0, 59).toInt();
    final endHour = config.endHour.clamp(0, 23).toInt();
    final endMinute = config.endMinute.clamp(0, 59).toInt();
    final interval = Duration(
      milliseconds: (config.intervalMinutes.clamp(0.1, 1440) *
              Duration.millisecondsPerMinute)
          .round(),
    );
    var cursor = DateTime.now().add(interval);
    var dayKey = '';
    var countForDay = 0;
    while (result.length < maximum) {
      final currentDayKey = '${cursor.year}-${cursor.month}-${cursor.day}';
      if (currentDayKey != dayKey) {
        dayKey = currentDayKey;
        countForDay = 0;
      }
      final start = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        startHour,
        startMinute,
      );
      final end = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        endHour,
        endMinute,
      );
      if (cursor.isBefore(start)) cursor = start;
      if (!cursor.isBefore(end) ||
          countForDay >= config.notificationsPerDay.clamp(1, 100000)) {
        cursor = DateTime(
          cursor.year,
          cursor.month,
          cursor.day + 1,
          startHour,
          startMinute,
        );
        continue;
      }
      result.add(cursor);
      countForDay++;
      cursor = cursor.add(interval);
    }
    return result;
  }

  int _notificationId(int courseId, int cardId, DateTime time) {
    final minute = time.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    return (courseId * 1000003 + cardId * 97 + minute) & 0x7fffffff;
  }

  String _notificationBody(
    Map<String, Object?> card,
    VocabularyReminderConfig config,
  ) {
    final lines = <String>[];
    final pronunciation = card['pronunciation']?.toString().trim() ?? '';
    final definition = card['definition']?.toString().trim() ?? '';
    if (config.includePronunciation && pronunciation.isNotEmpty) {
      lines.add('/$pronunciation/');
    }
    if (config.includeDefinition && definition.isNotEmpty) {
      lines.add(definition);
    }
    return lines.isEmpty ? 'Bạn đã thuộc từ này chưa?' : lines.join('\n');
  }

  NotificationDetails _notificationDetails(
    VocabularyReminderConfig config, {
    bool preview = false,
    required int courseId,
    required int cardId,
  }) {
    final presentInForeground = preview || config.showInForeground;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Nhắc từ vựng',
        channelDescription: 'Thông báo ôn từ ngẫu nhiên theo học phần',
        importance: Importance.high,
        priority: Priority.high,
        playSound: config.soundEnabled,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            vocabularyReminderKnownAction,
            'Đã thuộc',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            vocabularyReminderUnknownAction,
            'Chưa thuộc',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: vocabularyReminderCategory,
        threadIdentifier: 'vocabulary-reminder-${config.courseId}',
        presentAlert: presentInForeground,
        presentBanner: presentInForeground,
        presentList: presentInForeground,
        presentSound: config.soundEnabled,
      ),
      macOS: DarwinNotificationDetails(
        categoryIdentifier: vocabularyReminderCategory,
        threadIdentifier: 'vocabulary-reminder-${config.courseId}',
        presentAlert: presentInForeground,
        presentSound: config.soundEnabled,
      ),
      windows: WindowsNotificationDetails(
        actions: <WindowsAction>[
          WindowsAction(
            content: 'Đã thuộc',
            arguments: _windowsActionPayload(
              vocabularyReminderKnownAction,
              courseId,
              cardId,
            ),
            buttonStyle: WindowsButtonStyle.success,
          ),
          WindowsAction(
            content: 'Chưa thuộc',
            arguments: _windowsActionPayload(
              vocabularyReminderUnknownAction,
              courseId,
              cardId,
            ),
          ),
        ],
      ),
    );
  }

  String _windowsActionPayload(String actionId, int courseId, int cardId) {
    return jsonEncode(<String, Object?>{
      'type': 'vocabularyReminder',
      'actionId': actionId,
      'courseId': courseId,
      'cardId': cardId,
    });
  }
}
