part of flutterflashcard_main;

extension HomePageSelectionPart on _HomePageState {
  int get _homeSelectedItemCount =>
      _selectedHomeTopicIds.length + _selectedHomeCourseIds.length;

  void _startHomeTopicSelection(CourseTopicItem topic) {
    HapticFeedback.mediumImpact();
    setState(() {
      _homeSelectionMode = true;
      _selectedHomeCourseIds.clear();
      _selectedHomeTopicIds.add(topic.id);
    });
  }

  void _startHomeCourseSelection(CourseListItem course) {
    HapticFeedback.mediumImpact();
    setState(() {
      _homeSelectionMode = true;
      _selectedHomeTopicIds.clear();
      _selectedHomeCourseIds.add(course.id);
      selectedHomeCourse = null;
    });
  }

  void _toggleHomeTopicSelection(CourseTopicItem topic) {
    setState(() {
      if (!_selectedHomeTopicIds.add(topic.id)) {
        _selectedHomeTopicIds.remove(topic.id);
      }
      if (_selectedHomeTopicIds.isEmpty) _homeSelectionMode = false;
    });
  }

  void _toggleHomeCourseSelection(CourseListItem course) {
    setState(() {
      if (!_selectedHomeCourseIds.add(course.id)) {
        _selectedHomeCourseIds.remove(course.id);
      }
      if (_selectedHomeCourseIds.isEmpty) _homeSelectionMode = false;
    });
  }

  void _finishHomeSelection() {
    setState(() {
      _homeSelectionMode = false;
      _selectedHomeTopicIds.clear();
      _selectedHomeCourseIds.clear();
    });
  }

