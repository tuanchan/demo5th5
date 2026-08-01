part of flutterflashcard_main;

extension HomePageInboxPart on _HomePageState {
  Widget _buildHomeNotificationButton() {
    final count = _homeIncomingShareCount;
    return Tooltip(
      message: 'Thông báo',
      child: Semantics(
        button: true,
        label: count > 0 ? 'Thông báo, $count mục đang chờ' : 'Thông báo',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
              TextButton(
                onPressed: _homeIncomingShareCountLoading
                    ? null
                    : this._openHomeShareInbox,
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xff9ab9ff),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  minimumSize: Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                child: Text('Thông báo'),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -7,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(0xffe63950),
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xff05070b), width: 1.4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w900,
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

  void _restartHomeShareRealtime() {
    this._stopHomeShareRealtime();
    if (!mounted) return;
    final user = SupabaseConfig.currentUser;
    if (user == null) {
      if (mounted && _homeIncomingShareCount != 0) {
        setState(() => _homeIncomingShareCount = 0);
      }
      return;
    }

    unawaited(this._loadHomeIncomingShareCount());
    final channel = SupabaseConfig.client
        .channel('home-shares:${user.id}:${++_homeShareRealtimeSerial}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'course_shares',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user.id,
          ),
          callback: (_) {
            unawaited(this._loadHomeIncomingShareCount());
          },
        );
    _homeShareRealtimeChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('HOME SHARE REALTIME ERROR: $error');
      }
    });
  }

  void _stopHomeShareRealtime() {
    final channel = _homeShareRealtimeChannel;
    _homeShareRealtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseConfig.client.removeChannel(channel));
    }
  }

  Future<void> _loadHomeIncomingShareCount() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null || _homeIncomingShareCountLoading) return;
    _homeIncomingShareCountLoading = true;
    try {
      final rows = await SupabaseConfig.client
          .from('course_shares')
          .select('id')
          .eq('recipient_id', userId)
          .eq('status', 'pending');
      if (!mounted) return;
      setState(() => _homeIncomingShareCount = (rows as List).length);
    } catch (error) {
      debugPrint('LOAD HOME SHARE COUNT ERROR: $error');
    } finally {
      _homeIncomingShareCountLoading = false;
    }
  }

  Future<List<_HomeIncomingShare>> _loadHomeIncomingShares() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return const [];
    final response = await SupabaseConfig.client
        .from('course_shares')
        .select(
          'id, sender_id, item_type, title, payload, status, created_at, opened_at',
        )
        .eq('recipient_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(100);
    final rows = List<Map<String, dynamic>>.from(response as List);
    final senderIds = rows
        .map((row) => row['sender_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final profiles = <String, Map<String, dynamic>>{};
    if (senderIds.isNotEmpty) {
      final profileRows = await SupabaseConfig.client
          .from('profiles')
          .select('id, display_name, email, avatar_url')
          .inFilter('id', senderIds);
      for (final row in List<Map<String, dynamic>>.from(profileRows as List)) {
        final id = row['id']?.toString();
        if (id != null) profiles[id] = row;
      }
    }
    return rows
        .map(
          (row) => _HomeIncomingShare.fromMap(
            row,
            profiles[row['sender_id']?.toString()],
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> _openHomeShareInbox() async {
    if (!SupabaseConfig.isLoggedIn) {
      this.showHomeMessage('Vui lòng đăng nhập để xem thông báo');
      return;
    }
    unawaited(this._markHomeSharesOpened());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Color(0xff101217),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _HomeShareInboxSheet(
        loadShares: this._loadHomeIncomingShares,
        onAccept: this._acceptHomeIncomingShare,
        onDecline: this._declineHomeIncomingShare,
      ),
    );
    if (mounted) await this._loadHomeIncomingShareCount();
  }

  Future<void> _markHomeSharesOpened() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('course_shares')
          .update({'opened_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', userId)
          .eq('status', 'pending')
          .isFilter('opened_at', null);
    } catch (error) {
      debugPrint('MARK HOME SHARES OPENED ERROR: $error');
    }
  }

  Future<void> _declineHomeIncomingShare(_HomeIncomingShare share) async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) throw StateError('Phiên đăng nhập đã hết hạn');
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseConfig.client
        .from('course_shares')
        .update({'status': 'declined', 'opened_at': now, 'responded_at': now})
        .eq('id', share.id)
        .eq('recipient_id', userId)
        .eq('status', 'pending');
    await this._loadHomeIncomingShareCount();
    if (mounted) this.showHomeMessage('Đã từ chối mục được chia sẻ');
  }

  Future<void> _acceptHomeIncomingShare(_HomeIncomingShare share) async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) throw StateError('Phiên đăng nhập đã hết hạn');
    final result = await this._importHomeIncomingShare(share);
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseConfig.client
        .from('course_shares')
        .update({'status': 'accepted', 'opened_at': now, 'responded_at': now})
        .eq('id', share.id)
        .eq('recipient_id', userId)
        .eq('status', 'pending');

    if (!mounted) return;
    await this.loadCourses(showLoading: false);
    await this._loadHomeIncomingShareCount();
    this.showHomeMessage(
      result.alreadyImported
          ? 'Mục này đã có trong thư viện'
          : 'Đã nhận ${result.courseCount} học phần · ${result.cardCount} thẻ',
    );
    if (SupabaseConfig.isLoggedIn && !result.alreadyImported) {
      unawaited(
        SupabaseSyncService.instance.syncPendingChanges().then((syncResult) {
          if (syncResult.hasError) {
            debugPrint('RECEIVED SHARE SYNC ERROR: ${syncResult.error}');
          }
        }).catchError((error, stackTrace) {
          debugPrint('RECEIVED SHARE SYNC ERROR: $error\n$stackTrace');
        }),
      );
    }
  }

  Future<_HomeShareImportResult> _importHomeIncomingShare(
    _HomeIncomingShare share,
  ) async {
    final db = await AppDatabase.instance.database;
    await AppDatabase.instance.ensureTopicSchema();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS received_share_imports (
        shareId TEXT PRIMARY KEY,
        importedAt TEXT NOT NULL
      )
    ''');
    final payload = share.payload;
    final topicEntries = _homeMapList(payload['topics']);
    final standaloneCourses = _homeMapList(payload['courses']);
    if (topicEntries.isEmpty && standaloneCourses.isEmpty) {
      throw StateError('Dữ liệu được chia sẻ không hợp lệ hoặc đang trống');
    }

    return db.transaction<_HomeShareImportResult>((txn) async {
      final imported = await txn.query(
        'received_share_imports',
        columns: ['shareId'],
        where: 'shareId = ?',
        whereArgs: [share.id],
        limit: 1,
      );
      if (imported.isNotEmpty) {
        return const _HomeShareImportResult(alreadyImported: true);
      }

      final now = DateTime.now().toIso8601String();
      final topicIdsBySourceName = <String, int>{};
      var topicCount = 0;
      var courseCount = 0;
      var cardCount = 0;

      Future<int> createReceivedTopic(String rawName) async {
        final sourceName = rawName.trim().isEmpty ? 'Được chia sẻ' : rawName.trim();
        final cacheKey = sourceName.toLowerCase();
        final cached = topicIdsBySourceName[cacheKey];
        if (cached != null) return cached;
        final uniqueName = await this._uniqueHomeReceivedName(
          txn,
          table: 'topics',
          column: 'name',
          baseName: sourceName,
        );
        final id = await txn.insert('topics', {
          'name': uniqueName,
          'createdAt': now,
          'updatedAt': now,
        });
        topicIdsBySourceName[cacheKey] = id;
        topicCount++;
        return id;
      }

      Future<void> insertCourse(
        Map<String, dynamic> rawCourse,
        int topicId,
      ) async {
        final rawTitle = rawCourse['title']?.toString().trim() ?? '';
        final title = await this._uniqueHomeReceivedName(
          txn,
          table: 'courses',
          column: 'title',
          baseName: rawTitle.isEmpty ? 'Học phần được chia sẻ' : rawTitle,
        );
        final languageCode =
            rawCourse['languageCode']?.toString().trim().isNotEmpty == true
                ? rawCourse['languageCode'].toString().trim()
                : 'en-US';
        final cards = _homeMapList(rawCourse['cards']);
        final courseId = await txn.insert('courses', {
          'topicId': topicId,
          'title': title,
          'description': rawCourse['description']?.toString() ?? '',
          'languageName':
              rawCourse['languageName']?.toString().trim().isNotEmpty == true
                  ? rawCourse['languageName'].toString().trim()
                  : this.languageNameFromCode(languageCode),
          'languageCode': languageCode,
          'cardCount': cards.length,
          'isFavorite': 0,
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
          'syncOrigin': 'local',
          'hasLocalNameConflict': 0,
        });
        for (var index = 0; index < cards.length; index++) {
          final card = cards[index];
          final term = card['term']?.toString().trim() ?? '';
          final definition = card['definition']?.toString().trim() ?? '';
          final pronunciation = card['pronunciation']?.toString().trim() ?? '';
          final cardId = await txn.insert('cards', {
            'courseId': courseId,
            'term': term.isEmpty ? 'Chưa có thuật ngữ' : term,
            'definition': definition.isEmpty ? 'Chưa có định nghĩa' : definition,
            'pronunciation': pronunciation,
            'rawText': card['rawText']?.toString() ??
                '$term\t$pronunciation\t$definition',
            'inputFormat': card['inputFormat']?.toString() ?? 'shared',
            'extraMeaning': card['extraMeaning']?.toString(),
            'note': card['note']?.toString(),
            'position': _dbInt(card['position']) == 0
                ? index
                : _dbInt(card['position']),
            'isFavorite': _dbInt(card['isFavorite']),
            'isHidden': 0,
            'createdAt': now,
            'updatedAt': now,
          });
          for (final example in _homeMapList(card['examples'])) {
            final exampleText = example['exampleText']?.toString().trim() ?? '';
            if (exampleText.isEmpty) continue;
            await txn.insert('card_examples', {
              'cardId': cardId,
              'exampleText': exampleText,
              'pronunciation': example['pronunciation']?.toString(),
              'meaning': example['meaning']?.toString(),
              'createdAt': now,
              'updatedAt': now,
            });
          }
        }
        courseCount++;
        cardCount += cards.length;
      }

      for (final topic in topicEntries) {
        final topicId = await createReceivedTopic(
          topic['name']?.toString() ?? 'Được chia sẻ',
        );
        for (final course in _homeMapList(topic['courses'])) {
          await insertCourse(course, topicId);
        }
      }
      for (final course in standaloneCourses) {
        final topicId = await createReceivedTopic(
          course['topicName']?.toString() ?? 'Được chia sẻ',
        );
        await insertCourse(course, topicId);
      }

      await txn.insert('received_share_imports', {
        'shareId': share.id,
        'importedAt': now,
      });
      return _HomeShareImportResult(
        topicCount: topicCount,
        courseCount: courseCount,
        cardCount: cardCount,
      );
    });
  }

  Future<String> _uniqueHomeReceivedName(
    DatabaseExecutor db, {
    required String table,
    required String column,
    required String baseName,
  }) async {
    final normalized = baseName.trim();
    final safeBase = normalized.isEmpty ? 'Được chia sẻ' : normalized;
    var candidate = safeBase;
    var suffix = 1;
    while (true) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'lower(trim($column)) = ? AND deletedAt IS NULL',
        whereArgs: [candidate.toLowerCase()],
        limit: 1,
      );
      if (rows.isEmpty) return candidate;
      final tail = suffix == 1 ? ' (được chia sẻ)' : ' (được chia sẻ $suffix)';
      final maxBaseLength = math.max(1, 80 - tail.length).toInt();
      final cutAt = math.min(safeBase.length, maxBaseLength).toInt();
      candidate = '${safeBase.substring(0, cutAt)}$tail';
      suffix++;
    }
  }
}

List<Map<String, dynamic>> _homeMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class _HomeShareImportResult {
  const _HomeShareImportResult({
    this.topicCount = 0,
    this.courseCount = 0,
    this.cardCount = 0,
    this.alreadyImported = false,
  });

  final int topicCount;
  final int courseCount;
  final int cardCount;
  final bool alreadyImported;
}

class _HomeIncomingShare {
  const _HomeIncomingShare({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.itemType,
    required this.title,
    required this.payload,
    required this.createdAt,
    this.senderAvatarUrl,
    this.openedAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String? senderAvatarUrl;
  final String itemType;
  final String title;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? openedAt;

  int get courseCount {
    if (itemType == 'course') return _homeMapList(payload['courses']).length;
    return _homeMapList(payload['topics']).fold<int>(
      0,
      (sum, topic) => sum + _homeMapList(topic['courses']).length,
    );
  }

  int get cardCount {
    Iterable<Map<String, dynamic>> allCourses() sync* {
      yield* _homeMapList(payload['courses']);
      for (final topic in _homeMapList(payload['topics'])) {
        yield* _homeMapList(topic['courses']);
      }
    }
    return allCourses().fold<int>(
      0,
      (sum, course) => sum + _homeMapList(course['cards']).length,
    );
  }

  factory _HomeIncomingShare.fromMap(
    Map<String, dynamic> row,
    Map<String, dynamic>? profile,
  ) {
    final senderEmail = profile?['email']?.toString().trim() ?? '';
    final displayName = profile?['display_name']?.toString().trim() ?? '';
    final rawPayload = row['payload'];
    Map<String, dynamic> payload = const {};
    if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String) {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    }
    return _HomeIncomingShare(
      id: row['id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      senderName: displayName.isNotEmpty
          ? displayName
          : (senderEmail.isNotEmpty ? senderEmail : 'Người dùng FlashCard'),
      senderEmail: senderEmail,
      senderAvatarUrl: profile?['avatar_url']?.toString(),
      itemType: row['item_type']?.toString() ?? 'course',
      title: row['title']?.toString() ?? 'Mục được chia sẻ',
      payload: payload,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      openedAt: DateTime.tryParse(row['opened_at']?.toString() ?? ''),
    );
  }
}

class _HomeShareInboxSheet extends StatefulWidget {
  const _HomeShareInboxSheet({
    required this.loadShares,
    required this.onAccept,
    required this.onDecline,
  });

  final Future<List<_HomeIncomingShare>> Function() loadShares;
  final Future<void> Function(_HomeIncomingShare share) onAccept;
  final Future<void> Function(_HomeIncomingShare share) onDecline;

  @override
  State<_HomeShareInboxSheet> createState() => _HomeShareInboxSheetState();
}

class _HomeShareInboxSheetState extends State<_HomeShareInboxSheet> {
  List<_HomeIncomingShare> _shares = const [];
  bool _loading = true;
  String? _busyShareId;
  String? _busyAction;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shares = await widget.loadShares();
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được thông báo: $error';
      });
    }
  }

  Future<void> _handle(
    _HomeIncomingShare share,
    Future<void> Function(_HomeIncomingShare share) action,
    String actionName,
  ) async {
    setState(() {
      _busyShareId = share.id;
      _busyAction = actionName;
      _error = null;
    });
    try {
      await action(share);
      if (!mounted) return;
      setState(() {
        _shares = _shares.where((item) => item.id != share.id).toList();
        _busyShareId = null;
        _busyAction = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyShareId = null;
        _busyAction = null;
        _error = 'Xử lý thất bại: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.84,
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xff4b5260),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0x252f80ff),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_rounded, color: Color(0xff4595ff)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông báo',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${_shares.length} mục được chia sẻ đang chờ',
                        style: TextStyle(color: Color(0xff9ca3af), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busyShareId == null ? () => Navigator.pop(context) : null,
                  icon: Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Color(0xff292d35)),
          if (_error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(_error!, style: TextStyle(color: Color(0xffff7777), fontSize: 12)),
            ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xff3983ff)))
                : _shares.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, color: Color(0xff596273), size: 46),
                            SizedBox(height: 10),
                            Text('Không có mục nào đang chờ', style: TextStyle(color: Color(0xff9ca3af))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: EdgeInsets.all(14),
                          itemCount: _shares.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildShareCard(_shares[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCard(_HomeIncomingShare share) {
    final busy = _busyShareId == share.id;
    final accepting = busy && _busyAction == 'accept';
    final declining = busy && _busyAction == 'decline';
    final disabled = _busyShareId != null;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xff191c23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xff303540)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xff2b3444),
                backgroundImage: share.senderAvatarUrl != null && share.senderAvatarUrl!.trim().isNotEmpty
                    ? NetworkImage(share.senderAvatarUrl!)
                    : null,
                child: share.senderAvatarUrl == null || share.senderAvatarUrl!.trim().isEmpty
                    ? Text(share.senderName.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))
                    : null,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(share.senderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    if (share.senderEmail.isNotEmpty)
                      Text(share.senderEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xff939baa), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0x252f80ff),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  share.itemType == 'topic' ? 'CHỦ ĐỀ' : 'HỌC PHẦN',
                  style: TextStyle(color: Color(0xff71a7ff), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(share.title, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text(
            '${share.courseCount} học phần · ${share.cardCount} thẻ · ${_homeInboxTime(share.createdAt)}',
            style: TextStyle(color: Color(0xff9ca3af), fontSize: 12),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: disabled ? null : () => _confirmDecline(share),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xffff7474),
                    side: BorderSide(color: Color(0xff67353b)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    declining ? 'Đang xử lý...' : 'Từ chối',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled
                      ? null
                      : () => _handle(share, widget.onAccept, 'accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff247bf0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: accepting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.download_done_rounded, size: 18),
                  label: Text(accepting ? 'Đang nhận...' : 'Nhận', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDecline(_HomeIncomingShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Color(0xff191c23),
        title: Text('Từ chối mục được chia sẻ?', style: TextStyle(color: Colors.white)),
        content: Text('“${share.title}” sẽ được xóa khỏi danh sách đang chờ.', style: TextStyle(color: Color(0xffc7ccd5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Từ chối', style: TextStyle(color: Color(0xffff6b6b))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _handle(share, widget.onDecline, 'decline');
    }
  }
}

String _homeInboxTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final difference = now.difference(local);
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
  if (difference.inDays < 1) return '${difference.inHours} giờ trước';
  if (difference.inDays < 7) return '${difference.inDays} ngày trước';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
