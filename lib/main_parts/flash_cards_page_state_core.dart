part of flutterflashcard_main;

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

    this.loadInitialData();
  }

  @override
  void dispose() {
    this._finishStudySession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildFlashCardsPagePage(context);
  }
}
