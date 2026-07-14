part of flutterflashcard_main;

class _FlashCardsPageState extends State<FlashCardsPage> {
  List<CourseListItem> courseList = [];
  List<StudyCardItem> allCards = [];
  List<int> visibleOrder = [];

  int? selectedCourseId;
  int currentPos = 0;
  String _languageCode = 'zh-TW';

  bool isLoading = true;
  bool courseDropdownOpen = false;
  bool progressTracking = false;
  bool shuffleEnabled = false;
  bool starredOnly = false;
  bool autoPlayAudio = false;
  bool isFlipped = false;
  bool showCompletion = false;
  bool flashcardTableVisible = false;
  bool tableDefinitionVisible = true;
  int selectedVocabRow = -1;

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

  List<Map<String, String>> _parseGeminiExamples(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final examples = <Map<String, String>>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final exampleMatch = RegExp(
        r'^Ví dụ\s*\d*\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (exampleMatch == null) continue;

      final example = exampleMatch.group(1)?.trim() ?? '';
      var meaning = '';
      var note = '';
      for (var detailIndex = i + 1;
          detailIndex < lines.length;
          detailIndex++) {
        final detail = lines[detailIndex];
        if (RegExp(r'^Ví dụ\s*\d*\s*:', caseSensitive: false)
            .hasMatch(detail)) {
          break;
        }
        final meaningMatch = RegExp(
          r'^Dịch\s*\d*\s*:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(detail);
        final noteMatch = RegExp(
          r'^(?:Ghi chú|Lưu ý)\s*\d*\s*:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(detail);
        if (meaningMatch != null) {
          meaning = meaningMatch.group(1)?.trim() ?? '';
        } else if (noteMatch != null) {
          note = noteMatch.group(1)?.trim() ?? '';
        }
      }

      if (example.isNotEmpty) {
        examples.add({
          'exampleText': example,
          'meaning': meaning,
          'note': note,
        });
      }
    }

    if (examples.isEmpty && text.trim().isNotEmpty) {
      examples.add({
        'exampleText': text.trim(),
        'meaning': '',
        'note': '',
      });
    }

    return examples;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    Future.delayed(Duration(milliseconds: 350), () {
      if (mounted) {
        this.loadInitialData();
      }
    });
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
