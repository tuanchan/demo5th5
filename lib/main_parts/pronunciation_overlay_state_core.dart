part of flutterflashcard_main;

class _PronunciationOverlayState extends State<PronunciationOverlay> with SingleTickerProviderStateMixin {
  bool _isAvailable = false;
  bool _isRecording = false;
  bool _hasResult = false;
  bool _listenStarted = false;

  String _statusText = 'Nhấn nút để bắt đầu';
  List<_WordResult> _wordResults = [];
  double _score = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    this._initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildPronunciationOverlayPage(context);
  }
}
