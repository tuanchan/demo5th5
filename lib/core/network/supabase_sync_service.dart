import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'server_log_service.dart';
import 'supabase_config.dart';

enum _SyncOperation { pullReplace, merge, livePush }

class _SyncCancelled implements Exception {}

/// Service to synchronize local SQLite data with Supabase when user logs in.
/// Uses a "last-write-wins" merge strategy based on updatedAt timestamps.
class SupabaseSyncService {
  SupabaseSyncService._();

  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool _isSyncing = false;
  bool _cancelSyncRequested = false;
  String? _lastSyncError;
  Future<SyncResult>? _activeSync;
  final StreamController<SyncResult> _syncCompletedController =
      StreamController<SyncResult>.broadcast();
  final StreamController<void> _remoteDataChangedController =
      StreamController<void>.broadcast();
  final Map<String, String> _topicRemoteIdByLocal = {};
  final Map<String, String> _courseRemoteIdByLocal = {};
  final Map<String, String> _cardRemoteIdByLocal = {};
  final Map<String, int> _topicLocalIdByRemote = {};
  final Map<String, int> _courseLocalIdByRemote = {};
  final Map<String, int> _cardLocalIdByRemote = {};
  final Map<String, List<Map<String, dynamic>>> _prefetchedRemoteRows = {};
  String _localDeviceId = '';
  _SyncOperation _operation = _SyncOperation.pullReplace;
  String? _sessionOwnerId;
  String? _sessionStartedAt;
  String? _identityOwnerId;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeMergeDebounce;
  final Map<String, PostgresChangePayload> _realtimePendingChanges = {};
  Future<void> _studySyncTail = Future<void>.value();
  bool _isPushingStudyData = false;

  bool get isSyncing => _isSyncing;
  bool get isSyncCancellationRequested => _cancelSyncRequested;
  String? get lastSyncError => _lastSyncError;
  Future<SyncResult>? get activeSync => _activeSync;
  Stream<SyncResult> get syncCompleted => _syncCompletedController.stream;
  Stream<void> get remoteDataChanged => _remoteDataChangedController.stream;

  /// Pull-only replacement. No local rows are uploaded by this action.
  Future<SyncResult> syncAll() =>
      _startManualSync(_SyncOperation.pullReplace);

  Future<SyncResult> mergeAll() => _startManualSync(_SyncOperation.merge);

  Future<SyncResult> _startManualSync(_SyncOperation operation) async {
    final active = _activeSync;
    if (active != null) await active;
    return _startSync(operation);
  }

  Future<SyncResult> _startSync(_SyncOperation operation) {
    final active = _activeSync;
    if (active != null) return active;
    if (_isPushingStudyData) {
      return _studySyncTail.then((_) => _startSync(operation));
    }
    if (!SupabaseConfig.isLoggedIn) {
      return Future.value(
        SyncResult(pushed: 0, pulled: 0, error: 'Chưa đăng nhập'),
      );
    }

    _operation = operation;
    _cancelSyncRequested = false;
    final future = _syncAllOnce();
    _activeSync = future;
    future.then(_syncCompletedController.add);
    return future;
  }

  void cancelActiveSync() {
    if (!_isSyncing) return;
    _cancelSyncRequested = true;
    _realtimeMergeDebounce?.cancel();
    _realtimeMergeDebounce = null;
  }

  void _throwIfSyncCancelled() {
    if (_cancelSyncRequested) throw _SyncCancelled();
  }

  /// Wait for an in-flight sync, then start a fresh pass that includes local
  /// mutations made while that earlier pass was running.
  Future<SyncResult> syncPendingChanges() async {
    final active = _activeSync;
    if (active != null) await active;
    if (!SupabaseConfig.isLoggedIn) {
      return SyncResult(pushed: 0, pulled: 0, error: 'Chưa đăng nhập');
    }
    await beginAuthenticatedSession();
    return _startSync(_SyncOperation.livePush);
  }

