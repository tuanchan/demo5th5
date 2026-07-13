import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'supabase_config.dart';

/// Service to synchronize local SQLite data with Supabase when user logs in.
/// Uses a "last-write-wins" merge strategy based on updatedAt timestamps.
class SupabaseSyncService {
  SupabaseSyncService._();

  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool _isSyncing = false;
  String? _lastSyncError;
  Future<SyncResult>? _activeSync;
  final StreamController<SyncResult> _syncCompletedController =
      StreamController<SyncResult>.broadcast();
  final Map<String, String> _topicRemoteIdByLocal = {};
  final Map<String, String> _courseRemoteIdByLocal = {};
  final Map<String, String> _cardRemoteIdByLocal = {};
  final Map<String, int> _topicLocalIdByRemote = {};
  final Map<String, int> _courseLocalIdByRemote = {};
  final Map<String, int> _cardLocalIdByRemote = {};
  String _localDeviceId = '';

  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  Future<SyncResult>? get activeSync => _activeSync;
  Stream<SyncResult> get syncCompleted => _syncCompletedController.stream;

  /// Full bidirectional sync: push local → Supabase, then pull Supabase → local.
  Future<SyncResult> syncAll() {
    final active = _activeSync;
    if (active != null) return active;
    if (!SupabaseConfig.isLoggedIn) {
      return Future.value(
        SyncResult(pushed: 0, pulled: 0, error: 'Chưa đăng nhập'),
      );
    }

    final future = _syncAllOnce();
    _activeSync = future;
    future.then(_syncCompletedController.add);
    return future;
  }

  /// Wait for an in-flight sync, then start a fresh pass that includes local
  /// mutations made while that earlier pass was running.
  Future<SyncResult> syncPendingChanges() async {
    final active = _activeSync;
    if (active != null) await active;
    return syncAll();
  }

  Future<SyncResult> _syncAllOnce() async {

    _isSyncing = true;
    _lastSyncError = null;

    try {
      final ownerId = SupabaseConfig.currentUser!.id;
      final db = await AppDatabase.instance.database;
      final client = SupabaseConfig.client;

      // Apply topic repairs before IDs and foreign keys are mapped for sync.
      await AppDatabase.instance.ensureTopicSchema();

      int pushed = 0;
      int pulled = 0;
      final syncErrors = <String>[];

      await _ensureLocalDeviceId(db);
      await _prepareLocalOwner(db, ownerId);
      await _cleanupCrossAccountTombstones(db, client, ownerId);
      await _removeBundledVocabulary(db, client, ownerId);
      await _prepareIdentityMaps(db, client, ownerId);

      void collectError(String table, SyncResult result) {
        if (result.hasError) syncErrors.add('$table: ${result.error}');
      }

      // 1. Sync topics
      final topicResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'topics',
        remoteTable: 'topics',
        idColumn: 'id',
        localToRemote: _topicLocalToRemote,
        remoteToLocal: _topicRemoteToLocal,
      );
      pushed += topicResult.pushed;
      pulled += topicResult.pulled;
      collectError('topics', topicResult);

      // 2. Sync courses
      final courseResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'courses',
        remoteTable: 'courses',
        idColumn: 'id',
        localToRemote: _courseLocalToRemote,
        remoteToLocal: _courseRemoteToLocal,
      );
      pushed += courseResult.pushed;
      pulled += courseResult.pulled;
      collectError('courses', courseResult);

