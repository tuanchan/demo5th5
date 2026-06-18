part of flutterflashcard_main;

const int _hardCardWrongThreshold = 5;

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<StatisticsData> _future;
  final Set<int> _expandedCourseIds = {};

  @override
  void initState() {
    super.initState();
    _future = this.loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildStatisticsPagePage(context);
  }
}
