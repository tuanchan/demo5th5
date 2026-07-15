part of flutterflashcard_main;

const int _hardCardWrongThreshold = 5;

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<StatisticsData> _future;
  late Future<List<_SrsEditorItem>> _srsManagerFuture;
  late final StreamSubscription<SyncResult> _statisticsSyncSubscription;
  late final StreamSubscription<void> _statisticsRealtimeSubscription;
  final Set<int> _expandedCourseIds = {};
  final TextEditingController _srsSearchController = TextEditingController();
  final Map<int, int> _courseSrsLevelDraft = {};
  final Map<int, DateTime> _courseSrsDateDraft = {};
  bool _srsOnlyDueToday = true;

  List<Map<String, Object?>> _extractSrsImportItems(Object? decoded) {
    final source = decoded is Map ? decoded['items'] : decoded;
    if (source is! List) return [];

    return source
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  Future<int?> _findSrsImportCardId(
    DatabaseExecutor executor,
    Map<String, Object?> item,
  ) async {
    final term = item['term']?.toString().trim() ?? '';
    final definition = item['definition']?.toString().trim() ?? '';
    final courseTitle = item['courseTitle']?.toString().trim() ?? '';
    final languageCode = item['languageCode']?.toString().trim() ?? '';

    Future<int?> firstId(String sql, List<Object?> args) async {
      final rows = await executor.rawQuery(sql, args);
      if (rows.isEmpty) return null;
      final id = _dbInt(rows.first['id']);
      return id > 0 ? id : null;
    }

    if (term.isNotEmpty && definition.isNotEmpty && courseTitle.isNotEmpty) {
      final id = await firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
          AND lower(trim(c.title)) = lower(trim(?))
          AND (? = '' OR c.languageCode = ?)
          AND lower(trim(ca.term)) = lower(trim(?))
          AND lower(trim(ca.definition)) = lower(trim(?))
        LIMIT 1
        ''',
        [courseTitle, languageCode, languageCode, term, definition],
      );
      if (id != null) return id;
    }

    if (term.isNotEmpty && definition.isNotEmpty) {
      final id = await firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
          AND (? = '' OR c.languageCode = ?)
          AND lower(trim(ca.term)) = lower(trim(?))
          AND lower(trim(ca.definition)) = lower(trim(?))
        ORDER BY c.updatedAt DESC, c.createdAt DESC, ca.id ASC
        LIMIT 1
        ''',
        [languageCode, languageCode, term, definition],
      );
      if (id != null) return id;
    }

    final staleCardId = _dbInt(item['cardId']);
    if (staleCardId > 0) {
      return firstId(
        '''
        SELECT ca.id
        FROM cards ca
        INNER JOIN courses c ON c.id = ca.courseId
        WHERE ca.id = ?
          AND ca.deletedAt IS NULL
          AND ca.isHidden = 0
          AND c.deletedAt IS NULL
        LIMIT 1
        ''',
        [staleCardId],
      );
    }

    return null;
  }

  String _formatSrsDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return 'chưa có ngày';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _srsStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  @override
  void initState() {
    super.initState();
    _future = this.loadStatistics();
    _srsManagerFuture = this._loadSrsEditorItems();
    _statisticsSyncSubscription = SupabaseSyncService.instance.syncCompleted
        .listen((result) {
          if (mounted && result.pulled > 0) this.reloadStatistics();
        });
    _statisticsRealtimeSubscription =
        SupabaseSyncService.instance.remoteDataChanged.listen((_) {
          if (mounted) this.reloadStatistics();
        });
  }

  @override
  void dispose() {
    _statisticsSyncSubscription.cancel();
    _statisticsRealtimeSubscription.cancel();
    _srsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildStatisticsPagePage(context);
  }
}