  /// Pushes the complete SRS state after a study session finishes. Card IDs
  /// are resolved against Supabase first, matching the desktop sync flow.
  Future<SyncResult> syncReviewStatesAfterStudy({
    int? sessionId,
    Iterable<int>? cardIds,
  }) {
    final requestedCardIds = cardIds?.toSet();
    final completer = Completer<SyncResult>();
    _studySyncTail = _studySyncTail.then((_) async {
      try {
        completer.complete(
          await _syncReviewStatesAfterStudyOnce(
            sessionId: sessionId,
            cardIds: requestedCardIds,
          ),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }).catchError((_) {});
    return completer.future;
  }

  Future<SyncResult> _syncReviewStatesAfterStudyOnce({
    int? sessionId,
    Set<int>? cardIds,
  }) async {
    final active = _activeSync;
    if (active != null) await active;
    if (!SupabaseConfig.isLoggedIn) {
      return SyncResult(pushed: 0, pulled: 0, error: 'ChÆ°a Ä‘Äƒng nháº­p');
    }

    try {
      await ServerLogService.write('study_sync.start', details: {
        'sessionId': sessionId,
        'requestedCards': cardIds?.length ?? 'from-session',
      });
      // Push newly created topics/courses/cards first. Otherwise an SRS row can
      // be skipped because its card does not exist on Supabase yet.
      final dependencySync = await syncPendingChanges();
      _isPushingStudyData = true;
      await ServerLogService.write('study_sync.dependencies', details: {
        'sessionId': sessionId,
        'pushed': dependencySync.pushed,
        'pulled': dependencySync.pulled,
        'error': dependencySync.error,
      });
      final db = await AppDatabase.instance.database;
      final ownerId = SupabaseConfig.currentUser!.id;
      final targetCardIds = <int>{...?cardIds};
      if (sessionId != null) {
        final resultCards = await db.query(
          'study_results',
          columns: ['cardId'],
          where: 'sessionId = ?',
          whereArgs: [sessionId],
        );
        targetCardIds.addAll(
          resultCards
              .map((row) => _localInt(row['cardId']))
              .whereType<int>(),
        );
      }
      final hasExplicitTargets = sessionId != null || cardIds != null;
      final targetWhere = targetCardIds.isEmpty
          ? (hasExplicitTargets ? ' AND 1 = 0' : '')
          : ' AND rs.cardId IN (${List.filled(targetCardIds.length, '?').join(',')})';
      // A manually assigned due date is valid even at SRS level 0, so push
      // every local review state instead of filtering only progressed cards.
      final localStates = await db.rawQuery('''
        SELECT rs.*
        FROM review_states rs
        INNER JOIN cards ca ON ca.id = rs.cardId
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.deletedAt IS NULL
          AND c.deletedAt IS NULL
          AND COALESCE(c.hasLocalNameConflict, 0) = 0
$targetWhere
      ''', targetCardIds.toList());
      await ServerLogService.write('study_sync.local_scope', details: {
        'sessionId': sessionId,
        'cards': targetCardIds.length,
        'srsRows': localStates.length,
      });
      final payload = <Map<String, dynamic>>[];
      final skippedCardIds = <int>[];
      final failedRemoteCardIds = <String>[];
      final missingScheduleCardIds = <String>{};
      final timestamp = DateTime.now().toUtc().toIso8601String();

      for (final state in localStates) {
        final cardId = _localInt(state['cardId']);
        if (cardId == null) continue;
        final mappedRemoteCardId = _cardRemoteIdByLocal['$cardId'];
        final remoteCardId = mappedRemoteCardId?.isNotEmpty == true
            ? mappedRemoteCardId
            : await findRemoteCardId(cardId);
        if (remoteCardId == null || remoteCardId.isEmpty) {
          skippedCardIds.add(cardId);
          continue;
        }

        final row = _reviewStateLocalToRemote(state, ownerId)
          ..remove('id')
          ..['card_id'] = remoteCardId
          ..['updated_at'] = timestamp;
        payload.add(row);
      }

      for (var start = 0; start < payload.length; start += 200) {
        final end = math.min(start + 200, payload.length);
        final chunk = payload.sublist(start, end);
        try {
          final savedRows = await SupabaseConfig.client
              .from('review_states')
              .upsert(chunk, onConflict: 'owner_id,card_id')
              .select('card_id,next_review_at,interval_days');
          if (savedRows.length != chunk.length) {
            throw StateError(
              'Server chỉ trả về ${savedRows.length}/${chunk.length} SRS',
            );
          }
          missingScheduleCardIds.addAll(
            savedRows
                .where((row) {
                  final value = row['next_review_at']?.toString() ?? '';
                  return value.isEmpty;
                })
                .map((row) => row['card_id']?.toString())
                .whereType<String>(),
          );
        } catch (_) {
          // One stale foreign key must not prevent every valid SRS state in
          // the same batch from reaching Supabase.
          for (final row in chunk) {
            try {
              final savedRows = await SupabaseConfig.client
                  .from('review_states')
                  .upsert([row], onConflict: 'owner_id,card_id')
                  .select('card_id,next_review_at,interval_days');
              if (savedRows.length != 1) {
                throw StateError('Server không xác nhận SRS vừa lưu');
              }
              final savedSchedule =
                  savedRows.first['next_review_at']?.toString() ?? '';
              if (savedSchedule.isEmpty) {
                missingScheduleCardIds.add(row['card_id'].toString());
              }
            } catch (_) {
              failedRemoteCardIds.add(row['card_id']?.toString() ?? '?');
            }
          }
        }
      }
      await ServerLogService.write('study_sync.srs_uploaded', details: {
        'sessionId': sessionId,
        'payload': payload.length,
        'skippedCards': skippedCardIds.length,
        'failedCards': failedRemoteCardIds.length,
      });

      // Some existing server rows can acknowledge the conflict update while
      // still returning an empty schedule. Apply those SRS fields explicitly
      // before the final read-back verification.
      for (final cardId in missingScheduleCardIds) {
        final source = payload.where((row) => row['card_id'] == cardId);
        if (source.isEmpty) continue;
        final row = source.first;
        await SupabaseConfig.client
            .from('review_states')
            .update({
              'level': row['level'],
              'ease_factor': row['ease_factor'],
              'interval_days': row['interval_days'],
              'repetition_count': row['repetition_count'],
              'correct_count': row['correct_count'],
              'wrong_count': row['wrong_count'],
              'last_reviewed_at': row['last_reviewed_at'],
              'next_review_at': row['next_review_at'],
              'updated_at': timestamp,
            })
            .eq('owner_id', ownerId)
            .eq('card_id', cardId);
      }

      final expectedScheduleCount = payload.where((row) {
        final nextReviewAt = row['next_review_at']?.toString() ?? '';
        return nextReviewAt.isNotEmpty;
      }).length;
      var verifiedStateCount = 0;
      var verifiedMatchingStateCount = 0;
      var verifiedScheduleCount = 0;
      final expectedStateByCardId = <String, Map<String, dynamic>>{
        for (final row in payload)
          if (row['card_id'] != null) row['card_id'].toString(): row,
      };
      bool sameTimestamp(Object? left, Object? right) {
        final leftText = left?.toString() ?? '';
        final rightText = right?.toString() ?? '';
        if (leftText.isEmpty || rightText.isEmpty) {
          return leftText.isEmpty && rightText.isEmpty;
        }
        final leftTime = DateTime.tryParse(leftText);
        final rightTime = DateTime.tryParse(rightText);
        if (leftTime != null && rightTime != null) {
          return leftTime.isAtSameMomentAs(rightTime);
        }
        return leftText == rightText;
      }
      double numberValue(Object? value) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0;
      }
      final remoteCardIds = payload
          .map((row) => row['card_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      for (var start = 0; start < remoteCardIds.length; start += 200) {
        final end = math.min(start + 200, remoteCardIds.length);
        final rows = await SupabaseConfig.client
            .from('review_states')
            .select(
              'card_id,level,ease_factor,interval_days,repetition_count,'
              'correct_count,wrong_count,last_reviewed_at,next_review_at',
            )
            .eq('owner_id', ownerId)
            .inFilter('card_id', remoteCardIds.sublist(start, end));
        verifiedStateCount += rows.length;
        verifiedMatchingStateCount += rows.where((remote) {
          final expected = expectedStateByCardId[remote['card_id']?.toString()];
          if (expected == null) return false;
          return _localInt(remote['level']) == _localInt(expected['level']) &&
              (numberValue(remote['ease_factor']) -
                          numberValue(expected['ease_factor']))
                      .abs() <
                  0.000001 &&
              _localInt(remote['interval_days']) ==
                  _localInt(expected['interval_days']) &&
              _localInt(remote['repetition_count']) ==
                  _localInt(expected['repetition_count']) &&
              _localInt(remote['correct_count']) ==
                  _localInt(expected['correct_count']) &&
              _localInt(remote['wrong_count']) ==
                  _localInt(expected['wrong_count']) &&
              sameTimestamp(
                remote['last_reviewed_at'],
                expected['last_reviewed_at'],
              ) &&
              sameTimestamp(remote['next_review_at'], expected['next_review_at']);
        }).length;
        verifiedScheduleCount += rows.where((row) {
          final nextReviewAt = row['next_review_at']?.toString() ?? '';
          return nextReviewAt.isNotEmpty;
        }).length;
      }
      var verifiedStudyResultCount = 0;
      var expectedStudyResultCount = 0;
      String? studyDataError;
      if (sessionId != null) {
        final verification = await _pushAndVerifyStudySession(
          db: db,
          ownerId: ownerId,
          localSessionId: sessionId,
        );
        expectedStudyResultCount = verification.expected;
        verifiedStudyResultCount = verification.verified;
        studyDataError = verification.error;
      }

      final errors = <String>[
        if (dependencySync.hasError)
          'Lỗi đồng bộ dữ liệu cha: ${dependencySync.error}',
        if (skippedCardIds.isNotEmpty)
          'Không tìm thấy ${skippedCardIds.length} thẻ trên server',
        if (failedRemoteCardIds.isNotEmpty)
          'Không đẩy được SRS của ${failedRemoteCardIds.length} thẻ',
        if (verifiedStateCount != payload.length - failedRemoteCardIds.length)
          'Server chỉ lưu $verifiedStateCount/${payload.length - failedRemoteCardIds.length} SRS',
        if (verifiedScheduleCount != expectedScheduleCount)
          'Server chỉ xác nhận $verifiedScheduleCount/$expectedScheduleCount lịch ôn',
      ];
      if (verifiedMatchingStateCount != verifiedStateCount) {
        errors.add(
          'Server chỉ khớp $verifiedMatchingStateCount/'
          '$verifiedStateCount giá trị SRS',
        );
      }
      if (studyDataError != null) errors.add(studyDataError);
      if (verifiedStudyResultCount != expectedStudyResultCount) {
        errors.add(
          'Server chỉ xác nhận $verifiedStudyResultCount/'
          '$expectedStudyResultCount kết quả học',
        );
      }
      print(
        'SRS SERVER RESULT: states=$verifiedStateCount/${payload.length}, '
        'scheduled=$verifiedScheduleCount/$expectedScheduleCount, '
        'skippedCards=${skippedCardIds.length}',
      );
      await ServerLogService.write('study_sync.finish', details: {
        'sessionId': sessionId,
        'srs': '$verifiedStateCount/${payload.length}',
        'srsValues': '$verifiedMatchingStateCount/$verifiedStateCount',
        'schedules': '$verifiedScheduleCount/$expectedScheduleCount',
        'studyResults': '$verifiedStudyResultCount/$expectedStudyResultCount',
        'error': errors.isEmpty ? null : errors.join(' | '),
      });
      _isPushingStudyData = false;
      return SyncResult(
        pushed: verifiedStateCount + verifiedStudyResultCount,
        pulled: 0,
        error: errors.isEmpty ? null : errors.join(' | '),
        logs: [
          'SRS: server xác nhận $verifiedStateCount/${payload.length} trạng thái',
          'Lịch ôn: server xác nhận $verifiedScheduleCount/$expectedScheduleCount ngày',
        ],
      );
    } catch (error) {
      _isPushingStudyData = false;
      await ServerLogService.write('study_sync.error', details: {
        'sessionId': sessionId,
        'error': error,
      });
      return SyncResult(pushed: 0, pulled: 0, error: error.toString());
    }
  }

  Future<({int expected, int verified, String? error})>
      _pushAndVerifyStudySession({
    required Database db,
    required String ownerId,
    required int localSessionId,
  }) async {
    final sessions = await db.query(
      'study_sessions',
      where: 'id = ?',
      whereArgs: [localSessionId],
      limit: 1,
    );
    if (sessions.isEmpty) {
      return (expected: 0, verified: 0, error: 'Không tìm thấy phiên học local');
    }

    final session = sessions.first;
    final localCourseId = _localInt(session['courseId']);
    final mappedRemoteCourseId = localCourseId == null
        ? null
        : _courseRemoteIdByLocal['$localCourseId'];
    final remoteCourseId = mappedRemoteCourseId?.isNotEmpty == true
        ? mappedRemoteCourseId
        : (localCourseId == null
              ? null
              : await findRemoteCourseId(localCourseId));
    if (remoteCourseId == null || remoteCourseId.isEmpty) {
      return (
        expected: 0,
        verified: 0,
        error: 'Không tìm thấy học phần của phiên học trên server',
      );
    }

    final remoteSessionId = _uuidFromLocalId(localSessionId, 'study_session');
    final sessionPayload = _studySessionLocalToRemote(session, ownerId)
      ..['id'] = remoteSessionId
      ..['course_id'] = remoteCourseId
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await SupabaseConfig.client
        .from('study_sessions')
        .upsert([sessionPayload], onConflict: 'id');

    final localResults = await db.query(
      'study_results',
      where: 'sessionId = ?',
      whereArgs: [localSessionId],
      orderBy: 'id ASC',
    );
    final sessionAnsweredCount =
        (_localInt(session['correctCount']) ?? 0) +
        (_localInt(session['wrongCount']) ?? 0);
    final payload = <Map<String, dynamic>>[];
    final unmappedCardIds = <int>[];
    for (final result in localResults) {
      final localCardId = _localInt(result['cardId']);
      if (localCardId == null) continue;
      final mappedRemoteCardId = _cardRemoteIdByLocal['$localCardId'];
      final remoteCardId = mappedRemoteCardId?.isNotEmpty == true
          ? mappedRemoteCardId
          : await findRemoteCardId(localCardId);
      if (remoteCardId == null || remoteCardId.isEmpty) {
        unmappedCardIds.add(localCardId);
        continue;
      }
      payload.add(
        _studyResultLocalToRemote(result, ownerId)
          ..['session_id'] = remoteSessionId
          ..['card_id'] = remoteCardId,
      );
    }
    await ServerLogService.write('study_sync.results_prepared', details: {
      'sessionId': localSessionId,
      'sessionTotalCards': session['totalCards'],
      'sessionAnswered': sessionAnsweredCount,
      'localResults': localResults.length,
      'payload': payload.length,
      'unmappedCards': unmappedCardIds.length,
    });

    for (var start = 0; start < payload.length; start += 200) {
      final end = math.min(start + 200, payload.length);
      await SupabaseConfig.client
          .from('study_results')
          .upsert(payload.sublist(start, end), onConflict: 'id');
    }
    var verifiedRows = await SupabaseConfig.client
        .from('study_results')
        .select('id')
        .eq('owner_id', ownerId)
        .eq('session_id', remoteSessionId);
    // Remove only stale extras after every current local result has been
    // accepted. This keeps an undone answer from inflating the learned count.
    final expectedRemoteIds = payload
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();
    final staleRemoteIds = verifiedRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => !expectedRemoteIds.contains(id))
        .toList();
    if (unmappedCardIds.isEmpty && staleRemoteIds.isNotEmpty) {
      await SupabaseConfig.client
          .from('study_results')
          .delete()
          .eq('owner_id', ownerId)
          .eq('session_id', remoteSessionId)
          .inFilter('id', staleRemoteIds);
      verifiedRows = await SupabaseConfig.client
          .from('study_results')
          .select('id')
          .eq('owner_id', ownerId)
          .eq('session_id', remoteSessionId);
    }
    await ServerLogService.write('study_sync.results_verified', details: {
      'sessionId': localSessionId,
      'expected': localResults.length,
      'verified': verifiedRows.length,
      'removedStale': staleRemoteIds.length,
    });
    final resultErrors = <String>[
      if (sessionAnsweredCount != localResults.length)
        'Phiên ghi nhận $sessionAnsweredCount câu trả lời nhưng local chỉ có '
            '${localResults.length} kết quả',
      if (unmappedCardIds.isNotEmpty)
        'Thiếu ánh xạ server của ${unmappedCardIds.length} thẻ đã học',
    ];
    return (
      expected: localResults.length,
      verified: verifiedRows.length,
      error: resultErrors.isEmpty ? null : resultErrors.join(' | '),
    );
  }

  Future<void> beginAuthenticatedSession({bool newLogin = false}) async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return;
    if (!newLogin &&
        _sessionOwnerId == user.id &&
        _sessionStartedAt?.isNotEmpty == true) {
      startRealtimeSync();
      return;
    }
    if (newLogin || _sessionOwnerId != user.id) {
      _identityOwnerId = null;
    }

    final db = await AppDatabase.instance.database;
    final key = 'sync.sessionStartedAt.${user.id}';
    String? startedAt;
    if (!newLogin) {
      final rows = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      startedAt = rows.isEmpty ? null : rows.first['value']?.toString();
    }
    startedAt ??= DateTime.now().toIso8601String();
    _sessionOwnerId = user.id;
    _sessionStartedAt = startedAt;
    await _setLocalSetting(db, key, startedAt);
    await _setLocalSetting(db, 'sync.localBoundOwnerId', user.id);
    startRealtimeSync();
  }

