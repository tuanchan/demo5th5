part of flutterflashcard_main;

class _WritingScript {
  final String title;
  final String topic;
  final String vietnameseText;
  final String targetText;
  final String targetLanguageName;
  final String targetLanguageCode;
  final String difficulty;
  final List<String> usedVocabulary;
  final String contextNote;

  const _WritingScript({
    required this.title,
    required this.topic,
    required this.vietnameseText,
    required this.targetText,
    required this.targetLanguageName,
    required this.targetLanguageCode,
    required this.difficulty,
    required this.usedVocabulary,
    required this.contextNote,
  });

  factory _WritingScript.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value
              .map((item) {
                if (item is Map) {
                  final term = item['term']?.toString().trim() ?? '';
                  final meaning =
                      item['meaning']?.toString().trim() ??
                      item['definition']?.toString().trim() ??
                      '';
                  return meaning.isEmpty ? term : '$term - $meaning';
                }
                return item.toString().trim();
              })
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    return _WritingScript(
      title: json['title']?.toString().trim() ?? '',
      topic: json['topic']?.toString().trim() ?? '',
      vietnameseText: json['vietnameseText']?.toString().trim() ?? '',
      targetText: json['targetText']?.toString().trim() ?? '',
      targetLanguageName:
          json['targetLanguageName']?.toString().trim() ?? '',
      targetLanguageCode:
          json['targetLanguageCode']?.toString().trim() ?? '',
      difficulty: json['difficulty']?.toString().trim() ?? '',
      usedVocabulary: strings(json['usedVocabulary']),
      contextNote: json['contextNote']?.toString().trim() ?? '',
    );
  }
}

class _WritingIssue {
  final String wrongText;
  final String correction;
  final String explanation;
  final String type;

  const _WritingIssue({
    required this.wrongText,
    required this.correction,
    required this.explanation,
    required this.type,
  });

  factory _WritingIssue.fromJson(Map<String, dynamic> json) => _WritingIssue(
    wrongText: json['wrongText']?.toString().trim() ?? '',
    correction: json['correction']?.toString().trim() ?? '',
    explanation: json['explanation']?.toString().trim() ?? '',
    type: json['type']?.toString().trim() ?? '',
  );
}

class _WritingGrade {
  final int score;
  final String overallFeedback;
  final String suggestedRewrite;
  final List<_WritingIssue> issues;

  const _WritingGrade({
    required this.score,
    required this.overallFeedback,
    required this.suggestedRewrite,
    required this.issues,
  });

  factory _WritingGrade.fromJson(Map<String, dynamic> json) {
    final rawIssues = json['issues'];
    return _WritingGrade(
      score: _dbInt(json['score']).clamp(0, 100).toInt(),
      overallFeedback: json['overallFeedback']?.toString().trim() ?? '',
      suggestedRewrite: json['suggestedRewrite']?.toString().trim() ?? '',
      issues: rawIssues is List
          ? rawIssues
                .whereType<Map>()
                .map(
                  (item) => _WritingIssue.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <_WritingIssue>[],
    );
  }
}

class _WritingClozeItem {
  final int start;
  final int end;
  final String answer;
  final TextEditingController controller = TextEditingController();

  _WritingClozeItem({
    required this.start,
    required this.end,
    required this.answer,
  });

  void dispose() => controller.dispose();
}

class WritingPracticePage extends StatefulWidget {
  final int? initialCourseId;

  const WritingPracticePage({super.key, this.initialCourseId});

  @override
  State<WritingPracticePage> createState() => _WritingPracticePageState();
}

class _WritingPracticePageState extends State<WritingPracticePage> {
  static const _bg = Color(0xff000000);
  static const _surface = Color(0xff0b0c10);
  static const _surface2 = Color(0xff111318);
  static const _border = Color(0xff242832);
  static const _muted = Color(0xff9aa4b8);
  static const _blue = Color(0xff4257ff);

  final _topicController = TextEditingController();
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();

  List<CourseListItem> _courses = [];
  int? _selectedCourseId;
  String _sourceMode = 'course';
  String _practiceMode = 'translate';
  String _difficulty = 'basic';
  String _tense = 'Present Simple';
  String? _busyPhase;
  String _error = '';
  _WritingScript? _script;
  _WritingGrade? _grade;
  Map<String, List<String>>? _hints;
  final List<_WritingClozeItem> _clozeItems = [];

