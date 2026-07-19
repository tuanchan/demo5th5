part of flutterflashcard_main;

final Uri _geminiApiKeyUri = Uri.parse(
  'https://aistudio.google.com/api-keys?hl=vi&project=gen-lang-client-0159401860',
);

class _SettingsPageState extends State<SettingsPage> {
  String themeMode = 'light';
  bool showGeminiApiKey = false;
  String geminiKeyMessage = '';
  bool accountSyncing = false;
  bool? accountSyncSucceeded;
  String accountSyncMessage = '';
  List<String> accountSyncLogs = const [];
  String serverLogPath = '';
  bool serverLogLoading = false;
  
  final List<String> geminiModels = const [
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-lite-latest',
  ];
  String selectedGeminiModel = 'gemini-flash-lite-latest';

  final Map<String, String> colorNames = {
    'bg': 'Nền app',
    'panel': 'Nền card',
    'panel2': 'Nền phụ',
    'border': 'Viền / chữ đậm',
    'text': 'Chữ chính',
    'muted': 'Chữ phụ',
    'yellow': 'Nút tạo học phần',
    'green': 'Nút ôn tập / đúng',
    'red': 'Nút Flash Card / sai',
    'blue': 'Nút thống kê / phụ',
  };

  final List<Color> presets = [
    Color(0xffeef1f4),
    Color(0xffffffff),
    Color(0xff183153),
    Color(0xff1f3b63),
    Color(0xff6d7890),
    Color(0xfff5c400),
    Color(0xff8ee88b),
    Color(0xffff9f9f),
    Color(0xffa1a7fb),
    Color(0xff111827),
    Color(0xff1f2937),
    Color(0xff78e08f),
    Color(0xffffb020),
    Color(0xff38bdf8),
    Color(0xfff472b6),
  ];

  final TextEditingController geminiApiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    this.loadSettings();
    this._resumeAccountSyncStatus();
    if (ServerLogService.isAvailable) this._loadServerLogPath();
  }

  @override
  void dispose() {
    geminiApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildSettingsPagePage(context);
  }
}