  void endAuthenticatedSession() {
    stopRealtimeSync();
    _sessionOwnerId = null;
    _sessionStartedAt = null;
    _identityOwnerId = null;
  }

  /// Listens to server-side changes and merges them into the local SQLite
  /// database after a short debounce window.
  void startRealtimeSync() {
    final user = SupabaseConfig.currentUser;
    if (user == null || _realtimeChannel != null) return;

    void onChange(PostgresChangePayload change) => _queueRealtimeChange(change);

    var channel = SupabaseConfig.client.channel('account-sync:${user.id}');
    for (final table in const [
      'topics',
      'courses',
      'cards',
      'review_states',
      'card_examples',
    ]) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'owner_id',
          value: user.id,
        ),
        callback: onChange,
      );
    }
    _realtimeChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError) {
        print('REALTIME SUBSCRIPTION ERROR: $error');
      }
    });
  }

  void stopRealtimeSync() {
    _realtimeMergeDebounce?.cancel();
    _realtimeMergeDebounce = null;
    _realtimePendingChanges.clear();
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseConfig.client.removeChannel(channel));
    }
  }

  void _queueRealtimeChange(PostgresChangePayload change) {
    final row = change.newRecord.isNotEmpty ? change.newRecord : change.oldRecord;
    final id = row['id']?.toString() ?? row['key']?.toString() ?? '';
    if (id.isEmpty) return;
    _realtimePendingChanges['${change.table}:$id'] = change;
    _realtimeMergeDebounce?.cancel();
    _realtimeMergeDebounce = Timer(const Duration(milliseconds: 1200), () async {
      if (!SupabaseConfig.isLoggedIn) return;
      if (_isSyncing || _isPushingStudyData) {
        _realtimeMergeDebounce = Timer(
          const Duration(milliseconds: 1200),
          () => _queueRealtimeChanges(),
        );
        return;
      }
      await _queueRealtimeChanges();
    });
  }

  // A Realtime channel created before a hot reload can retain a callback that
  // referenced this old method. Reconnect it once so subsequent events use
  // the current row-level callback instead of crashing with a method lookup.
  void _queueRealtimeMerge() {
    stopRealtimeSync();
    startRealtimeSync();
  }

  Future<void> _queueRealtimeChanges() async {
    if (!SupabaseConfig.isLoggedIn || _realtimePendingChanges.isEmpty) {
      return;
    }
    if (_isSyncing || _isPushingStudyData) {
      _realtimeMergeDebounce?.cancel();
      _realtimeMergeDebounce = Timer(
        const Duration(milliseconds: 1200),
        _queueRealtimeChanges,
      );
      return;
    }
    final changes = _realtimePendingChanges.values.toList()
      ..sort((a, b) => _realtimeTableOrder(a.table).compareTo(_realtimeTableOrder(b.table)));
    _realtimePendingChanges.clear();

    _isSyncing = true;
    try {
      var changed = false;
      final changesByTable = <String, List<PostgresChangePayload>>{};
      for (final change in changes) {
        changesByTable.putIfAbsent(change.table, () => []).add(change);
      }
      final tables = changesByTable.keys.toList()
        ..sort((a, b) => _realtimeTableOrder(a).compareTo(_realtimeTableOrder(b)));
      for (final table in tables) {
        changed = await _applyRealtimeChanges(changesByTable[table]!) || changed;
      }
      if (changed) _remoteDataChangedController.add(null);
    } catch (error) {
      print('REALTIME APPLY ERROR: $error');
    } finally {
      _isSyncing = false;
      if (_realtimePendingChanges.isNotEmpty) {
        _queueRealtimeChange(_realtimePendingChanges.values.first);
      }
    }
  }

  int _realtimeTableOrder(String table) => switch (table) {
        'topics' => 0,
        'courses' => 1,
        'cards' => 2,
        'card_examples' => 3,
        'review_states' => 4,
        _ => 99,
      };

  /// Realtime delivers the changed row itself. Apply only that row; do not
  /// call mergeAll(), which would re-query every synchronized table.
  Future<bool> _applyRealtimeChanges(
    List<PostgresChangePayload> changes,
  ) async {
    if (changes.isEmpty) return false;
    final table = changes.first.table;
    const supportedTables = {
      'topics',
      'courses',
      'cards',
      'card_examples',
      'review_states',
    };
    if (!supportedTables.contains(table)) return false;
    final db = await AppDatabase.instance.database;
    final rows = <Map<String, dynamic>>[];
    var changed = false;
    for (final change in changes) {
      final source = change.newRecord.isNotEmpty
          ? change.newRecord
          : change.oldRecord;
      final remote = Map<String, dynamic>.from(source);
      final remoteId = remote['id']?.toString();
      if (remoteId == null || remoteId.isEmpty) continue;

      if (change.eventType == PostgresChangeEvent.delete ||
          remote['deleted_at'] != null) {
        final localId = switch (table) {
          'topics' => _topicLocalIdByRemote[remoteId] ?? _stableLocalId(remoteId),
          'courses' => _courseLocalIdByRemote[remoteId] ?? _stableLocalId(remoteId),
          'cards' => _cardLocalIdByRemote[remoteId] ?? _stableLocalId(remoteId),
          _ => _stableLocalId(remoteId),
        };
        await db.delete(table, where: 'id = ?', whereArgs: [localId]);
        changed = true;
        continue;
      }

      if (table == 'topics') {
        _topicLocalIdByRemote.putIfAbsent(remoteId, () => _stableLocalId(remoteId));
      } else if (table == 'courses') {
        _courseLocalIdByRemote.putIfAbsent(remoteId, () => _stableLocalId(remoteId));
      } else if (table == 'cards') {
        _cardLocalIdByRemote.putIfAbsent(remoteId, () => _stableLocalId(remoteId));
      }
      rows.add(remote);
    }
    if (rows.isEmpty) return changed;

    final previousOperation = _operation;
    _operation = _SyncOperation.merge;
    try {
      final ownerId = SupabaseConfig.currentUser!.id;
      final client = SupabaseConfig.client;
      switch (table) {
        case 'topics':
          await _syncTable(
            db: db, client: client, ownerId: ownerId, localTable: 'topics',
            remoteTable: 'topics', idColumn: 'id',
            localToRemote: _topicLocalToRemote, remoteToLocal: _topicRemoteToLocal,
            remoteRowsOverride: rows,
          );
          break;
        case 'courses':
          await _syncTable(
            db: db, client: client, ownerId: ownerId, localTable: 'courses',
            remoteTable: 'courses', idColumn: 'id',
            localToRemote: _courseLocalToRemote, remoteToLocal: _courseRemoteToLocal,
            remoteRowsOverride: rows,
          );
          break;
        case 'cards':
          await _syncTable(
            db: db, client: client, ownerId: ownerId, localTable: 'cards',
            remoteTable: 'cards', idColumn: 'id',
            localToRemote: _cardLocalToRemote, remoteToLocal: _cardRemoteToLocal,
            remoteRowsOverride: rows,
          );
          break;
        case 'card_examples':
          await _syncTable(
            db: db, client: client, ownerId: ownerId, localTable: 'card_examples',
            remoteTable: 'card_examples', idColumn: 'id',
            localToRemote: _cardExampleLocalToRemote,
            remoteToLocal: _cardExampleRemoteToLocal,
            remoteRowsOverride: rows,
          );
          break;
        case 'review_states':
          await _syncTable(
            db: db, client: client, ownerId: ownerId, localTable: 'review_states',
            remoteTable: 'review_states', idColumn: 'id',
            remoteConflictColumns: 'owner_id,card_id',
            localConflictColumns: const ['cardId'],
            localToRemote: _reviewStateLocalToRemote,
            remoteToLocal: _reviewStateRemoteToLocal,
            remoteRowsOverride: rows,
          );
          break;
      }
      return true;
    } finally {
      _operation = previousOperation;
    }
  }

  Future<SyncResult> _syncAllOnce() async {

    _isSyncing = true;
    _lastSyncError = null;
    await ServerLogService.write('sync.start', details: {
      'operation': _operation.name,
    });

    try {
      _prefetchedRemoteRows.clear();
      final ownerId = SupabaseConfig.currentUser!.id;
      final db = await AppDatabase.instance.database;
      final client = SupabaseConfig.client;

      // Apply topic repairs before IDs and foreign keys are mapped for sync.
      await AppDatabase.instance.ensureTopicSchema();

      int pushed = 0;
      int pulled = 0;
      final syncErrors = <String>[];
      final syncLogs = <String>[
        switch (_operation) {
          _SyncOperation.pullReplace => 'Chế độ: tải xuống và thay thế local',
          _SyncOperation.merge => 'Chế độ: merge cloud + local',
          _SyncOperation.livePush => 'Chế độ: cập nhật thay đổi sau đăng nhập',
        },
      ];

      await _ensureLocalDeviceId(db);
      await beginAuthenticatedSession();
      _throwIfSyncCancelled();

      if (_operation != _SyncOperation.livePush) {
        // Download every table successfully before touching local data.
        await _prefetchAccountSnapshot(client, ownerId);
        _throwIfSyncCancelled();
        if (_operation == _SyncOperation.pullReplace) {
          await _clearLocalAccountData(db);
        } else {
          await _markLocalMergeConflicts(db);
        }
      }
      // Refresh on every pass. Pull/cleanup may change local IDs while a hot
      // reload keeps this singleton alive, making cached parent IDs stale and
      // causing foreign-key failures for study sessions and SRS.
      await _prepareIdentityMaps(db, client, ownerId);
      _identityOwnerId = ownerId;

      // Only rows changed after this authenticated session began may upload.
      // Pull/merge never uploads anything.
      final lastSyncAt = _operation == _SyncOperation.livePush
          ? _sessionStartedAt
          : null;

      void collectError(String table, SyncResult result) {
        syncLogs.add(
          '$table: đẩy ${result.pushed}, tải ${result.pulled}'
          '${result.hasError ? ' — ${result.error}' : ''}',
        );
        if (result.hasError) syncErrors.add('$table: ${result.error}');
        unawaited(ServerLogService.write('sync.table', details: {
          'operation': _operation.name,
          'table': table,
          'pushed': result.pushed,
          'pulled': result.pulled,
          'error': result.error,
        }));
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
        lastSyncAt: lastSyncAt,
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
        lastSyncAt: lastSyncAt,
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
        lastSyncAt: lastSyncAt,
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
        lastSyncAt: lastSyncAt,
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
        localConflictColumns: const ['cardId'],
        localToRemote: _reviewStateLocalToRemote,
        remoteToLocal: _reviewStateRemoteToLocal,
        lastSyncAt: lastSyncAt,
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
        lastSyncAt: lastSyncAt,
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
        lastSyncAt: lastSyncAt,
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
        localConflictColumns: const [
          'courseId',
          'cardId',
          'languageCode',
          'direction',
        ],
        localToRemote: _questionLocalToRemote,
        remoteToLocal: _questionRemoteToLocal,
        lastSyncAt: lastSyncAt,
      );
      pushed += questionResult.pushed;
      pulled += questionResult.pulled;
      collectError('review_sentence_questions', questionResult);

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
        lastSyncAt: lastSyncAt,
      );
      pushed += appSettingsResult.pushed;
      pulled += appSettingsResult.pulled;
      collectError('app_settings', appSettingsResult);

      if (_operation != _SyncOperation.livePush) {
        final now = DateTime.now().toIso8601String();
        await _setLocalSetting(db, 'sync.lastSyncAt', now);
      }

      await ServerLogService.write('sync.finish', details: {
        'operation': _operation.name,
        'pushed': pushed,
        'pulled': pulled,
        'errors': syncErrors.length,
      });
      return SyncResult(
        pushed: pushed,
        pulled: pulled,
        pulledCourses: courseResult.pulled,
        pulledCards: cardResult.pulled,
        logs: syncLogs,
        error: syncErrors.isEmpty ? null : syncErrors.join(' | '),
      );
    } on _SyncCancelled {
      await ServerLogService.write('sync.cancelled', details: {
        'operation': _operation.name,
      });
      return SyncResult(
        pushed: 0,
        pulled: 0,
        error: 'ÄÃ£ dừng Ä‘ồng bộ',
      );
    } catch (e) {
      _lastSyncError = e.toString();
      await ServerLogService.write('sync.error', details: {
        'operation': _operation.name,
        'error': e,
      });
      return SyncResult(pushed: 0, pulled: 0, error: e.toString());
    } finally {
      _prefetchedRemoteRows.clear();
      _isSyncing = false;
      _activeSync = null;
    }
  }

  /// Shared table worker. The active operation decides whether this pass is
  /// upload-only (session mutations) or download-only (replace/merge).
  Future<SyncResult> _syncTable({
    required Database db,
    required SupabaseClient client,
    required String ownerId,
    required String localTable,
    required String remoteTable,
    required String idColumn,
    String? remoteConflictColumns,
    List<String>? localConflictColumns,
    required Map<String, dynamic> Function(
      Map<String, Object?> localRow,
      String ownerId,
    ) localToRemote,
    required Map<String, Object?> Function(
      Map<String, dynamic> remoteRow,
    ) remoteToLocal,
    String? lastSyncAt,
    List<Map<String, dynamic>>? remoteRowsOverride,
  }) async {
    int pushed = 0;
    int pulled = 0;
    final errors = <String>[];

    try {
      _throwIfSyncCancelled();
      var remoteRows = remoteRowsOverride ?? (_operation == _SyncOperation.livePush
          ? <Map<String, dynamic>>[]
          : await _fetchAllRemoteRows(
              client: client,
              table: remoteTable,
              ownerId: ownerId,
              lastSyncAt: lastSyncAt,
            ));
      final remoteById = <String, Map<String, dynamic>>{
        for (final row in remoteRows)
          if (row[idColumn] != null) row[idColumn].toString(): row,
      };
      final remoteConflictColumnList = remoteConflictColumns
          ?.split(',')
          .map((column) => column.trim())
          .where((column) => column.isNotEmpty)
          .toList(growable: false);
      final remoteByConflict = <String, Map<String, dynamic>>{
        if (remoteConflictColumnList != null)
          for (final row in remoteRows)
            _syncConflictKey(row, remoteConflictColumnList): row,
      };

      // --- PUSH local → Supabase ---
      final Map<String, String> localTimestampColumns = {
        'topics': 'COALESCE(updatedAt, createdAt)',
        'courses': 'COALESCE(updatedAt, createdAt)',
        'cards': 'COALESCE(updatedAt, createdAt)',
        'card_examples': 'COALESCE(updatedAt, createdAt)',
        'review_states': 'COALESCE(updatedAt, createdAt)',
        'study_sessions': 'startedAt',
        'study_results': 'reviewedAt',
        'review_sentence_questions': 'COALESCE(updatedAt, createdAt)',
        'app_settings': 'updatedAt',
      };

      List<Map<String, Object?>> queriedLocalRows;
      final timeCol = localTimestampColumns[localTable];
      if (lastSyncAt != null &&
          lastSyncAt.isNotEmpty &&
          timeCol != null) {
        final parsed = DateTime.tryParse(lastSyncAt);
        if (parsed != null) {
          final safetyTime = _operation == _SyncOperation.livePush
              ? parsed.toIso8601String()
              : parsed.subtract(const Duration(minutes: 5)).toIso8601String();
          queriedLocalRows = await db.query(
            localTable,
            where: '$timeCol > ?',
            whereArgs: [safetyTime],
          );
        } else {
          queriedLocalRows = await db.query(localTable);
        }
      } else {
        queriedLocalRows = await db.query(localTable);
      }

      var localRows = localTable == 'app_settings'
          ? queriedLocalRows
              .where((row) => !_isLocalOnlySetting(row['key']))
              .toList(growable: false)
          : queriedLocalRows;
      if (_operation == _SyncOperation.livePush) {
        localRows = await _filterPushableLocalRows(db, localTable, localRows);
        // SRS is pushed only by syncReviewStatesAfterStudy(), where each
        // local card is resolved to its actual server card ID first.
        if (localTable == 'review_states') {
          localRows = const <Map<String, Object?>>[];
        }
      } else {
        localRows = const <Map<String, Object?>>[];
      }
      final toPush = <Map<String, dynamic>>[];
      for (final row in localRows) {
        try {
          final remoteData = localToRemote(row, ownerId);
          final remoteId = remoteData[idColumn]?.toString();
          final existingRemote = (remoteId == null
                  ? null
                  : remoteById[remoteId]) ??
              (remoteConflictColumnList == null
                  ? null
                  : remoteByConflict[
                      _syncConflictKey(
                        remoteData,
                        remoteConflictColumnList,
                      )
                    ]);
          if (existingRemote != null &&
              !_localRowIsNewer(remoteData, existingRemote)) {
            continue;
          }
          toPush.add(remoteData);
        } catch (e) {
          errors.add('prepare push row ${row[idColumn]}: $e');
          print('SYNC PREPARE PUSH ERROR ($localTable row ${row[idColumn]}): $e');
        }
      }

      if (toPush.isNotEmpty) {
        const chunkSize = 200;
        for (var i = 0; i < toPush.length; i += chunkSize) {
          _throwIfSyncCancelled();
          final chunk = toPush.sublist(
            i,
            math.min(i + chunkSize, toPush.length),
          );
          try {
            await client.from(remoteTable).upsert(
              chunk,
              onConflict: remoteConflictColumns ?? idColumn,
            );
            pushed += chunk.length;
          } catch (batchError) {
            print(
              'SYNC PUSH BATCH ERROR ($localTable), retrying rows: '
              '$batchError',
            );
            // PostgREST applies a batch atomically. Retry its rows separately
            // so one stale foreign key cannot block every valid session/result.
            for (final remoteData in chunk) {
              try {
                await client.from(remoteTable).upsert(
                  [remoteData],
                  onConflict: remoteConflictColumns ?? idColumn,
                );
                pushed++;
              } catch (rowError) {
                final rowId = remoteData[idColumn]?.toString() ?? '?';
                errors.add('push row $rowId: $rowError');
                print(
                  'SYNC PUSH ROW ERROR ($localTable row $rowId): $rowError',
                );
              }
            }
          }
        }
        if (pushed > 0) {
          _prefetchedRemoteRows.remove(remoteTable);
        }
      }

      if (_operation == _SyncOperation.livePush) {
        final error = errors.isEmpty ? null : errors.join(' || ');
        return SyncResult(pushed: pushed, pulled: 0, error: error);
      }

      // --- PULL Supabase → local ---
      remoteRows = remoteRowsOverride ?? await _fetchAllRemoteRows(
        client: client,
        table: remoteTable,
        ownerId: ownerId,
        lastSyncAt: lastSyncAt,
      );

      final existingTopicIds = <int>{};
      final deletedTopicIds = <int>{};
      if (localTable == 'courses') {
        final rows = await db.query('topics', columns: ['id', 'deletedAt']);
        for (final r in rows) {
          final id = r['id'] as int?;
          if (id != null) {
            existingTopicIds.add(id);
            if (r['deletedAt'] != null) deletedTopicIds.add(id);
          }
        }
      }

      final existingCardIds = <int>{};
      final deletedCardIds = <int>{};
      if (localTable == 'review_states' ||
          localTable == 'card_examples' ||
          localTable == 'review_sentence_questions' ||
          localTable == 'study_results') {
        final rows = await db.query('cards', columns: ['id', 'deletedAt']);
        for (final r in rows) {
          final id = r['id'] as int?;
          if (id != null) {
            existingCardIds.add(id);
            if (r['deletedAt'] != null) {
              deletedCardIds.add(id);
            }
          }
        }
      }

      final existingCourseIds = <int>{};
      final deletedCourseIds = <int>{};
      if (localTable == 'cards' ||
          localTable == 'study_sessions' ||
          localTable == 'review_sentence_questions') {
        final rows = await db.query('courses', columns: ['id', 'deletedAt']);
        for (final r in rows) {
          final id = r['id'] as int?;
          if (id != null) {
            existingCourseIds.add(id);
            if (r['deletedAt'] != null) {
              deletedCourseIds.add(id);
            }
          }
        }
      }

      final existingSessionIds = <int>{};
      if (localTable == 'study_results') {
        final rows = await db.query('study_sessions', columns: ['id']);
        for (final r in rows) {
          final id = r['id'] as int?;
          if (id != null) existingSessionIds.add(id);
        }
      }

      final remoteIdsToDelete = <String>[];

      // --- Build memory cache of local rows to avoid O(N) database queries ---
      final columnsToFetch = <String>{idColumn};
      if (localConflictColumns != null) {
        columnsToFetch.addAll(localConflictColumns);
      }
      final timeColName = localTable == 'study_sessions'
          ? 'startedAt'
          : (localTable == 'study_results' ? 'reviewedAt' : 'updatedAt');
      columnsToFetch.add(timeColName);

      final allLocalList = await db.query(
        localTable,
        columns: columnsToFetch.toList(),
      );

      final localById = <String, Map<String, Object?>>{
        for (final row in allLocalList)
          if (row[idColumn] != null) row[idColumn].toString(): row,
      };

      final localByConflict = <String, Map<String, Object?>>{
        if (localConflictColumns != null && localConflictColumns.isNotEmpty)
          for (final row in allLocalList)
            _syncConflictKey(row, localConflictColumns): row,
      };

      await db.transaction((txn) async {
        for (final remote in remoteRows) {
          _throwIfSyncCancelled();
          if (_operation == _SyncOperation.merge &&
              remote['deleted_at'] != null) {
            continue;
          }
          if (localTable == 'app_settings' &&
              _isLocalOnlySetting(remote['key'])) {
            continue;
          }
          try {
            final localData = remoteToLocal(remote);
            final localId = localData[idColumn];

            // Check for orphaned/deleted parent records to prevent pulling data
            // for soft-deleted/deleted cards or courses.
            if (localTable == 'courses') {
              final topicId = localData['topicId'];
              if (topicId != null &&
                  (!existingTopicIds.contains(topicId) ||
                      deletedTopicIds.contains(topicId))) {
                // Keep an active orphaned course usable instead of violating
                // SQLite's topic foreign key. It will appear as "Chủ đề khác".
                localData['topicId'] = null;
              }
            }

            if (localTable == 'cards') {
              final courseId = localData['courseId'];
              if (courseId == null ||
                  !existingCourseIds.contains(courseId) ||
                  deletedCourseIds.contains(courseId)) {
                // The server may retain active child rows after their course
                // was tombstoned. Ignore them instead of failing the snapshot.
                continue;
              }
            }

            if (localTable == 'review_states' ||
                localTable == 'card_examples' ||
                localTable == 'review_sentence_questions' ||
                localTable == 'study_results') {
              final cardId = localData['cardId'];
              if (cardId != null) {
                final isDeletedOrMissing =
                    !existingCardIds.contains(cardId) ||
                    deletedCardIds.contains(cardId);
                if (isDeletedOrMissing) {
                  await txn.delete(
                    localTable,
                    where: 'cardId = ?',
                    whereArgs: [cardId],
                  );
                  final rId = remote['id']?.toString();
                  if (rId != null) remoteIdsToDelete.add(rId);
                  continue;
                }
              }
            }

            if (localTable == 'study_sessions' ||
                localTable == 'review_sentence_questions') {
              final courseId = localData['courseId'];
              if (courseId != null) {
                final isDeletedOrMissing =
                    !existingCourseIds.contains(courseId) ||
                    deletedCourseIds.contains(courseId);
                if (isDeletedOrMissing) {
                  await txn.delete(
                    localTable,
                    where: 'courseId = ?',
                    whereArgs: [courseId],
                  );
                  final rId = remote['id']?.toString();
                  if (rId != null) remoteIdsToDelete.add(rId);
                  continue;
                }
              }
            }

            if (localTable == 'study_results') {
              final sessionId = localData['sessionId'];
              if (sessionId != null) {
                if (!existingSessionIds.contains(sessionId)) {
                  await txn.delete(
                    'study_results',
                    where: 'sessionId = ?',
                    whereArgs: [sessionId],
                  );
                  final rId = remote['id']?.toString();
                  if (rId != null) remoteIdsToDelete.add(rId);
                  continue;
                }
              }
            }

            // Find existing local row using memory maps instead of txn.query
            Map<String, Object?>? existingRow;
            final localIdStr = localId?.toString();
            if (localIdStr != null) {
              existingRow = localById[localIdStr];
            }
            if (existingRow == null &&
                localConflictColumns != null &&
                localConflictColumns.isNotEmpty) {
              existingRow = localByConflict[_syncConflictKey(localData, localConflictColumns)];
            }

            if (existingRow == null) {
              // A tombstone only matters when this device still has the row it
              // deletes. Do not import historical deleted rows as new local
              // data on every login.
              if (remote.containsKey('deleted_at') &&
                  remote['deleted_at'] != null) {
                continue;
              }
              await txn.insert(
                localTable,
                localData,
                conflictAlgorithm: ConflictAlgorithm.abort,
              );
              // Update memory cache
              if (localIdStr != null) {
                localById[localIdStr] = localData;
              }
              if (localConflictColumns != null && localConflictColumns.isNotEmpty) {
                localByConflict[_syncConflictKey(localData, localConflictColumns)] = localData;
              }
              pulled++;
            } else {
              // Compare updatedAt: remote wins if newer
              final localUpdated = existingRow[timeColName]?.toString() ?? '';
              final remoteUpdated = remote['updated_at']?.toString() ?? '';
              if (_isRemoteNewer(remoteUpdated, localUpdated)) {
                // When the natural key matches but IDs differ between devices,
                // preserve the existing SQLite ID. Replacing it would create a
                // new remote UUID on the next push and repeat the conflict.
                final mergedData = Map<String, Object?>.from(localData)
                  ..[idColumn] = existingRow[idColumn];
                await txn.update(
                  localTable,
                  mergedData,
                  where: '$idColumn = ?',
                  whereArgs: [existingRow[idColumn]],
                );
                // Update memory cache
                if (localIdStr != null) {
                  localById[localIdStr] = mergedData;
                }
                if (localConflictColumns != null && localConflictColumns.isNotEmpty) {
                  localByConflict[_syncConflictKey(mergedData, localConflictColumns)] = mergedData;
                }
                pulled++;
              }
            }
          } catch (e) {
            errors.add('pull row ${remote['id'] ?? remote['key']}: $e');
            print('SYNC PULL ERROR ($localTable): $e');
          }
        }
      });

      if (remoteIdsToDelete.isNotEmpty) {
        try {
          await client.from(remoteTable).delete().inFilter('id', remoteIdsToDelete);
          print('SYNC CLEANED UP ${remoteIdsToDelete.length} ORPHANED REMOTE ROWS FROM $remoteTable');
        } catch (e) {
          print('SYNC CLEANUP ERROR ($remoteTable): $e');
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
      'syncOrigin': 'remote',
      'hasLocalNameConflict': 0,
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
      'last_reviewed_at': _localTimestampToRemoteIso(row['lastReviewedAt']),
      'next_review_at': _localTimestampToRemoteIso(row['nextReviewAt']),
      'created_at': _localTimestampToRemoteIso(row['createdAt']),
      'updated_at': _localTimestampToRemoteIso(
        row['updatedAt'] ?? row['createdAt'],
      ),
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
      'lastReviewedAt': _remoteTimestampToLocalIso(row['last_reviewed_at']),
      'nextReviewAt': _remoteTimestampToLocalIso(row['next_review_at']),
      'createdAt': _remoteTimestampToLocalIso(row['created_at']),
      'updatedAt': _remoteTimestampToLocalIso(row['updated_at']),
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
      'updated_at': row['endedAt'] ?? row['startedAt'],
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

  static const _snapshotTables = <String>[
    'topics',
    'courses',
    'cards',
    'card_examples',
    'review_states',
    'study_sessions',
    'study_results',
    'review_sentence_questions',
    'app_settings',
  ];

  Future<void> _prefetchAccountSnapshot(
    SupabaseClient client,
    String ownerId,
  ) async {
    for (final table in _snapshotTables) {
      try {
        await _fetchAllRemoteRows(
          client: client,
          table: table,
          ownerId: ownerId,
        );
      } catch (error) {
        throw StateError('Không tải được bảng $table: $error');
      }
    }
  }

  Future<void> _clearLocalAccountData(Database db) async {
    const deletionOrder = <String>[
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
        await txn.delete(table);
      }
      final settings = await txn.query('app_settings', columns: ['key']);
      for (final row in settings) {
        final key = row['key']?.toString() ?? '';
        if (!_isLocalOnlySetting(key)) {
          await txn.delete('app_settings', where: 'key = ?', whereArgs: [key]);
        }
      }
    });
  }

  Future<void> _markLocalMergeConflicts(Database db) async {
    final remoteTitles = (_prefetchedRemoteRows['courses'] ?? const [])
        .where((row) => row['deleted_at'] == null)
        .map((row) => _normalizeIdentity(row['title']))
        .where((title) => title.isNotEmpty)
        .toSet();
    final localRows = await db.query(
      'courses',
      columns: ['id', 'title', 'syncOrigin'],
      where: 'deletedAt IS NULL',
    );
    await db.transaction((txn) async {
      for (final row in localRows) {
        final isCloud = row['syncOrigin']?.toString() == 'remote';
        final conflict = !isCloud &&
            remoteTitles.contains(_normalizeIdentity(row['title']));
        await txn.update(
          'courses',
          {
            'syncOrigin': isCloud ? 'remote' : 'local',
            'hasLocalNameConflict': conflict ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> _filterPushableLocalRows(
    Database db,
    String localTable,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty || localTable == 'topics' || localTable == 'app_settings') {
      return rows;
    }
    final conflictCourses = (await db.query(
      'courses',
      columns: ['id'],
      where: 'COALESCE(hasLocalNameConflict, 0) = 1',
    ))
        .map((row) => row['id'] as int?)
        .whereType<int>()
        .toSet();
    if (conflictCourses.isEmpty) return rows;

    final placeholders = List.filled(conflictCourses.length, '?').join(',');
    final conflictCards = (await db.query(
      'cards',
      columns: ['id'],
      where: 'courseId IN ($placeholders)',
      whereArgs: conflictCourses.toList(),
    ))
        .map((row) => row['id'] as int?)
        .whereType<int>()
        .toSet();
    final conflictSessions = (await db.query(
      'study_sessions',
      columns: ['id'],
      where: 'courseId IN ($placeholders)',
      whereArgs: conflictCourses.toList(),
    ))
        .map((row) => row['id'] as int?)
        .whereType<int>()
        .toSet();

    bool pushable(Map<String, Object?> row) {
      switch (localTable) {
        case 'courses':
          return !conflictCourses.contains(row['id']);
        case 'cards':
        case 'study_sessions':
          return !conflictCourses.contains(row['courseId']);
        case 'card_examples':
        case 'review_states':
          return !conflictCards.contains(row['cardId']);
        case 'study_results':
          return !conflictCards.contains(row['cardId']) &&
              !conflictSessions.contains(row['sessionId']);
        case 'review_sentence_questions':
          return !conflictCourses.contains(row['courseId']) &&
              !conflictCards.contains(row['cardId']);
        default:
          return true;
      }
    }

    return rows.where(pushable).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchAllRemoteRows({
    required SupabaseClient client,
    required String table,
    required String ownerId,
    String? lastSyncAt,
  }) async {
    final useIncremental = lastSyncAt != null &&
        lastSyncAt.isNotEmpty &&
        table != 'topics' &&
        table != 'courses' &&
        table != 'cards';

    final cacheKey = useIncremental ? '$table:$lastSyncAt' : table;
    if (_prefetchedRemoteRows.containsKey(cacheKey)) {
      return _prefetchedRemoteRows[cacheKey]!;
    }
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    String? filterTimestamp;
    if (useIncremental) {
      final parsed = DateTime.tryParse(lastSyncAt);
      if (parsed != null) {
        filterTimestamp = parsed
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String();
      }
    }

    while (true) {
      _throwIfSyncCancelled();
      dynamic query = client.from(table).select().eq('owner_id', ownerId);
      if (filterTimestamp != null) {
        query = query.gt('updated_at', filterTimestamp);
      }
      final response = await query
          .order(table == 'app_settings' ? 'key' : 'id')
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    _prefetchedRemoteRows[cacheKey] = rows;
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
        key == 'sync.lastSyncAt' ||
        key == 'gemini.apiKey' ||
        key.startsWith('sync.sessionStartedAt.') ||
        key.startsWith('sync.migration.') ||
        key.startsWith('sync.offlineDeleteRecovery');
  }

  String _syncConflictKey(
    Map<String, Object?> row,
    List<String> columns,
  ) {
    return columns.map((column) {
      final value = row[column]?.toString() ?? '';
      return '${value.length}:$value';
    }).join('|');
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
          final settingKey = setting['key']?.toString() ?? '';
          if (!_isLocalOnlySetting(settingKey) || settingKey == 'sync.lastSyncAt') {
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
      final preserveLocalCopy =
          (local['hasLocalNameConflict'] as int? ?? 0) == 1 ||
              (_operation == _SyncOperation.merge &&
                  local['syncOrigin']?.toString() != 'remote');
      var remote = preserveLocalCopy
          ? null
          : courseByPulledLocalId['$localId'] ??
              (local['deletedAt'] == null
                  ? activeCourseByTitle[identity] ??
                      deletedCourseByTitle[identity]
                  : deletedCourseByTitle[identity] ??
                      activeCourseByTitle[identity]);
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
    // App-generated SQLite values have no offset and represent device-local
    // time. DateTime.parse handles those as local; explicit server offsets are
    // honored, then both sides are compared as UTC instants.
    return DateTime.tryParse(text)?.toUtc();
  }

  String? _remoteTimestampToLocalIso(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed?.toLocal().toIso8601String() ?? text;
  }

  String? _localTimestampToRemoteIso(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed?.toUtc().toIso8601String() ?? text;
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

  Future<String> getRemoteCardId(int localCardId) async {
    final db = await AppDatabase.instance.database;
    await _ensureLocalDeviceId(db);
    return _uuidFromLocalId(localCardId, 'card');
  }

  Future<void> deleteRemoteReviewStatesForCards(
    Iterable<int> localCardIds,
  ) async {
    if (!SupabaseConfig.isLoggedIn) return;
    final remoteIds = <String>[];
    for (final localId in localCardIds.toSet()) {
      final remoteId = await findRemoteCardId(localId);
      if (remoteId != null && remoteId.isNotEmpty) remoteIds.add(remoteId);
    }
    if (remoteIds.isEmpty) return;
    await SupabaseConfig.client
        .from('review_states')
        .delete()
        .eq('owner_id', SupabaseConfig.currentUser!.id)
        .inFilter('card_id', remoteIds);
  }

  Future<void> deleteRemoteCourseChildren(int localCourseId) async {
    if (!SupabaseConfig.isLoggedIn) return;
    final db = await AppDatabase.instance.database;
    final cardRows = await db.query(
      'cards',
      columns: ['id'],
      where: 'courseId = ?',
      whereArgs: [localCourseId],
    );
    final remoteCardIds = <String>[];
    for (final row in cardRows) {
      final localCardId = row['id'] as int?;
      if (localCardId == null) continue;
      final remoteId = await findRemoteCardId(localCardId);
      if (remoteId != null && remoteId.isNotEmpty) remoteCardIds.add(remoteId);
    }
    final remoteCourseId = await findRemoteCourseId(localCourseId);
    final ownerId = SupabaseConfig.currentUser!.id;
    if (remoteCardIds.isNotEmpty) {
      for (final table in const [
        'study_results',
        'review_sentence_questions',
        'review_states',
        'card_examples',
      ]) {
        await SupabaseConfig.client
            .from(table)
            .delete()
            .eq('owner_id', ownerId)
            .inFilter('card_id', remoteCardIds);
      }
    }
    if (remoteCourseId != null && remoteCourseId.isNotEmpty) {
      await SupabaseConfig.client
          .from('study_sessions')
          .delete()
          .eq('owner_id', ownerId)
          .eq('course_id', remoteCourseId);
    }
  }

  Future<void> markRemoteCoursesDeleted(
    Iterable<int> localCourseIds, {
    required String deletedAt,
  }) async {
    if (!SupabaseConfig.isLoggedIn) return;

    final db = await AppDatabase.instance.database;
    final ownerId = SupabaseConfig.currentUser!.id;
    final remoteCourseIds = <String>[];
    final remoteCardIds = <String>[];
    final requestedCourseIds = localCourseIds.toSet().toList();
    if (requestedCourseIds.isEmpty) return;

    final placeholders = List.filled(requestedCourseIds.length, '?').join(',');
    final conflictCourseIds = (await db.query(
      'courses',
      columns: ['id'],
      where:
          'id IN ($placeholders) AND COALESCE(hasLocalNameConflict, 0) = 1',
      whereArgs: requestedCourseIds,
    ))
        .map((row) => row['id'] as int?)
        .whereType<int>()
        .toSet();

    for (final localCourseId in requestedCourseIds) {
      // A conflict copy was never uploaded, so a same-title server course may
      // belong to another topic and must not be touched.
      if (conflictCourseIds.contains(localCourseId)) continue;
      final remoteCourseId = await findRemoteCourseId(localCourseId);
      if (remoteCourseId != null && remoteCourseId.isNotEmpty) {
        remoteCourseIds.add(remoteCourseId);
      }
    }

    const chunkSize = 100;
    final uniqueCourseIds = remoteCourseIds.toSet().toList();
    for (var i = 0; i < uniqueCourseIds.length; i += chunkSize) {
      final chunk = uniqueCourseIds.sublist(
        i,
        math.min(i + chunkSize, uniqueCourseIds.length),
      );
      final rows = await SupabaseConfig.client
          .from('cards')
          .select('id')
          .eq('owner_id', ownerId)
          .inFilter('course_id', chunk);
      remoteCardIds.addAll(
        List<Map<String, dynamic>>.from(rows)
            .map((row) => row['id']?.toString())
            .whereType<String>(),
      );
    }

    Future<void> markDeleted(
      String table,
      List<String> remoteIds,
    ) async {
      for (var i = 0; i < remoteIds.length; i += chunkSize) {
        final chunk = remoteIds.sublist(
          i,
          math.min(i + chunkSize, remoteIds.length),
        );
        await SupabaseConfig.client
            .from(table)
            .update({'deleted_at': deletedAt, 'updated_at': deletedAt})
            .eq('owner_id', ownerId)
            .inFilter('id', chunk);
      }
    }

    // Mark children first so every server row in the deleted topic receives a
    // tombstone before its parent course is hidden.
    await markDeleted('cards', remoteCardIds.toSet().toList());
    await markDeleted('courses', remoteCourseIds.toSet().toList());
  }

  Future<void> deleteRemoteCardChildren(int localCardId) async {
    if (!SupabaseConfig.isLoggedIn) return;
    final db = await AppDatabase.instance.database;
    final conflict = await db.rawQuery(
      '''
      SELECT COALESCE(c.hasLocalNameConflict, 0) AS isConflict
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      WHERE ca.id = ?
      LIMIT 1
      ''',
      [localCardId],
    );
    if (conflict.isNotEmpty && conflict.first['isConflict'] == 1) return;
    final remoteCardId = await findRemoteCardId(localCardId);
    if (remoteCardId == null || remoteCardId.isEmpty) return;
    final ownerId = SupabaseConfig.currentUser!.id;
    for (final table in const [
      'study_results',
      'review_sentence_questions',
      'review_states',
      'card_examples',
    ]) {
      await SupabaseConfig.client
          .from(table)
          .delete()
          .eq('owner_id', ownerId)
          .eq('card_id', remoteCardId);
    }
  }

  Future<String?> findRemoteCardId(int localCardId) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'cards',
        where: 'id = ?',
        whereArgs: [localCardId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final card = rows.first;
      final term = card['term']?.toString() ?? '';
      final definition = card['definition']?.toString() ?? '';
      final position = card['position'] ?? 0;
      final localCourseId = _localInt(card['courseId']);

      final ownerId = SupabaseConfig.currentUser?.id;
      if (ownerId == null) return null;
      final remoteCourseId = localCourseId == null
          ? null
          : await findRemoteCourseId(localCourseId);

      dynamic query = SupabaseConfig.client
          .from('cards')
          .select('id')
          .eq('owner_id', ownerId)
          .eq('term', term)
          .eq('definition', definition)
          .eq('position', position);
      if (remoteCourseId != null) {
        query = query.eq('course_id', remoteCourseId);
      }
      final response = await query.limit(1);

      if (response.isNotEmpty) {
        return response.first['id']?.toString();
      }
    } catch (e) {
      print('findRemoteCardId error: $e');
    }
    return getRemoteCardId(localCardId);
  }

  Future<String> getRemoteCourseId(int localCourseId) async {
    final db = await AppDatabase.instance.database;
    await _ensureLocalDeviceId(db);
    return _uuidFromLocalId(localCourseId, 'course');
  }

  Future<String?> findRemoteCourseId(int localCourseId) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'courses',
        where: 'id = ?',
        whereArgs: [localCourseId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final course = rows.first;
      final title = course['title']?.toString() ?? '';

      final ownerId = SupabaseConfig.currentUser?.id;
      if (ownerId == null) return null;

      final response = await SupabaseConfig.client
          .from('courses')
          .select('id')
          .eq('owner_id', ownerId)
          .eq('title', title)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['id']?.toString();
      }
    } catch (e) {
      print('findRemoteCourseId error: $e');
    }
    return getRemoteCourseId(localCourseId);
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
  final List<String> logs;

  SyncResult({
    required this.pushed,
    required this.pulled,
    this.pulledCourses = 0,
    this.pulledCards = 0,
    this.error,
    this.logs = const [],
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
