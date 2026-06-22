part of flutterflashcard_main;

class _ReviewPracticePageState extends State<ReviewPracticePage> {
  final Map<int, GlobalKey> _questionKeys = {};

  List<StudyCardItem> _cards = [];
  List<StudyCardItem> _quizCards = [];
  Map<int, List<String>> _choiceMap = {};
  Set<int> _answeredCards = {};
  Map<int, bool> _correctMap = {};
  Map<int, String> _selectedAnswerMap = {};
  Map<int, String> _geminiTextFeedbackMap = {};
  List<_MatchPairTile> _matchPairTiles = [];
  int? _selectedMatchPairTileId;
  final Set<int> _matchedPairCardIds = {};
  final Set<int> _wrongMatchPairTileIds = {};
  final Set<int> _correctMatchPairTileIds = {};

  bool _isLoading = true;
  bool _isGeneratingSentenceQuiz = false;
  bool _isGeminiTextGrading = false;
  bool _showSetup = true;
  bool _multipleChoice = true;
  bool _essay = false;
  bool _listening = false;
  bool _matchingPairs = false;
  bool _sentenceMode = false;
  bool _answerByDefinition = true;
  bool _finished = false;
  int _questionLimit = 0;
  int _currentEssayIndex = 0;
  int? _studySessionId;
  String? _selectedListeningAnswer;
  bool _isPlayingListeningAudio = false;
  bool _studySessionFinished = true;
  DateTime? _sessionStartedAt;
  DateTime _essayQuestionStartedAt = DateTime.now();
  final Set<int> _recordedResultCardIds = {};
  final Map<int, DateTime> _cardStartedAtMap = {};

  int get _total => _quizCards.length;
  int get _done => _answeredCards.length;
  int get _correct => _correctMap.values.where((e) => e).length;
  int get _wrong => _done - _correct;
  int get _displayTotal => _isGeneratingSentenceQuiz
      ? (_questionLimit <= 0
            ? _cards.length
            : _questionLimit.clamp(1, _cards.length).toInt())
      : (_total == 0 ? _cards.length : _total);
  bool get _usesGeminiTextGrading =>
      _essay && !_multipleChoice && !_listening;

  String _geminiTextResultScript = '';

  final TextEditingController _essayController = TextEditingController();
  final math.Random _random = math.Random();
  final ScrollController _mcScrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    this._loadCards();
  }

  @override
  void dispose() {
    this._finishStudySession();
    _essayController.dispose();
    _mcScrollController.dispose();
    super.dispose();
  }

  List<StudyCardItem> get _wrongReviewCards {
    return _quizCards.where((card) => _correctMap[card.id] != true).toList();
  }

  void _setupMatchingTilesForPage(int pageIndex) {
    final startIndex = pageIndex * 5;
    final endIndex = math.min(startIndex + 5, _quizCards.length);
    final pageCards = _quizCards.sublist(startIndex, endIndex);

    final termTiles = <_MatchPairTile>[];
    final answerTiles = <_MatchPairTile>[];

    for (var i = 0; i < pageCards.length; i++) {
      final card = pageCards[i];
      termTiles.add(
        _MatchPairTile(
          tileId: i * 2,
          cardId: card.id,
          text: card.term,
          subText: card.pronunciation,
          isTerm: true,
        ),
      );
      answerTiles.add(
        _MatchPairTile(
          tileId: i * 2 + 1,
          cardId: card.id,
          text: card.definition,
          subText: '',
          isTerm: false,
        ),
      );
    }

    termTiles.shuffle(_random);
    answerTiles.shuffle(_random);

    _matchPairTiles = [];
    _matchPairTiles.addAll(termTiles);
    _matchPairTiles.addAll(answerTiles);

    _selectedMatchPairTileId = null;
    _wrongMatchPairTileIds.clear();
    _correctMatchPairTileIds.clear();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildReviewPracticePagePage(context);
  }
}