  Widget _buildHomeSelectionCircle(bool selected) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 140),
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Color(0xff1684ff) : Colors.transparent,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: selected
          ? Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : null,
    );
  }

  Widget _buildHomeSelectionBar(bool compact) {
    final count = _homeSelectedItemCount;
    final canEdit = count == 1 && !_homeSelectionBusy;
    return Container(
      key: ValueKey('home-selection-bar'),
      height: 84,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
      decoration: BoxDecoration(
        color: Color(0xff05070b),
        border: Border(bottom: BorderSide(color: Color(0xff26324a))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 70 : 130,
            child: Text(
              '$count mục',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                this._homeSelectionAction(
                  asset: 'assets/icon/share-solid-full.svg',
                  tooltip: 'Chia sẻ',
                  onPressed: count > 0 && !_homeSelectionBusy
                      ? this._showHomeShareOptions
                      : null,
                ),
                SizedBox(width: compact ? 8 : 16),
                this._homeSelectionAction(
                  asset: 'assets/icon/pen-to-square-solid-full.svg',
                  tooltip: canEdit ? 'Sửa' : 'Chỉ sửa được một mục mỗi lần',
                  onPressed: canEdit ? this._editHomeSelection : null,
                ),
                SizedBox(width: compact ? 8 : 16),
                this._homeSelectionAction(
                  asset: 'assets/icon/trash-can-solid-full.svg',
                  tooltip: 'Xóa',
                  color: Color(0xffff6666),
                  onPressed: count > 0 && !_homeSelectionBusy
                      ? this._deleteHomeSelection
                      : null,
                ),
              ],
            ),
          ),
          SizedBox(
            width: compact ? 70 : 130,
            child: TextButton(
              onPressed: _homeSelectionBusy ? null : this._finishHomeSelection,
              child: Text(
                'Xong',
                style: TextStyle(
                  color: Color(0xff4595ff),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeSelectionAction({
    required String asset,
    required String tooltip,
    required VoidCallback? onPressed,
    Color color = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: Size(42, 42),
          shape: CircleBorder(
            side: BorderSide(
              color: onPressed == null
                  ? Color(0xff303846)
                  : Colors.white.withOpacity(0.75),
            ),
          ),
        ),
        icon: SvgPicture.asset(
          asset,
          width: 19,
          height: 19,
          colorFilter: ColorFilter.mode(
            onPressed == null ? Color(0xff525a68) : color,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Future<void> _editHomeSelection() async {
    if (_homeSelectedItemCount != 1) {
      this.showHomeMessage('Chỉ có thể sửa một mục mỗi lần');
      return;
    }
    if (_selectedHomeTopicIds.isNotEmpty) {
      final id = _selectedHomeTopicIds.first;
      final matches = topics.where((item) => item.id == id);
      if (matches.isEmpty) return;
      final item = matches.first;
      this._finishHomeSelection();
      await this.openEditTopicDialog(item);
      return;
    }
    final id = _selectedHomeCourseIds.first;
    final matches = courses.where((item) => item.id == id);
    if (matches.isEmpty) return;
    final item = matches.first;
    this._finishHomeSelection();
    await this.openEditCourseDialog(item);
  }

  Future<void> _showHomeShareOptions() async {
    if (_homeSelectedItemCount == 0) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.64),
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xff17191f),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xff343943)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chia sẻ $_homeSelectedItemCount mục',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Color(0xff343943)),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: _homeShareOptionIcon(Icons.people_alt_rounded),
                  title: Text(
                    'Chia sẻ với bạn bè',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Chọn người dùng trong FlashCard',
                    style: TextStyle(color: Color(0xff9ca3af)),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    this._showHomeUserPicker();
                  },
                ),
                Divider(height: 1, indent: 72, color: Color(0xff343943)),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: _homeShareOptionIcon(Icons.ios_share_rounded),
                  title: Text(
                    'Chia sẻ file',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _selectedHomeTopicIds.isNotEmpty
                        ? 'Xuất chủ đề thành file ZIP'
                        : 'Xuất học phần thành file TXT',
                    style: TextStyle(color: Color(0xff9ca3af)),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    this._shareHomeSelectionAsFiles();
                  },
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _homeShareOptionIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Color(0xff237cf4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Future<void> _showHomeUserPicker() async {
    if (!SupabaseConfig.isLoggedIn) {
      this.showHomeMessage('Vui lòng đăng nhập để chia sẻ với bạn bè');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Color(0xff101217),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _HomeUserShareSheet(
        onSend: this._sendHomeSelectionToUsers,
      ),
    );
  }

  Future<void> _sendHomeSelectionToUsers(
    List<_HomeShareUser> recipients,
  ) async {
    if (recipients.isEmpty) return;
    final senderId = SupabaseConfig.currentUser?.id;
    if (senderId == null) throw StateError('Phiên đăng nhập đã hết hạn');

    final payload = await this._buildHomeSelectionPayload();
    final itemType = _selectedHomeTopicIds.isNotEmpty ? 'topic' : 'course';
    final selectedNames = itemType == 'topic'
        ? topics
            .where((item) => _selectedHomeTopicIds.contains(item.id))
            .map((item) => item.name)
            .toList()
        : courses
            .where((item) => _selectedHomeCourseIds.contains(item.id))
            .map((item) => item.title)
            .toList();
    final title = selectedNames.length == 1
        ? selectedNames.first
        : '${selectedNames.length} mục FlashCard';
    final now = DateTime.now().toUtc().toIso8601String();

    await SupabaseConfig.client.from('course_shares').insert(
      recipients
          .map(
            (recipient) => {
              'sender_id': senderId,
              'recipient_id': recipient.id,
              'item_type': itemType,
              'title': title,
              'payload': payload,
              'created_at': now,
            },
          )
          .toList(),
    );

    if (!mounted) return;
    this.showHomeMessage('Đã gửi cho ${recipients.length} người dùng');
    this._finishHomeSelection();
  }

  Future<Map<String, dynamic>> _buildHomeSelectionPayload() async {
    final db = await AppDatabase.instance.database;
    final selectedTopicIds = _selectedHomeTopicIds.toList();
    final selectedCourseIds = _selectedHomeCourseIds.toList();
    final payloadTopics = <Map<String, dynamic>>[];
    final payloadCourses = <Map<String, dynamic>>[];

    if (selectedTopicIds.isNotEmpty) {
      for (final topic in topics.where(
        (item) => selectedTopicIds.contains(item.id),
      )) {
        final topicCourses = courses
            .where((course) => course.topicId == topic.id)
            .toList();
        final packed = <Map<String, dynamic>>[];
        for (final course in topicCourses) {
          packed.add(await this._packHomeCourse(db, course));
        }
        payloadTopics.add({'name': topic.name, 'courses': packed});
      }
    } else {
      for (final course in courses.where(
        (item) => selectedCourseIds.contains(item.id),
      )) {
        payloadCourses.add(await this._packHomeCourse(db, course));
      }
    }

    return {
      'version': 1,
      'sharedAt': DateTime.now().toUtc().toIso8601String(),
      'topics': payloadTopics,
      'courses': payloadCourses,
    };
  }

  Future<Map<String, dynamic>> _packHomeCourse(
    Database db,
    CourseListItem course,
  ) async {
    final courseRows = await db.query(
      'courses',
      columns: ['description', 'languageName'],
      where: 'id = ?',
      whereArgs: [course.id],
      limit: 1,
    );
    final rows = await db.query(
      'cards',
      columns: [
        'id',
        'term',
        'definition',
        'pronunciation',
        'rawText',
        'inputFormat',
        'extraMeaning',
        'note',
        'position',
        'isFavorite',
      ],
      where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
      whereArgs: [course.id],
      orderBy: 'position ASC, id ASC',
    );
    final packedCards = <Map<String, dynamic>>[];
    for (final row in rows) {
      final cardId = row['id'] as int?;
      final examples = cardId == null
          ? const <Map<String, Object?>>[]
          : await db.query(
              'card_examples',
              columns: ['exampleText', 'pronunciation', 'meaning'],
              where: 'cardId = ?',
              whereArgs: [cardId],
              orderBy: 'id ASC',
            );
      final packed = Map<String, dynamic>.from(row)..remove('id');
      packed['examples'] = examples
          .map((example) => Map<String, Object?>.from(example))
          .toList();
      packedCards.add(packed);
    }
    final courseRow = courseRows.isEmpty ? const <String, Object?>{} : courseRows.first;
    return {
      'title': course.title,
      'topicName': course.topicName,
      'languageCode': course.languageCode,
      'languageName': courseRow['languageName']?.toString(),
      'description': courseRow['description']?.toString(),
      'cards': packedCards,
    };
  }

  Future<void> _shareHomeSelectionAsFiles() async {
    if (_homeSelectionBusy) return;
    setState(() => _homeSelectionBusy = true);
    try {
      final db = await AppDatabase.instance.database;
      final temp = await getTemporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final exportDir = Directory(p.join(temp.path, 'flashcard_share_$stamp'));
      await exportDir.create(recursive: true);
      final files = <XFile>[];

      if (_selectedHomeTopicIds.isNotEmpty) {
        for (final topic in topics.where(
          (item) => _selectedHomeTopicIds.contains(item.id),
        )) {
          final archive = Archive();
          final topicCourses = courses.where(
            (course) => course.topicId == topic.id,
          );
          for (final course in topicCourses) {
            final content = await this._homeCourseTxtContent(db, course.id);
            final bytes = utf8.encode(content);
            archive.addFile(
              ArchiveFile(
                '${this._safeHomeFileName(course.title)}.txt',
                bytes.length,
                bytes,
              ),
            );
          }
          final encoded = ZipEncoder().encode(archive);
          if (encoded == null) throw StateError('Không thể tạo file ZIP');
          final zip = File(
            p.join(exportDir.path, '${this._safeHomeFileName(topic.name)}.zip'),
          );
          await zip.writeAsBytes(encoded, flush: true);
          files.add(XFile(zip.path, mimeType: 'application/zip'));
        }
      } else {
        for (final course in courses.where(
          (item) => _selectedHomeCourseIds.contains(item.id),
        )) {
          final file = File(
            p.join(exportDir.path, '${this._safeHomeFileName(course.title)}.txt'),
          );
          await file.writeAsString(
            await this._homeCourseTxtContent(db, course.id),
            encoding: utf8,
            flush: true,
          );
          files.add(XFile(file.path, mimeType: 'text/plain'));
        }
      }

      if (files.isEmpty) throw StateError('Không có dữ liệu để chia sẻ');
      if (!mounted) return;
      final renderBox = context.findRenderObject();
      final origin = renderBox is RenderBox
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : Rect.fromLTWH(0, 0, 1, 1);
      await Share.shareXFiles(
        files,
        subject: 'Học phần FlashCard',
        text: 'Dữ liệu học phần được chia sẻ từ FlashCard.',
        sharePositionOrigin: origin,
      );
    } catch (error, stackTrace) {
      debugPrint('SHARE HOME FILE ERROR: $error\n$stackTrace');
      if (mounted) this.showHomeMessage('Chia sẻ file thất bại: $error');
    } finally {
      if (mounted) setState(() => _homeSelectionBusy = false);
    }
  }

  Future<String> _homeCourseTxtContent(Database db, int courseId) async {
    final rows = await db.query(
      'cards',
      columns: ['term', 'pronunciation', 'definition'],
      where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
      whereArgs: [courseId],
      orderBy: 'position ASC, id ASC',
    );
    String clean(Object? value) => (value?.toString() ?? '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    return rows
        .map(
          (row) => '${clean(row['term'])}\t${clean(row['pronunciation'])}\t${clean(row['definition'])}',
        )
        .join('\n');
  }

  String _safeHomeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? 'flashcard' : cleaned;
  }

  Future<void> _deleteHomeSelection() async {
    final topicIds = _selectedHomeTopicIds.toList();
    final courseIds = _selectedHomeCourseIds.toList();
    if (topicIds.isEmpty && courseIds.isEmpty) return;
    final label = topicIds.isNotEmpty ? 'chủ đề' : 'học phần';
    final count = topicIds.isNotEmpty ? topicIds.length : courseIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Color(0xff151820),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Xóa $count $label?', style: TextStyle(color: Colors.white)),
        content: Text(
          topicIds.isNotEmpty
              ? 'Tất cả học phần, thẻ và tiến độ bên trong các chủ đề đã chọn cũng sẽ bị xóa. Thao tác này không thể hoàn tác.'
              : 'Các học phần và toàn bộ thẻ đã chọn sẽ bị xóa. Thao tác này không thể hoàn tác.',
          style: TextStyle(color: Color(0xffcbd5e1), height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xffef4444),
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.delete_outline_rounded),
            label: Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _homeSelectionBusy = true);
    try {
      final db = await AppDatabase.instance.database;
      final syncDeletion = SupabaseConfig.isLoggedIn;
      final now = DateTime.now().toIso8601String();
      final targetCourseIds = courseIds.toSet();
      if (topicIds.isNotEmpty) {
        final placeholders = List.filled(topicIds.length, '?').join(',');
        final rows = await db.query(
          'courses',
          columns: ['id'],
          where: 'topicId IN ($placeholders) AND deletedAt IS NULL',
          whereArgs: topicIds,
        );
        targetCourseIds.addAll(
          rows.map((row) => row['id'] as int?).whereType<int>(),
        );
      }

      for (final id in targetCourseIds) {
        try {
          await TtsAudioCache.instance.deleteCourseAudioCache(courseId: id);
        } catch (error) {
          debugPrint('BULK DELETE AUDIO CACHE ERROR ($id): $error');
        }
      }

      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();

      await db.transaction((txn) async {
        if (targetCourseIds.isNotEmpty) {
          final ids = targetCourseIds.toList();
          final placeholders = List.filled(ids.length, '?').join(',');
          final courseWhere = 'courseId IN ($placeholders)';
          final cardWhere = 'cardId IN (SELECT id FROM cards WHERE $courseWhere)';
          await txn.delete(
            'study_results',
            where:
                'sessionId IN (SELECT id FROM study_sessions WHERE $courseWhere) OR $cardWhere',
            whereArgs: [...ids, ...ids],
          );
          if (tableNames.contains('review_sentence_questions')) {
            await txn.delete(
              'review_sentence_questions',
              where: courseWhere,
              whereArgs: ids,
            );
          }
          await txn.delete('study_sessions', where: courseWhere, whereArgs: ids);
          await txn.delete('review_states', where: cardWhere, whereArgs: ids);
          await txn.delete('card_examples', where: cardWhere, whereArgs: ids);
          await txn.delete(
            'course_tags',
            where: 'courseId IN ($placeholders)',
            whereArgs: ids,
          );
          await txn.delete(
            'import_exports',
            where: 'courseId IN ($placeholders)',
            whereArgs: ids,
          );
          if (syncDeletion) {
            await txn.update(
              'cards',
              {'deletedAt': now, 'updatedAt': now},
              where: courseWhere,
              whereArgs: ids,
            );
            await txn.update(
              'courses',
              {'deletedAt': now, 'updatedAt': now, 'cardCount': 0},
              where: 'id IN ($placeholders)',
              whereArgs: ids,
            );
          } else {
            await txn.delete('cards', where: courseWhere, whereArgs: ids);
            await txn.delete(
              'courses',
              where: 'id IN ($placeholders)',
              whereArgs: ids,
            );
          }
        }
        if (topicIds.isNotEmpty) {
          final placeholders = List.filled(topicIds.length, '?').join(',');
          if (syncDeletion) {
            await txn.update(
              'topics',
              {'deletedAt': now, 'updatedAt': now},
              where: 'id IN ($placeholders)',
              whereArgs: topicIds,
            );
          } else {
            await txn.delete(
              'topics',
              where: 'id IN ($placeholders)',
              whereArgs: topicIds,
            );
          }
        }
      });

      expandedTopicIds.removeAll(topicIds);
      if (!mounted) return;
      this._finishHomeSelection();
      await this.loadCourses(showLoading: false);
      this.showHomeMessage('Đã xóa $count $label');
      if (syncDeletion) {
        unawaited(
          SupabaseSyncService.instance
              .markRemoteCoursesDeleted(targetCourseIds, deletedAt: now)
              .then((_) => SupabaseSyncService.instance.syncPendingChanges())
              .then((result) {
            if (result.hasError) {
              debugPrint('BULK DELETE SYNC ERROR: ${result.error}');
            }
          })
              .catchError((error, stackTrace) {
            debugPrint('BULK DELETE SYNC ERROR: $error\n$stackTrace');
          }),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('BULK DELETE ERROR: $error\n$stackTrace');
      if (mounted) this.showHomeMessage('Xóa thất bại: $error');
    } finally {
      if (mounted) setState(() => _homeSelectionBusy = false);
    }
  }
}

class _HomeShareUser {
  const _HomeShareUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  factory _HomeShareUser.fromMap(Map<String, dynamic> map) {
    final email = map['email']?.toString().trim() ?? '';
    final displayName = map['display_name']?.toString().trim() ?? '';
    return _HomeShareUser(
      id: map['id']?.toString() ?? '',
      name: displayName.isEmpty ? (email.isEmpty ? 'Người dùng FlashCard' : email) : displayName,
      email: email,
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}

class _HomeUserShareSheet extends StatefulWidget {
  const _HomeUserShareSheet({required this.onSend});

  final Future<void> Function(List<_HomeShareUser> users) onSend;

  @override
  State<_HomeUserShareSheet> createState() => _HomeUserShareSheetState();
}

class _HomeUserShareSheetState extends State<_HomeUserShareSheet> {
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, _HomeShareUser> _selected = {};
  List<_HomeShareUser> _users = const [];
  Timer? _debounce;
  int _page = 0;
  int _requestSerial = 0;
  bool _loading = true;
  bool _hasNext = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 320), () {
      _page = 0;
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    final serial = ++_requestSerial;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final currentUserId = SupabaseConfig.currentUser?.id;
      final keyword = _searchController.text
          .trim()
          .replaceAll(RegExp(r'[,()]'), ' ');
      dynamic query = SupabaseConfig.client
          .from('profiles')
          .select('id, display_name, email, avatar_url');
      if (currentUserId != null) query = query.neq('id', currentUserId);
      if (keyword.isNotEmpty) {
        query = query.or(
          'display_name.ilike.%$keyword%,email.ilike.%$keyword%',
        );
      }
      final start = _page * _pageSize;
      final response = await query
          .order('display_name', ascending: true)
          .range(start, start + _pageSize);
      if (!mounted || serial != _requestSerial) return;
      final rows = List<Map<String, dynamic>>.from(response as List);
      setState(() {
        _hasNext = rows.length > _pageSize;
        _users = rows
            .take(_pageSize)
            .map(_HomeShareUser.fromMap)
            .where((user) => user.id.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được danh sách người dùng. Hãy cập nhật Supabase schema rồi thử lại.\n$error';
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      await widget.onSend(_selected.values.toList());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() { _sending = false; _error = 'Gửi thất bại: $error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
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
            padding: EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chia sẻ với bạn bè',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc email',
                hintStyle: TextStyle(color: Color(0xff767e8d)),
                prefixIcon: Icon(Icons.search_rounded, color: Color(0xff8d96a6)),
                filled: true,
                fillColor: Color(0xff20232a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(_error!, style: TextStyle(color: Color(0xffff7777), fontSize: 12)),
            ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xff3983ff)))
                : _users.isEmpty
                    ? Center(
                        child: Text('Không tìm thấy người dùng', style: TextStyle(color: Color(0xff9ca3af))),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: Color(0xff292d35)),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final selected = _selected.containsKey(user.id);
                          return ListTile(
                            onTap: () => setState(() {
                              if (selected) {
                                _selected.remove(user.id);
                              } else {
                                _selected[user.id] = user;
                              }
                            }),
                            leading: CircleAvatar(
                              backgroundColor: Color(0xff2b3444),
                              backgroundImage: user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null || user.avatarUrl!.trim().isEmpty
                                  ? Text(user.name.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))
                                  : null,
                            ),
                            title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            subtitle: user.email.isEmpty
                                ? null
                                : Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xff9ca3af))),
                            trailing: Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? Color(0xff1684ff) : Colors.transparent,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: selected ? Icon(Icons.check_rounded, color: Colors.white, size: 17) : null,
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Trang trước',
                  onPressed: _page > 0 && !_loading ? () { setState(() => _page--); _loadUsers(); } : null,
                  icon: Icon(Icons.chevron_left_rounded),
                  color: Colors.white,
                ),
                Text('Trang ${_page + 1}', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                IconButton(
                  tooltip: 'Trang sau',
                  onPressed: _hasNext && !_loading ? () { setState(() => _page++); _loadUsers(); } : null,
                  icon: Icon(Icons.chevron_right_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selected.isEmpty || _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff1677ed),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _sending
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send_rounded, size: 19),
                  label: Text(
                    _selected.isEmpty ? 'Chọn người nhận' : 'Gửi (${_selected.length})',
                    style: TextStyle(fontWeight: FontWeight.w900),
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