  bool get _busy => _busyPhase != null;
  CourseListItem? get _selectedCourse {
    for (final course in _courses) {
      if (course.id == _selectedCourseId) return course;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
    _loadCourses();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _answerController.dispose();
    _scrollController.dispose();
    _disposeClozeItems();
    super.dispose();
  }

  void _disposeClozeItems() {
    for (final item in _clozeItems) {
      item.dispose();
    }
    _clozeItems.clear();
  }

  Future<void> _loadCourses() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery('''
        SELECT c.id, c.topicId, COALESCE(t.name, '') AS topicName,
          c.title, c.languageCode, COUNT(cards.id) AS cardCount
        FROM courses c
        LEFT JOIN topics t ON t.id = c.topicId AND t.deletedAt IS NULL
        LEFT JOIN cards ON cards.courseId = c.id
          AND cards.deletedAt IS NULL AND cards.isHidden = 0
        WHERE c.deletedAt IS NULL
        GROUP BY c.id, c.topicId, t.name, c.title, c.languageCode
        ORDER BY COALESCE(c.updatedAt, c.createdAt) DESC
      ''');
      if (!mounted) return;
      final loaded = rows.map(CourseListItem.fromMap).toList();
      final selectedExists = loaded.any(
        (course) => course.id == _selectedCourseId,
      );
      setState(() {
        _courses = loaded;
        if (!selectedExists) {
          _selectedCourseId = loaded.isEmpty ? null : loaded.first.id;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Không tải được học phần: $error');
    }
  }

  Future<List<StudyCardItem>> _loadVocabulary() async {
    final courseId = _selectedCourseId;
    if (courseId == null) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cards',
      where: 'courseId = ? AND deletedAt IS NULL AND isHidden = 0',
      whereArgs: [courseId],
      orderBy: 'position ASC, id ASC',
    );
    final cards = rows.map(StudyCardItem.fromMap).toList()..shuffle();
    return cards.take(90).toList();
  }

  String _languageName(String code) {
    final normalized = code.toLowerCase();
    if (normalized.startsWith('zh')) return 'Tiếng Trung';
    if (normalized.startsWith('ja')) return 'Tiếng Nhật';
    if (normalized.startsWith('ko')) return 'Tiếng Hàn';
    if (normalized.startsWith('fr')) return 'Tiếng Pháp';
    if (normalized.startsWith('de')) return 'Tiếng Đức';
    if (normalized.startsWith('es')) return 'Tiếng Tây Ban Nha';
    if (normalized.startsWith('vi')) return 'Tiếng Việt';
    return 'Tiếng Anh';
  }

  ({String label, int sentences, String instruction})
  get _difficultyInfo {
    switch (_difficulty) {
      case 'hard':
        return (
          label: 'Khó',
          sentences: 6,
          instruction:
              'câu tự nhiên, ý liên kết, cụm từ hữu ích và cấu trúc trung cấp',
        );
      case 'advanced':
        return (
          label: 'Nâng cao',
          sentences: 8,
          instruction:
              'đoạn dài hơn, cấu trúc phong phú nhưng vẫn tự nhiên',
        );
      default:
        return (
          label: 'Cơ bản',
          sentences: 4,
          instruction: 'câu ngắn, cấu trúc quen thuộc, phù hợp người mới',
        );
    }
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    value = value.replaceFirst(RegExp(r'\s*```$'), '');
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start >= 0 && end > start) value = value.substring(start, end + 1);
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw FormatException('Gemini không trả về JSON hợp lệ');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _generate() async {
    if (_busy) return;
    final course = _selectedCourse;
    if ((_sourceMode == 'course' || _sourceMode == 'tense') &&
        course == null) {
      _showMessage('Hãy chọn học phần trước');
      return;
    }
    if (_sourceMode == 'topic' && _topicController.text.trim().isEmpty) {
      _showMessage('Hãy nhập chủ đề trước');
      return;
    }

    setState(() {
      _busyPhase = 'generate';
      _error = '';
      _grade = null;
      _hints = null;
    });
    try {
      final cards = await _loadVocabulary();
      final info = _difficultyInfo;
      final languageCode = course?.languageCode.trim().isNotEmpty == true
          ? course!.languageCode.trim()
          : 'en-US';
      final languageName = _languageName(languageCode);
      final topic = _sourceMode == 'topic'
          ? _topicController.text.trim()
          : (course?.title ?? 'giao tiếp đời thường');
      final vocabulary = cards
          .map(
            (card) => {
              'term': card.term.trim(),
              'meaning': card.definition.trim(),
              'pronunciation': card.pronunciation.trim(),
            },
          )
          .toList();
      final tenseRule = _sourceMode == 'tense'
          ? 'Tất cả câu trong targetText phải dùng đúng thì $_tense.'
          : '';
      final prompt = '''
Bạn là giáo viên ngoại ngữ tạo bài luyện viết có hướng dẫn cho người Việt.
Chỉ trả về đúng một JSON hợp lệ, không markdown, không chú thích.

Học phần: ${course?.title ?? 'Theo chủ đề'}
Ngôn ngữ đích: $languageName ($languageCode)
Chủ đề/ngữ cảnh: $topic
Số câu tiếng Việt: khoảng ${info.sentences}
Độ khó: ${info.label} — ${info.instruction}
$tenseRule

Từ vựng học phần JSON:
${jsonEncode(vocabulary)}

Yêu cầu:
- Tạo đoạn tiếng Việt tự nhiên, thực tế và targetText cùng ý bằng đúng ngôn ngữ đích.
- Dùng khoảng ${math.min(cards.length, math.max(3, info.sentences))} đến ${math.min(cards.length, info.sentences + 3)} từ/cụm trong danh sách nếu có, không nhồi từ.
- Nội dung hữu ích cho giao tiếp, công việc, học tập hoặc đời sống; tránh văn phong AI.
- Nếu là zh-TW phải dùng chữ phồn thể.
- usedVocabulary chỉ ghi từ thực sự đã dùng; contextNote viết ngắn bằng tiếng Việt.

Schema:
{"title":"tiêu đề ngắn","topic":"chủ đề","difficulty":"${info.label}","vietnameseText":"đoạn tiếng Việt","targetText":"đoạn ngôn ngữ đích","targetLanguageName":"$languageName","targetLanguageCode":"$languageCode","usedVocabulary":["từ đã dùng"],"contextNote":"ghi chú ngắn"}
''';
      final raw = await GeminiFlashLiteClient.generateText(
        prompt,
        maxOutputTokens: 1800,
        responseMimeType: 'application/json',
      );
      final generated = _WritingScript.fromJson(_decodeJsonObject(raw));
      if (generated.vietnameseText.isEmpty || generated.targetText.isEmpty) {
        throw FormatException('Gemini chưa tạo đủ hai đoạn văn');
      }
      if (!mounted) return;
      setState(() {
        _script = generated;
        _answerController.clear();
        _buildClozeItems();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPhase = null);
    }
  }

  Future<void> _requestHint() async {
    final script = _script;
    if (_busy || script == null) return;
    if (_practiceMode == 'cloze') {
      setState(() {
        _hints = {
          'Từ vựng đã dùng': script.usedVocabulary.isEmpty
              ? ['Bài này chưa có danh sách từ gợi ý.']
              : script.usedVocabulary,
        };
      });
      return;
    }
    setState(() {
      _busyPhase = 'hint';
      _error = '';
    });
    try {
      final prompt = '''
Bạn là trợ lý gợi ý luyện viết. Chỉ trả về JSON, không đưa đáp án hoàn chỉnh.
Bài tập: ${jsonEncode({'vietnameseText': script.vietnameseText, 'topic': script.topic, 'difficulty': script.difficulty, 'targetLanguageName': script.targetLanguageName, 'targetLanguageCode': script.targetLanguageCode, 'usedVocabulary': script.usedVocabulary})}
Mỗi gợi ý ngắn dưới 18 từ, viết bằng tiếng Việt. Không dịch toàn bộ đoạn.
Schema: {"keyIdeas":["ý chính"],"wordHints":["từ/cụm từ"],"structureHints":["cấu trúc"]}
''';
      final raw = await GeminiFlashLiteClient.generateText(
        prompt,
        maxOutputTokens: 700,
        responseMimeType: 'application/json',
      );
      final json = _decodeJsonObject(raw);
      List<String> list(String key) => json[key] is List
          ? (json[key] as List)
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : <String>[];
      if (!mounted) return;
      setState(() {
        _hints = {
          'Ý chính nên bám': list('keyIdeas'),
          'Cách dùng từ': list('wordHints'),
          'Cấu trúc gợi ý': list('structureHints'),
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyPhase = null);
    }
  }

  String? _submissionText() {
    if (_practiceMode != 'cloze') return _answerController.text.trim();
    final script = _script;
    if (script == null) return null;
    if (_clozeItems.any((item) => item.controller.text.trim().isEmpty)) {
      return null;
    }
    var value = script.targetText;
    for (final item in _clozeItems.reversed) {
      value = value.replaceRange(
        item.start,
        item.end,
        item.controller.text.trim(),
      );
    }
    _answerController.text = value;
    return value;
  }

  Future<void> _gradeWriting() async {
    final script = _script;
    if (_busy || script == null) return;
    final userText = _submissionText();
    if (userText == null || userText.trim().isEmpty) {
      _showMessage(
        _practiceMode == 'cloze'
            ? 'Điền hết các ô bị khuyết trước khi chấm'
            : 'Nhập bài viết trước khi chấm',
      );
      return;
    }
    setState(() {
      _busyPhase = 'grade';
      _error = '';
    });
    try {
      final payload = {
        'vietnameseText': script.vietnameseText,
        'expectedText': script.targetText,
        'userText': userText,
        'targetLanguageName': script.targetLanguageName,
        'targetLanguageCode': script.targetLanguageCode,
        'topic': script.topic,
      };
      final prompt = '''
Bạn là giáo viên chấm bài viết ngoại ngữ nghiêm túc nhưng hữu ích.
Chỉ trả về một JSON hợp lệ. Chấm ý nghĩa, ngữ pháp, từ vựng, độ đầy đủ và tự nhiên.
Bài nộp JSON: ${jsonEncode(payload)}
Không bắt buộc giống expectedText từng chữ nếu bài tự nhiên và giữ đủ ý.
overallFeedback và explanation viết bằng tiếng Việt. score là số nguyên 0-100.
wrongText ưu tiên là chuỗi con chính xác trong userText. type chỉ là grammar, meaning, wording, missing hoặc style.
Schema: {"score":82,"overallFeedback":"nhận xét","suggestedRewrite":"bản viết hoàn chỉnh","issues":[{"wrongText":"đoạn sai","correction":"sửa thành","explanation":"giải thích","type":"grammar"}]}
''';
      final raw = await GeminiFlashLiteClient.generateText(
        prompt,
        maxOutputTokens: 1600,
        responseMimeType: 'application/json',
      );
      final result = _WritingGrade.fromJson(_decodeJsonObject(raw));
      if (!mounted) return;
      setState(() => _grade = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyPhase = null);
    }
  }

  void _buildClozeItems() {
    _disposeClozeItems();
    final text = _script?.targetText ?? '';
    if (text.isEmpty) return;
    final matches = RegExp(
      r"[A-Za-zÀ-ỹ\u00C0-\u024F\u3400-\u9FFF]+(?:['’-][A-Za-zÀ-ỹ\u00C0-\u024F\u3400-\u9FFF]+)*",
      unicode: true,
    ).allMatches(text).toList();
    final stopWords = {
      'the', 'and', 'that', 'with', 'from', 'this', 'have', 'were', 'been',
      'they', 'their', 'there', 'then', 'than', 'into', 'when', 'what',
    };
    final candidates = <({RegExpMatch match, int wordIndex})>[];
    for (var i = 0; i < matches.length; i++) {
      final word = matches[i].group(0) ?? '';
      if (word.length >= 4 && !stopWords.contains(word.toLowerCase())) {
        candidates.add((match: matches[i], wordIndex: i));
      }
    }
    if (candidates.isEmpty) {
      for (var i = 0; i < matches.length; i++) {
        if ((matches[i].group(0) ?? '').length >= 2) {
          candidates.add((match: matches[i], wordIndex: i));
        }
      }
    }
    candidates.sort(
      (a, b) => (b.match.group(0)?.length ?? 0).compareTo(
        a.match.group(0)?.length ?? 0,
      ),
    );
    final target = math.min(10, math.max(3, (matches.length * 0.22).ceil()));
    final picked = <({RegExpMatch match, int wordIndex})>[];
    for (final candidate in candidates) {
      if (picked.length >= target) break;
      if (picked.any(
        (item) => (item.wordIndex - candidate.wordIndex).abs() <= 1,
      )) {
        continue;
      }
      picked.add(candidate);
    }
    picked.sort((a, b) => a.match.start.compareTo(b.match.start));
    for (final item in picked) {
      _clozeItems.add(
        _WritingClozeItem(
          start: item.match.start,
          end: item.match.end,
          answer: item.match.group(0) ?? '',
        ),
      );
    }
  }

  Future<void> _playDictation() async {
    final script = _script;
    if (script == null || script.targetText.isEmpty) return;
    try {
      await TtsAudioCache.instance.playText(
        text: script.targetText,
        languageCode: script.targetLanguageCode,
        courseId: _selectedCourseId ?? 0,
      );
    } catch (error) {
      _showMessage('Không phát được âm thanh: $error');
    }
  }

  void _clearAnswer() {
    _answerController.clear();
    for (final item in _clozeItems) {
      item.controller.clear();
    }
    setState(() {
      _grade = null;
      _hints = null;
      _error = '';
    });
  }

  String _buildImportPrompt() {
    final course = _selectedCourse;
    final info = _difficultyInfo;
    final code = course?.languageCode ?? 'en-US';
    return '''
Hãy tạo JSON thuần để import vào app luyện viết. Không dùng markdown.
Ngôn ngữ đích: ${_languageName(code)} ($code)
Chủ đề: ${_topicController.text.trim().isEmpty ? course?.title ?? 'giao tiếp đời thường' : _topicController.text.trim()}
Độ khó: ${info.label}; khoảng ${info.sentences} câu tiếng Việt.
Tạo vietnameseText tự nhiên và targetText cùng ý bằng ngôn ngữ đích.
Schema: {"title":"tiêu đề","topic":"chủ đề","difficulty":"${info.label}","vietnameseText":"đoạn tiếng Việt","targetText":"bản đúng","targetLanguageName":"${_languageName(code)}","targetLanguageCode":"$code","usedVocabulary":[],"contextNote":"ghi chú"}
''';
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _buildImportPrompt()));
    _showMessage('Đã chép prompt tạo JSON');
  }

  Future<void> _openImportDialog() async {
    final controller = TextEditingController();
    final imported = await showDialog<_WritingScript>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import JSON', style: _titleStyle(21)),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  style: TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Dán JSON bài luyện viết'),
                ),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionButton(
                      'Đóng',
                      Icons.close,
                      () => Navigator.pop(dialogContext),
                      primary: false,
                    ),
                    SizedBox(width: 10),
                    _actionButton('Áp dụng', Icons.check, () {
                      try {
                        final value = _WritingScript.fromJson(
                          _decodeJsonObject(controller.text),
                        );
                        if (value.vietnameseText.isEmpty ||
                            value.targetText.isEmpty) {
                          throw FormatException('JSON thiếu nội dung bài viết');
                        }
                        Navigator.pop(dialogContext, value);
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('JSON không hợp lệ: $error')),
                        );
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (imported == null || !mounted) return;
    setState(() {
      _script = imported;
      _answerController.clear();
      _grade = null;
      _hints = null;
      _buildClozeItems();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  TextStyle _titleStyle(double size) => TextStyle(
    color: Colors.white,
    fontSize: size,
    fontWeight: FontWeight.w500,
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Color(0xff667085)),
    filled: true,
    fillColor: _surface2,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _blue, width: 1.5),
    ),
  );

  Widget _actionButton(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool primary = true,
    bool expand = false,
  }) {
    final button = SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary ? _blue : _surface2,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0xff20242d),
          disabledForegroundColor: _muted,
          padding: EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: primary ? _blue : _border),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }

  Widget _tab(String value, String label, String group, VoidCallback onTap) {
    final selected = value == group;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _label(String value) => Padding(
    padding: EdgeInsets.only(bottom: 7),
    child: Text(
      value,
      style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w400),
    ),
  );

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => DropdownButtonFormField<T>(
    value: value,
    dropdownColor: _surface2,
    iconEnabledColor: Colors.white,
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
    decoration: _inputDecoration(''),
    items: items,
    onChanged: onChanged,
  );

  Widget _buildSettingsPanel() {
    final course = _selectedCourse;
    final languageCode = course?.languageCode ?? 'en-US';
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thiết lập đoạn viết', style: _titleStyle(19)),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tab('course', 'Học phần', _sourceMode, () {
                  setState(() => _sourceMode = 'course');
                }),
                _tab('topic', 'Chủ đề', _sourceMode, () {
                  setState(() => _sourceMode = 'topic');
                }),
                _tab('tense', 'Luyện thì', _sourceMode, () {
                  setState(() => _sourceMode = 'tense');
                }),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (_sourceMode != 'topic') ...[
            _label('Học phần'),
            if (_courses.isEmpty)
              Text('Chưa có học phần', style: TextStyle(color: _muted))
            else
              _dropdown<int>(
                value: _selectedCourseId ?? _courses.first.id,
                items: _courses
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(
                          '${item.title} (${item.cardCount})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCourseId = value;
                  _script = null;
                  _grade = null;
                  _hints = null;
                }),
              ),
            SizedBox(height: 14),
          ],
          if (_sourceMode == 'topic') ...[
            _label('Chủ đề/ngữ cảnh'),
            TextField(
              controller: _topicController,
              style: TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                'đi làm muộn, mua đồ, tin thời sự...',
              ),
            ),
            SizedBox(height: 14),
          ],
          if (_sourceMode == 'tense') ...[
            _label('Thì cần luyện'),
            _dropdown<String>(
              value: _tense,
              items: const [
                'Present Simple',
                'Present Continuous',
                'Past Simple',
                'Present Perfect',
                'Future Simple',
                'Past Continuous',
                'Past Perfect',
              ]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _tense = value);
              },
            ),
            SizedBox(height: 14),
          ],
          _label('Ngôn ngữ đích'),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Text(
              '${_languageName(languageCode)} ($languageCode)',
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(height: 14),
          _label('Độ khó'),
          _dropdown<String>(
            value: _difficulty,
            items: const {
              'basic': 'Cơ bản · 4 câu',
              'hard': 'Khó · 6 câu',
              'advanced': 'Nâng cao · 8 câu',
            }.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _difficulty = value);
            },
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _actionButton(
              _busyPhase == 'generate' ? 'Đang tạo...' : 'Tạo đoạn viết',
              Icons.auto_awesome_rounded,
              _busy ? null : _generate,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              _actionButton(
                'Import JSON',
                Icons.data_object,
                _busy ? null : _openImportDialog,
                primary: false,
                expand: true,
              ),
              SizedBox(width: 8),
              _actionButton(
                'Chép prompt',
                Icons.copy_rounded,
                _copyPrompt,
                primary: false,
                expand: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClozeEditor() {
    final script = _script;
    if (script == null) return SizedBox.shrink();
    if (_clozeItems.isEmpty) {
      return Text(script.targetText, style: TextStyle(color: Colors.white));
    }
    final children = <Widget>[];
    var cursor = 0;
    for (var i = 0; i < _clozeItems.length; i++) {
      final item = _clozeItems[i];
      if (item.start > cursor) {
        children.add(
          Text(
            script.targetText.substring(cursor, item.start),
            style: TextStyle(color: Colors.white, height: 1.7),
          ),
        );
      }
      children.add(
        SizedBox(
          width: math
              .max(74, math.min(170, item.answer.length * 14.0))
              .toDouble(),
          child: TextField(
            controller: item.controller,
            textInputAction: i == _clozeItems.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            style: TextStyle(color: Colors.white),
            decoration: _inputDecoration('${i + 1}').copyWith(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
        ),
      );
      cursor = item.end;
    }
    if (cursor < script.targetText.length) {
      children.add(
        Text(
          script.targetText.substring(cursor),
          style: TextStyle(color: Colors.white, height: 1.7),
        ),
      );
    }
    return Wrap(spacing: 5, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }

  Widget _buildHints() {
    final hints = _hints;
    if (hints == null) return SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hints.entries
            .where((entry) => entry.value.isNotEmpty)
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: _titleStyle(15)),
                    SizedBox(height: 6),
                    ...entry.value.map(
                      (value) => Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $value',
                          style: TextStyle(color: _muted, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGrade() {
    final grade = _grade;
    if (grade == null) return SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${grade.score}', style: _titleStyle(34)),
              Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('/100', style: TextStyle(color: _muted)),
              ),
            ],
          ),
          if (grade.overallFeedback.isNotEmpty) ...[
            SizedBox(height: 5),
            Text(
              grade.overallFeedback,
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
          if (grade.issues.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Điểm cần sửa', style: _titleStyle(16)),
            SizedBox(height: 8),
            ...grade.issues.map(
              (issue) => Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (issue.wrongText.isNotEmpty)
                      Text(
                        issue.wrongText,
                        style: TextStyle(color: _muted),
                      ),
                    if (issue.correction.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '→ ${issue.correction}',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    if (issue.explanation.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          issue.explanation,
                          style: TextStyle(color: _muted, height: 1.35),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (grade.suggestedRewrite.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('Gợi ý nên viết', style: _titleStyle(16)),
            SizedBox(height: 7),
            SelectableText(
              grade.suggestedRewrite,
              style: TextStyle(color: Colors.white, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    final script = _script;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _tab('translate', 'Viết', _practiceMode, () {
                  setState(() => _practiceMode = 'translate');
                }),
                _tab('dictation', 'Nghe viết', _practiceMode, () {
                  setState(() => _practiceMode = 'dictation');
                }),
                _tab('cloze', 'Đục lỗ', _practiceMode, () {
                  setState(() {
                    _practiceMode = 'cloze';
                    if (_clozeItems.isEmpty) _buildClozeItems();
                  });
                }),
              ],
            ),
          ),
          SizedBox(height: 18),
          if (script == null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 70, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.edit_note_rounded, color: _muted, size: 42),
                  SizedBox(height: 10),
                  Text(
                    'Chọn thiết lập và tạo đoạn viết để bắt đầu',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            )
          else ...[
            if (script.title.isNotEmpty) ...[
              Text(script.title, style: _titleStyle(21)),
              if (script.contextNote.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(script.contextNote, style: TextStyle(color: _muted)),
                ),
              SizedBox(height: 16),
            ],
            if (_practiceMode == 'translate') ...[
              _label('Đoạn tiếng Việt'),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: SelectableText(
                  script.vietnameseText,
                  style: TextStyle(color: Colors.white, height: 1.55),
                ),
              ),
              SizedBox(height: 16),
            ] else if (_practiceMode == 'dictation') ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nghe và chép lại đoạn văn', style: _titleStyle(16)),
                          SizedBox(height: 4),
                          Text(
                            '${script.targetLanguageName} · nghe lại không giới hạn',
                            style: TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _playDictation,
                      style: IconButton.styleFrom(backgroundColor: _blue),
                      icon: Icon(Icons.volume_up_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ] else ...[
              _label('Điền các từ còn thiếu'),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: _buildClozeEditor(),
              ),
              SizedBox(height: 16),
            ],
            if (_practiceMode != 'cloze') ...[
              _label('Bài viết của bạn (${script.targetLanguageCode})'),
              TextField(
                controller: _answerController,
                minLines: 7,
                maxLines: 14,
                style: TextStyle(color: Colors.white, height: 1.5),
                decoration: _inputDecoration(
                  _practiceMode == 'dictation'
                      ? 'Chép lại toàn bộ nội dung vừa nghe'
                      : 'Viết lại toàn bộ ý ở trên bằng ngôn ngữ đích',
                ),
              ),
              SizedBox(height: 14),
            ],
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _actionButton(
                  _busyPhase == 'hint' ? 'Đang gợi ý...' : 'Gợi ý',
                  Icons.lightbulb_outline_rounded,
                  _busy ? null : _requestHint,
                  primary: false,
                ),
                _actionButton(
                  _busyPhase == 'grade' ? 'Đang chấm...' : 'Gửi chấm',
                  Icons.fact_check_outlined,
                  _busy ? null : _gradeWriting,
                ),
                _actionButton(
                  'Xóa bài',
                  Icons.delete_outline_rounded,
                  _busy ? null : _clearAnswer,
                  primary: false,
                ),
              ],
            ),
            _buildHints(),
            _buildGrade(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back),
        ),
        title: Text(
          'Luyện viết',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    if (_error.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Text(_error, style: TextStyle(color: Colors.white)),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 860) {
                          return Column(
                            children: [
                              _buildSettingsPanel(),
                              SizedBox(height: 14),
                              _buildWorkspace(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 340, child: _buildSettingsPanel()),
                            SizedBox(width: 14),
                            Expanded(child: _buildWorkspace()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