      // 3. Sync cards
      final cardResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'cards',
        remoteTable: 'cards',
        idColumn: 'id',
        localToRemote: _cardLocalToRemote,
        remoteToLocal: _cardRemoteToLocal,
      );
      pushed += cardResult.pushed;
      pulled += cardResult.pulled;
      collectError('cards', cardResult);

      // 4. Sync card_examples
      final exampleResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'card_examples',
        remoteTable: 'card_examples',
        idColumn: 'id',
        localToRemote: _cardExampleLocalToRemote,
        remoteToLocal: _cardExampleRemoteToLocal,
      );
      pushed += exampleResult.pushed;
      pulled += exampleResult.pulled;
      collectError('card_examples', exampleResult);

      // 5. Sync review_states
      final reviewResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'review_states',
        remoteTable: 'review_states',
        idColumn: 'id',
        remoteConflictColumns: 'owner_id,card_id',
        localToRemote: _reviewStateLocalToRemote,
        remoteToLocal: _reviewStateRemoteToLocal,
      );
      pushed += reviewResult.pushed;
      pulled += reviewResult.pulled;
      collectError('review_states', reviewResult);

      // 6. Sync study_sessions
      final sessionResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'study_sessions',
        remoteTable: 'study_sessions',
        idColumn: 'id',
        localToRemote: _studySessionLocalToRemote,
        remoteToLocal: _studySessionRemoteToLocal,
      );
      pushed += sessionResult.pushed;
      pulled += sessionResult.pulled;
      collectError('study_sessions', sessionResult);

      // 7. Sync study_results
      final studyResultResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'study_results',
        remoteTable: 'study_results',
        idColumn: 'id',
        localToRemote: _studyResultLocalToRemote,
        remoteToLocal: _studyResultRemoteToLocal,
      );
      pushed += studyResultResult.pushed;
      pulled += studyResultResult.pulled;
      collectError('study_results', studyResultResult);

      // 8. Sync review_sentence_questions
      final questionResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'review_sentence_questions',
        remoteTable: 'review_sentence_questions',
        idColumn: 'id',
        remoteConflictColumns:
            'owner_id,course_id,card_id,language_code,direction',
        localToRemote: _questionLocalToRemote,
        remoteToLocal: _questionRemoteToLocal,
      );
      pushed += questionResult.pushed;
      pulled += questionResult.pulled;
      collectError('review_sentence_questions', questionResult);

      // import_exports is local operation history, not user learning data.
      // Syncing it also duplicated bundled asset metadata on every device.
      await _removeRemoteBundledImportMetadata(client, ownerId);

      // 10. Sync app_settings
      final appSettingsResult = await _syncTable(
        db: db,
        client: client,
        ownerId: ownerId,
        localTable: 'app_settings',
        remoteTable: 'app_settings',
        idColumn: 'key',
        remoteConflictColumns: 'owner_id,key',
        localToRemote: _appSettingLocalToRemote,
        remoteToLocal: _appSettingRemoteToLocal,
      );
      pushed += appSettingsResult.pushed;
      pulled += appSettingsResult.pulled;
      collectError('app_settings', appSettingsResult);

      // Save last sync timestamp
      final now = DateTime.now().toIso8601String();
      await _setLocalSetting(db, 'sync.lastSyncAt', now);

      return SyncResult(
        pushed: pushed,
        pulled: pulled,
        pulledCourses: courseResult.pulled,
        pulledCards: cardResult.pulled,
        error: syncErrors.isEmpty ? null : syncErrors.join(' | '),
      );
    } catch (e) {
      _lastSyncError = e.toString();
      return SyncResult(pushed: 0, pulled: 0, error: e.toString());
    } finally {
      _isSyncing = false;
      _activeSync = null;
    }
  }

  /// Generic table sync. Pushes all local rows to remote, then pulls any
  /// remote rows not present locally or newer than local.
  Future<SyncResult> _syncTable({
    required Database db,
    required SupabaseClient client,
    required String ownerId,
    required String localTable,
    required String remoteTable,
    required String idColumn,
    String? remoteConflictColumns,
    required Map<String, dynamic> Function(
      Map<String, Object?> localRow,
      String ownerId,
    ) localToRemote,
    required Map<String, Object?> Function(
      Map<String, dynamic> remoteRow,
    ) remoteToLocal,
  }) async {
    int pushed = 0;
    int pulled = 0;
    final errors = <String>[];

    try {
      var remoteRows = await _fetchAllRemoteRows(
        client: client,
        table: remoteTable,
        ownerId: ownerId,
      );
      final remoteById = <String, Map<String, dynamic>>{
        for (final row in remoteRows)
          if (row[idColumn] != null) row[idColumn].toString(): row,
      };

      // --- PUSH local → Supabase ---
      final queriedLocalRows = await db.query(localTable);
      final localRows = localTable == 'app_settings'
          ? queriedLocalRows
              .where((row) => !_isLocalOnlySetting(row['key']))
              .toList(growable: false)
          : queriedLocalRows;
      for (final row in localRows) {
        try {
          final remoteData = localToRemote(row, ownerId);
          final remoteId = remoteData[idColumn]?.toString();
          final existingRemote = remoteId == null ? null : remoteById[remoteId];
          if (existingRemote != null &&
              !_localRowIsNewer(remoteData, existingRemote)) {
            continue;
          }
          await client.from(remoteTable).upsert(
            remoteData,
            onConflict: remoteConflictColumns ?? idColumn,
          );
          pushed++;
        } catch (e) {
          // Skip individual row errors
          errors.add('push row ${row[idColumn]}: $e');
          print('SYNC PUSH ERROR ($localTable row ${row[idColumn]}): $e');
        }
      }

      // --- PULL Supabase → local ---
      remoteRows = await _fetchAllRemoteRows(
        client: client,
        table: remoteTable,
        ownerId: ownerId,
      );

      for (final remote in remoteRows) {
        if (localTable == 'app_settings' &&
            _isLocalOnlySetting(remote['key'])) {
          continue;
        }
        try {
          final localData = remoteToLocal(remote);
          final localId = localData[idColumn];

          final existing = await db.query(
            localTable,
            where: '$idColumn = ?',
            whereArgs: [localId],
            limit: 1,
          );

          if (existing.isEmpty) {
            // A tombstone only matters when this device still has the row it
            // deletes. Do not import historical deleted rows as new local
            // data on every login.
            if (remote.containsKey('deleted_at') &&
                remote['deleted_at'] != null) {
              continue;
            }
            await db.insert(
              localTable,
              localData,
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
            pulled++;
          } else {
            // Compare updatedAt: remote wins if newer
            final localUpdated = existing.first['updatedAt']?.toString() ?? '';
            final remoteUpdated = remote['updated_at']?.toString() ?? '';
            if (_isRemoteNewer(remoteUpdated, localUpdated)) {
              await db.update(
                localTable,
                localData,
                where: '$idColumn = ?',
                whereArgs: [localId],
              );
              pulled++;
            }
          }
        } catch (e) {
          errors.add('pull row ${remote['id'] ?? remote['key']}: $e');
          print('SYNC PULL ERROR ($localTable): $e');
        }
      }
    } catch (e) {
      errors.add('table: $e');
      print('SYNC TABLE ERROR ($localTable): $e');
    }

    final error = errors.isEmpty
        ? null
        : '${errors.length} lỗi; ${errors.take(3).join(' || ')}';
    print(
      'SYNC TABLE RESULT ($localTable): pushed=$pushed, '
      'pulled=$pulled, errors=${errors.length}',
    );
    return SyncResult(pushed: pushed, pulled: pulled, error: error);
  }

  // ========== Mappers: local (camelCase) ↔ remote (snake_case) ==========

  Map<String, dynamic> _topicLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    final localTopicId = _localInt(row['id']);
    final remoteTopicId = _remoteIdFor(
      _topicRemoteIdByLocal,
      localTopicId,
      'topic',
    );
    if (localTopicId != null) {
      _topicLocalIdByRemote.putIfAbsent(
        remoteTopicId,
        () => localTopicId,
      );
    }
    return {
      'id': remoteTopicId,
      'owner_id': ownerId,
      'name': row['name'],
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
      'deleted_at': row['deletedAt'],
    };
  }

  Map<String, Object?> _topicRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _topicLocalIdByRemote[row['id']?.toString()] ??
          _stableLocalId(row['id']),
      'name': row['name'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'deletedAt': row['deleted_at'],
    };
  }

  Map<String, dynamic> _courseLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    final localCourseId = _localInt(row['id']);
    final remoteCourseId = _remoteIdFor(
      _courseRemoteIdByLocal,
      localCourseId,
      'course',
    );
    if (localCourseId != null) {
      _courseLocalIdByRemote.putIfAbsent(
        remoteCourseId,
        () => localCourseId,
      );
    }
    return {
      'id': remoteCourseId,
      'owner_id': ownerId,
      'topic_id': row['topicId'] != null
          ? _remoteIdFor(_topicRemoteIdByLocal, row['topicId'], 'topic')
          : null,
      'title': row['title'],
      'description': row['description'],
      'language_id': row['languageId'],
      'language_name': row['languageName'],
      'language_code': row['languageCode'],
      'card_count': row['cardCount'] ?? 0,
      'is_favorite': (row['isFavorite'] == 1),
      'is_archived': (row['isArchived'] == 1),
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
      'deleted_at': row['deletedAt'],
    };
  }

  Map<String, Object?> _courseRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _courseLocalIdByRemote[row['id']?.toString()] ??
          _stableLocalId(row['id']),
      'topicId': row['topic_id'] != null
          ? (_topicLocalIdByRemote[row['topic_id'].toString()] ??
                _stableLocalId(row['topic_id']))
          : null,
      'title': row['title'],
      'description': row['description'],
      'languageId': row['language_id'],
      'languageName': row['language_name'],
      'languageCode': row['language_code'],
      'cardCount': row['card_count'] ?? 0,
      'isFavorite': row['is_favorite'] == true ? 1 : 0,
      'isArchived': row['is_archived'] == true ? 1 : 0,
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'deletedAt': row['deleted_at'],
    };
  }

  Map<String, dynamic> _cardLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    final localCourseId = row['courseId'];
    final remoteCourseId = _remoteIdFor(
      _courseRemoteIdByLocal,
      localCourseId,
      'course',
    );
    final localCardId = _localInt(row['id']);
    final remoteCardId = _remoteIdFor(
      _cardRemoteIdByLocal,
      localCardId,
      'card',
    );
    if (localCardId != null) {
      _cardLocalIdByRemote.putIfAbsent(remoteCardId, () => localCardId);
    }
    return {
      'id': remoteCardId,
      'owner_id': ownerId,
      'course_id': remoteCourseId,
      'term': row['term'],
      'definition': row['definition'],
      'pronunciation': row['pronunciation'],
      'raw_text': row['rawText'],
      'input_format': row['inputFormat'],
      'extra_meaning': row['extraMeaning'],
      'note': row['note'],
      'image_path': row['imagePath'],
      'audio_path': row['audioPath'],
      'position': row['position'] ?? 0,
      'is_favorite': (row['isFavorite'] == 1),
      'is_hidden': (row['isHidden'] == 1),
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
      'deleted_at': row['deletedAt'],
    };
  }

  Map<String, Object?> _cardRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _cardLocalIdByRemote[row['id']?.toString()] ??
          _stableLocalId(row['id']),
      'courseId': _courseLocalIdByRemote[row['course_id']?.toString()] ??
          _stableLocalId(row['course_id']),
      'term': row['term'],
      'definition': row['definition'],
      'pronunciation': row['pronunciation'],
      'rawText': row['raw_text'],
      'inputFormat': row['input_format'],
      'extraMeaning': row['extra_meaning'],
      'note': row['note'],
      'imagePath': row['image_path'],
      'audioPath': row['audio_path'],
      'position': row['position'] ?? 0,
      'isFavorite': row['is_favorite'] == true ? 1 : 0,
      'isHidden': row['is_hidden'] == true ? 1 : 0,
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'deletedAt': row['deleted_at'],
    };
  }

  Map<String, dynamic> _cardExampleLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'id': _uuidFromLocalId(row['id'], 'card_example'),
      'owner_id': ownerId,
      'card_id': _remoteIdFor(_cardRemoteIdByLocal, row['cardId'], 'card'),
      'example_text': row['exampleText'],
      'pronunciation': row['pronunciation'],
      'meaning': row['meaning'],
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
    };
  }

  Map<String, Object?> _cardExampleRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _stableLocalId(row['id']),
      'cardId': _cardLocalIdByRemote[row['card_id']?.toString()] ??
          _stableLocalId(row['card_id']),
      'exampleText': row['example_text'],
      'pronunciation': row['pronunciation'],
      'meaning': row['meaning'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  Map<String, dynamic> _reviewStateLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'id': _uuidFromLocalId(row['id'], 'review_state'),
      'owner_id': ownerId,
      'card_id': _remoteIdFor(_cardRemoteIdByLocal, row['cardId'], 'card'),
      'level': row['level'] ?? 0,
      'ease_factor': row['easeFactor'] ?? 2.5,
      'interval_days': row['intervalDays'] ?? 0,
      'repetition_count': row['repetitionCount'] ?? 0,
      'correct_count': row['correctCount'] ?? 0,
      'wrong_count': row['wrongCount'] ?? 0,
      'last_reviewed_at': row['lastReviewedAt'],
      'next_review_at': row['nextReviewAt'],
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
    };
  }

  Map<String, Object?> _reviewStateRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _stableLocalId(row['id']),
      'cardId': _cardLocalIdByRemote[row['card_id']?.toString()] ??
          _stableLocalId(row['card_id']),
      'level': row['level'] ?? 0,
      'easeFactor': row['ease_factor'] ?? 2.5,
      'intervalDays': row['interval_days'] ?? 0,
      'repetitionCount': row['repetition_count'] ?? 0,
      'correctCount': row['correct_count'] ?? 0,
      'wrongCount': row['wrong_count'] ?? 0,
      'lastReviewedAt': row['last_reviewed_at'],
      'nextReviewAt': row['next_review_at'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  Map<String, dynamic> _studySessionLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'id': _uuidFromLocalId(row['id'], 'study_session'),
      'owner_id': ownerId,
      'course_id': _remoteIdFor(
        _courseRemoteIdByLocal,
        row['courseId'],
        'course',
      ),
      'mode': row['mode'],
      'total_cards': row['totalCards'] ?? 0,
      'correct_count': row['correctCount'] ?? 0,
      'wrong_count': row['wrongCount'] ?? 0,
      'started_at': row['startedAt'],
      'ended_at': row['endedAt'],
      'updated_at': row['startedAt'],
    };
  }

  Map<String, Object?> _studySessionRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _stableLocalId(row['id']),
      'courseId': _courseLocalIdByRemote[row['course_id']?.toString()] ??
          _stableLocalId(row['course_id']),
      'mode': row['mode'],
      'totalCards': row['total_cards'] ?? 0,
      'correctCount': row['correct_count'] ?? 0,
      'wrongCount': row['wrong_count'] ?? 0,
      'startedAt': row['started_at'],
      'endedAt': row['ended_at'],
    };
  }

  Map<String, dynamic> _studyResultLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'id': _uuidFromLocalId(row['id'], 'study_result'),
      'owner_id': ownerId,
      'session_id': _uuidFromLocalId(row['sessionId'], 'study_session'),
      'card_id': _remoteIdFor(_cardRemoteIdByLocal, row['cardId'], 'card'),
      'answer_text': row['answerText'],
      'is_correct': (row['isCorrect'] == 1),
      'response_time_ms': row['responseTimeMs'],
      'reviewed_at': row['reviewedAt'],
      'updated_at': row['reviewedAt'],
    };
  }

  Map<String, Object?> _studyResultRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _stableLocalId(row['id']),
      'sessionId': _stableLocalId(row['session_id']),
      'cardId': _cardLocalIdByRemote[row['card_id']?.toString()] ??
          _stableLocalId(row['card_id']),
      'answerText': row['answer_text'],
      'isCorrect': row['is_correct'] == true ? 1 : 0,
      'responseTimeMs': row['response_time_ms'],
      'reviewedAt': row['reviewed_at'],
    };
  }

  Map<String, dynamic> _questionLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'id': _uuidFromLocalId(row['id'], 'question'),
      'owner_id': ownerId,
      'course_id': _remoteIdFor(
        _courseRemoteIdByLocal,
        row['courseId'],
        'course',
      ),
      'card_id': _remoteIdFor(_cardRemoteIdByLocal, row['cardId'], 'card'),
      'language_code': row['languageCode'],
      'direction': row['direction'],
      'source_term': row['sourceTerm'],
      'source_definition': row['sourceDefinition'],
      'question': row['question'],
      'answer': row['answer'],
      'created_at': row['createdAt'],
      'updated_at': row['updatedAt'] ?? row['createdAt'],
    };
  }

  Map<String, Object?> _questionRemoteToLocal(Map<String, dynamic> row) {
    return {
      'id': _stableLocalId(row['id']),
      'courseId': _courseLocalIdByRemote[row['course_id']?.toString()] ??
          _stableLocalId(row['course_id']),
      'cardId': _cardLocalIdByRemote[row['card_id']?.toString()] ??
          _stableLocalId(row['card_id']),
      'languageCode': row['language_code'],
      'direction': row['direction'],
      'sourceTerm': row['source_term'],
      'sourceDefinition': row['source_definition'],
      'question': row['question'],
      'answer': row['answer'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  Map<String, dynamic> _appSettingLocalToRemote(
    Map<String, Object?> row,
    String ownerId,
  ) {
    return {
      'key': row['key'],
      'owner_id': ownerId,
      'value': row['value'],
      'updated_at': row['updatedAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _appSettingRemoteToLocal(Map<String, dynamic> row) {
    return {
      'key': row['key'],
      'value': row['value'],
      'updatedAt': row['updated_at'],
    };
  }

  // ========== Helpers ==========

  Future<List<Map<String, dynamic>>> _fetchAllRemoteRows({
    required SupabaseClient client,
    required String table,
    required String ownerId,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final response = await client
          .from(table)
          .select()
          .eq('owner_id', ownerId)
          .order(table == 'app_settings' ? 'key' : 'id')
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return rows;
  }

  Future<void> _ensureLocalDeviceId(Database db) async {
    const key = 'sync.localDeviceId';
    final existing = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final saved = existing.isEmpty
        ? ''
        : existing.first['value']?.toString().trim() ?? '';
    if (saved.isNotEmpty) {
      _localDeviceId = saved;
      return;
    }

    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int length) => bytes
        .skip(start)
        .take(length)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    _localDeviceId = '${hex(0, 4)}-${hex(4, 2)}-${hex(6, 2)}-'
        '${hex(8, 2)}-${hex(10, 6)}';
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': _localDeviceId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _isLocalOnlySetting(Object? keyValue) {
    final key = keyValue?.toString() ?? '';
    return key == 'sync.localDeviceId' ||
        key == 'sync.localBoundOwnerId' ||
        key.startsWith('sync.migration.') ||
        key.startsWith('sync.offlineDeleteRecovery');
  }

  Future<void> _prepareLocalOwner(Database db, String ownerId) async {
    const key = 'sync.localBoundOwnerId';
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final previousOwner =
        rows.isEmpty ? '' : rows.first['value']?.toString() ?? '';
    if (previousOwner == ownerId) return;

    if (previousOwner.isNotEmpty) {
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = tableRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();
      const deletionOrder = [
        'study_results',
        'review_sentence_questions',
        'review_states',
        'study_sessions',
        'card_examples',
        'course_tags',
        'import_exports',
        'cards',
        'courses',
        'topics',
      ];
      await db.transaction((txn) async {
        for (final table in deletionOrder) {
          if (tables.contains(table)) await txn.delete(table);
        }
        final settingRows = await txn.query('app_settings', columns: ['key']);
        for (final setting in settingRows) {
          final settingKey = setting['key'];
          if (!_isLocalOnlySetting(settingKey)) {
            await txn.delete(
              'app_settings',
              where: 'key = ?',
              whereArgs: [settingKey],
            );
          }
        }
      });
    }

    await _setLocalSetting(db, key, ownerId);
  }

  Future<void> _cleanupCrossAccountTombstones(
    Database db,
    SupabaseClient client,
    String ownerId,
  ) async {
    final markerKey = 'sync.migration.crossAccountCleanup.$ownerId';
    final marker = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [markerKey],
      limit: 1,
    );
    if (marker.isNotEmpty) return;

    try {
      // These historical tombstones were copied while the same SQLite file
      // was reused by another account. Remove children before parents.
      await client
          .from('cards')
          .delete()
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'not.is', null);
      await client
          .from('courses')
          .delete()
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'not.is', null);
      await client
          .from('topics')
          .delete()
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'not.is', null);

      await db.delete('cards', where: 'deletedAt IS NOT NULL');
      await db.delete('courses', where: 'deletedAt IS NOT NULL');
      await db.delete('topics', where: 'deletedAt IS NOT NULL');
      await _setLocalSetting(db, markerKey, 'done');
    } catch (error) {
      print('SYNC CLEANUP cross-account tombstones ERROR: $error');
    }
  }

  Future<void> _removeRemoteBundledImportMetadata(
    SupabaseClient client,
    String ownerId,
  ) async {
    try {
      await client
          .from('import_exports')
          .delete()
          .eq('owner_id', ownerId)
          .or(
            'file_path.like.assets/TOEIC/%,file_path.like.assets/TOCFL/%',
          );
    } catch (error) {
      // Metadata cleanup must not make the learning-data sync fail.
      print('SYNC CLEANUP import_exports ERROR: $error');
    }
  }

  Future<void> _removeBundledVocabulary(
    Database db,
    SupabaseClient client,
    String ownerId,
  ) async {
    const bundledDescriptionFilter =
        'description.like.%assets/TOEIC/%,description.like.%assets/TOCFL/%';

    try {
      // Cards and their dependent learning rows are removed by the remote
      // course foreign-key cascade.
      await client
          .from('courses')
          .delete()
          .eq('owner_id', ownerId)
          .or(bundledDescriptionFilter);

      final activeCourses = await client
          .from('courses')
          .select('topic_id')
          .eq('owner_id', ownerId)
          .filter('deleted_at', 'is', null);
      final usedTopicIds = List<Map<String, dynamic>>.from(activeCourses)
          .map((row) => row['topic_id']?.toString())
          .whereType<String>()
          .toSet();
      final remoteTopics = await client
          .from('topics')
          .select('id,name,deleted_at')
          .eq('owner_id', ownerId);
      const bundledTopicNames = {
        'chủ đề khác',
        'toeic',
        'tiếng trung b1',
      };
      for (final topic in List<Map<String, dynamic>>.from(remoteTopics)) {
        final topicId = topic['id']?.toString();
        final name = _normalizeIdentity(topic['name']);
        if (topicId != null &&
            !usedTopicIds.contains(topicId) &&
            bundledTopicNames.contains(name)) {
          await client
              .from('topics')
              .delete()
              .eq('owner_id', ownerId)
              .eq('id', topicId);
        }
      }
    } catch (error) {
      print('SYNC CLEANUP bundled remote data ERROR: $error');
    }

    // Older app versions stored bundled assets as local tombstones. They are
    // not user data and must not be pushed back on the next sync.
    await db.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM cards
        WHERE courseId IN (
          SELECT id FROM courses
          WHERE description LIKE ? OR description LIKE ?
        )
        ''',
        ['%assets/TOEIC/%', '%assets/TOCFL/%'],
      );
      await txn.rawDelete(
        '''
        DELETE FROM courses
        WHERE description LIKE ? OR description LIKE ?
        ''',
        ['%assets/TOEIC/%', '%assets/TOCFL/%'],
      );
      await txn.rawDelete(
        '''
        DELETE FROM topics
        WHERE lower(trim(name)) IN (?, ?, ?)
          AND NOT EXISTS (
            SELECT 1 FROM courses c WHERE c.topicId = topics.id
          )
        ''',
        ['chủ đề khác', 'toeic', 'tiếng trung b1'],
      );
    });
  }

  Future<void> _prepareIdentityMaps(
    Database db,
    SupabaseClient client,
    String ownerId,
  ) async {
    _topicRemoteIdByLocal.clear();
    _courseRemoteIdByLocal.clear();
    _cardRemoteIdByLocal.clear();
    _topicLocalIdByRemote.clear();
    _courseLocalIdByRemote.clear();
    _cardLocalIdByRemote.clear();

    final remoteTopics = await _fetchAllRemoteRows(
      client: client,
      table: 'topics',
      ownerId: ownerId,
    );
    final remoteCourses = await _fetchAllRemoteRows(
      client: client,
      table: 'courses',
      ownerId: ownerId,
    );
    final remoteCards = await _fetchAllRemoteRows(
      client: client,
      table: 'cards',
      ownerId: ownerId,
    );

    final activeTopicByName = <String, Map<String, dynamic>>{};
    final deletedTopicByName = <String, Map<String, dynamic>>{};
    final topicByPulledLocalId = <String, Map<String, dynamic>>{};
    for (final remote in remoteTopics) {
      topicByPulledLocalId['${_stableLocalId(remote['id'])}'] = remote;
      final identity = _normalizeIdentity(remote['name']);
      if (remote['deleted_at'] == null) {
        activeTopicByName[identity] = remote;
      } else {
        deletedTopicByName[identity] = remote;
      }
    }
    final localTopics = await db.query('topics', orderBy: 'id ASC');
    for (final local in localTopics) {
      final localId = _localInt(local['id']);
      if (localId == null) continue;
      final identity = _normalizeIdentity(local['name']);
      var remote = topicByPulledLocalId['$localId'] ??
          (local['deletedAt'] == null
              ? activeTopicByName[identity] ?? deletedTopicByName[identity]
              : deletedTopicByName[identity] ?? activeTopicByName[identity]);
      final remoteId = remote?['id']?.toString() ??
          _uuidFromLocalId(localId, 'topic');
      _topicRemoteIdByLocal['$localId'] = remoteId;
      _topicLocalIdByRemote.putIfAbsent(remoteId, () => localId);
    }
    final usedTopicLocalIds = localTopics
        .map((row) => _localInt(row['id']))
        .whereType<int>()
        .toSet();
    for (final remote in remoteTopics) {
      final remoteId = remote['id']?.toString();
      if (remoteId == null || _topicLocalIdByRemote.containsKey(remoteId)) {
        continue;
      }
      final localId = _availableLocalId(remoteId, usedTopicLocalIds);
      _topicLocalIdByRemote[remoteId] = localId;
      usedTopicLocalIds.add(localId);
    }

    final activeCourseByTitle = <String, Map<String, dynamic>>{};
    final deletedCourseByTitle = <String, Map<String, dynamic>>{};
    final courseByPulledLocalId = <String, Map<String, dynamic>>{};
    for (final remote in remoteCourses) {
      courseByPulledLocalId['${_stableLocalId(remote['id'])}'] = remote;
      final identity = _normalizeIdentity(remote['title']);
      if (remote['deleted_at'] == null) {
        activeCourseByTitle[identity] = remote;
      } else {
        deletedCourseByTitle[identity] = remote;
      }
    }
    final localCourses = await db.query('courses', orderBy: 'id ASC');
    for (final local in localCourses) {
      final localId = _localInt(local['id']);
      if (localId == null) continue;
      final identity = _normalizeIdentity(local['title']);
      var remote = courseByPulledLocalId['$localId'] ??
          (local['deletedAt'] == null
              ? activeCourseByTitle[identity] ?? deletedCourseByTitle[identity]
              : deletedCourseByTitle[identity] ?? activeCourseByTitle[identity]);
      final remoteId = remote?['id']?.toString() ??
          _uuidFromLocalId(localId, 'course');
      _courseRemoteIdByLocal['$localId'] = remoteId;
      _courseLocalIdByRemote.putIfAbsent(remoteId, () => localId);
    }
    final usedCourseLocalIds = localCourses
        .map((row) => _localInt(row['id']))
        .whereType<int>()
        .toSet();
    for (final remote in remoteCourses) {
      final remoteId = remote['id']?.toString();
      if (remoteId == null || _courseLocalIdByRemote.containsKey(remoteId)) {
        continue;
      }
      final localId = _availableLocalId(remoteId, usedCourseLocalIds);
      _courseLocalIdByRemote[remoteId] = localId;
      usedCourseLocalIds.add(localId);
    }

    final activeCardByContent = <String, Map<String, dynamic>>{};
    final deletedCardByContent = <String, Map<String, dynamic>>{};
    final cardByPulledLocalId = <String, Map<String, dynamic>>{};
    for (final remote in remoteCards) {
      cardByPulledLocalId['${_stableLocalId(remote['id'])}'] = remote;
      final identity = _remoteCardIdentity(remote);
      if (remote['deleted_at'] == null) {
        activeCardByContent[identity] = remote;
      } else {
        deletedCardByContent[identity] = remote;
      }
    }
    final localCards = await db.query('cards', orderBy: 'id ASC');
    for (final local in localCards) {
      final localId = _localInt(local['id']);
      if (localId == null) continue;
      final remoteCourseId = _remoteIdFor(
        _courseRemoteIdByLocal,
        local['courseId'],
        'course',
      );
      final identity = _cardIdentity(
        remoteCourseId,
        local['position'],
        local['term'],
        local['definition'],
      );
      var remote = cardByPulledLocalId['$localId'] ??
          (local['deletedAt'] == null
              ? activeCardByContent[identity] ?? deletedCardByContent[identity]
              : deletedCardByContent[identity] ?? activeCardByContent[identity]);
      final remoteId = remote?['id']?.toString() ??
          _uuidFromLocalId(localId, 'card');
      _cardRemoteIdByLocal['$localId'] = remoteId;
      _cardLocalIdByRemote.putIfAbsent(remoteId, () => localId);
    }
    final usedCardLocalIds = localCards
        .map((row) => _localInt(row['id']))
        .whereType<int>()
        .toSet();
    for (final remote in remoteCards) {
      final remoteId = remote['id']?.toString();
      if (remoteId == null || _cardLocalIdByRemote.containsKey(remoteId)) {
        continue;
      }
      final localId = _availableLocalId(remoteId, usedCardLocalIds);
      _cardLocalIdByRemote[remoteId] = localId;
      usedCardLocalIds.add(localId);
    }
  }

  int _availableLocalId(String remoteId, Set<int> usedIds) {
    var candidate = _stableLocalId(remoteId);
    if (candidate == 0) candidate = 1;
    while (usedIds.contains(candidate)) {
      candidate = (candidate + 1) & 0x7fffffff;
      if (candidate == 0) candidate = 1;
    }
    return candidate;
  }

  String _remoteIdFor(
    Map<String, String> identities,
    Object? localId,
    String namespace,
  ) {
    final key = localId?.toString() ?? '';
    return identities.putIfAbsent(
      key,
      () => _uuidFromLocalId(localId, namespace),
    );
  }

  int? _localInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int _stableLocalId(Object? value) {
    final candidate = _stableHash32(value?.toString() ?? '') & 0x7fffffff;
    return candidate == 0 ? 1 : candidate;
  }

  int _stableHash32(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  bool _isRemoteNewer(String remoteValue, String localValue) {
    if (remoteValue.isEmpty) return false;
    if (localValue.isEmpty) return true;
    final remote = _parseSyncTimestamp(remoteValue);
    final local = _parseSyncTimestamp(localValue);
    if (remote != null && local != null) return remote.isAfter(local);
    return remoteValue.compareTo(localValue) > 0;
  }

  bool _localRowIsNewer(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localValue =
        (local['updated_at'] ?? local['created_at'])?.toString() ?? '';
    final remoteValue =
        (remote['updated_at'] ?? remote['created_at'])?.toString() ?? '';
    if (localValue.isEmpty) return false;
    if (remoteValue.isEmpty) return true;

    final localTime = _parseSyncTimestamp(localValue);
    final remoteTime = _parseSyncTimestamp(remoteValue);
    if (localTime != null && remoteTime != null) {
      return localTime.isAfter(remoteTime);
    }
    return localValue.compareTo(remoteValue) > 0;
  }

  DateTime? _parseSyncTimestamp(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text);
    // Legacy SQLite values have no offset. Supabase interpreted those strings
    // as UTC when writing timestamptz, so parse them the same way locally.
    return DateTime.tryParse(hasTimezone ? text : '${text}Z')?.toUtc();
  }

  String _normalizeIdentity(Object? value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _remoteCardIdentity(Map<String, dynamic> row) {
    return _cardIdentity(
      row['course_id'],
      row['position'],
      row['term'],
      row['definition'],
    );
  }

  String _cardIdentity(
    Object? courseId,
    Object? position,
    Object? term,
    Object? definition,
  ) {
    return '${courseId ?? ''}|${position ?? 0}|'
        '${_normalizeIdentity(term)}|${_normalizeIdentity(definition)}';
  }

  /// Deterministic UUID v5-like from integer local ID + namespace.
  /// This ensures the same local row always maps to the same remote UUID.
  String _uuidFromLocalId(Object? localId, String namespace) {
    final id = localId?.toString() ?? '0';
    final device = _localDeviceId.isEmpty ? 'legacy' : _localDeviceId;
    final seed = '$device:$namespace:$id';
    // Simple deterministic "UUID" from hash – sufficient for personal sync
    final hash = _stableHash32(seed);
    final hex = hash.toRadixString(16).padLeft(8, '0');
    return '00000000-0000-4000-8000-$hex${hex.substring(0, 4)}';
  }

  Future<void> _setLocalSetting(Database db, String key, String value) async {
    await db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updatedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}


class SyncResult {
  final int pushed;
  final int pulled;
  final int pulledCourses;
  final int pulledCards;
  final String? error;

  SyncResult({
    required this.pushed,
    required this.pulled,
    this.pulledCourses = 0,
    this.pulledCards = 0,
    this.error,
  });

  bool get hasError => error != null;
  int get total => pushed + pulled;
  String get downloadSummary =>
      'Hoàn tất • Tải về $pulledCourses học phần • $pulledCards thẻ';

  @override
  String toString() {
    if (hasError) return 'Lỗi đồng bộ: $error';
    return 'Đồng bộ: đẩy lên $pushed, tải về $pulled';
  }
}
