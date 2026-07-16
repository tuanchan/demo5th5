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
  final FlutterTts _writingTts = FlutterTts();

  List<CourseListItem> _courses = [];
  int? _selectedCourseId;
  String _sourceMode = 'course';
  String _practiceMode = 'translate';
  String _difficulty = 'basic';
  String _tense = 'Present Simple';
  String _targetLanguageOverride = '';
  bool _showSettings = true;
  String? _busyPhase;
  String _error = '';
  _WritingScript? _script;
  _WritingGrade? _grade;
  String _gradedSubmission = '';
  Map<String, List<String>>? _hints;
  final List<_WritingClozeItem> _clozeItems = [];

  bool get _busy => _busyPhase != null;
  CourseListItem? get _selectedCourse {
    for (final course in _courses) {
      if (course.id == _selectedCourseId) return course;
    }
    return null;
  }

  String get _targetLanguageCode {
    if (_targetLanguageOverride.isNotEmpty) return _targetLanguageOverride;
    final courseCode = _selectedCourse?.languageCode.trim() ?? '';
    return courseCode.isEmpty ? 'en-US' : courseCode;
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
    _writingTts.stop();
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
      await AppDatabase.instance.ensureTopicSchema();
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

  Future<List<StudyCardItem>> _loadVocabulary({int? limit = 90}) async {
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
    return limit == null ? cards : cards.take(limit).toList();
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
      final languageCode = _targetLanguageCode;
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
        _showSettings = false;
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
      _grade = null;
      _gradedSubmission = '';
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
Mỗi wrongText phải là chuỗi con chính xác, nguyên văn trong userText để app có thể tô đỏ đúng vị trí sai.
Không đưa các đoạn đúng vào issues, không lặp lại cùng một lỗi. Nếu chỉ thiếu nội dung, wrongText là chuỗi gần vị trí cần bổ sung.
type chỉ là grammar, meaning, wording, missing hoặc style.
Schema: {"score":82,"overallFeedback":"nhận xét","suggestedRewrite":"bản viết hoàn chỉnh","issues":[{"wrongText":"đoạn sai","correction":"sửa thành","explanation":"giải thích","type":"grammar"}]}
''';
      final raw = await GeminiFlashLiteClient.generateText(
        prompt,
        maxOutputTokens: 1600,
        responseMimeType: 'application/json',
      );
      final result = _WritingGrade.fromJson(_decodeJsonObject(raw));
      if (!mounted) return;
      setState(() {
        _grade = result;
        _gradedSubmission = userText;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
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
      if (!kIsWeb && Platform.isWindows) {
        await _writingTts.stop();
        await _writingTts.setLanguage(script.targetLanguageCode);
        await _writingTts.setSpeechRate(0.42);
        await _writingTts.speak(script.targetText);
        return;
      }
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

  String _promptLanguageName(String code) {
    final normalized = code.toLowerCase();
    if (normalized.startsWith('zh')) return 'Tiếng Trung (Chinese)';
    if (normalized.startsWith('ja')) return 'Tiếng Nhật (Japanese)';
    if (normalized.startsWith('ko')) return 'Tiếng Hàn (Korean)';
    if (normalized.startsWith('fr')) return 'Tiếng Pháp (French)';
    if (normalized.startsWith('de')) return 'Tiếng Đức (German)';
    if (normalized.startsWith('es')) return 'Tiếng Tây Ban Nha (Spanish)';
    if (normalized.startsWith('vi')) return 'Tiếng Việt (Vietnamese)';
    return 'Tiếng Anh (English)';
  }

  String _buildImportPrompt(List<StudyCardItem> cards) {
    final course = _selectedCourse;
    final info = _difficultyInfo;
    final code = _targetLanguageCode;
    final languageName = _promptLanguageName(code);
    final promptSentences = _difficulty == 'basic' ? 3 : info.sentences;
    final promptInstruction = _difficulty == 'basic'
        ? 'câu ngắn, cấu trúc quen thuộc, ít mệnh đề phụ, phù hợp để luyện nền tảng'
        : info.instruction;
    final topic = _topicController.text.trim().isEmpty
        ? course?.title ?? 'giao tiếp đời thường'
        : _topicController.text.trim();
    final vocabulary = cards
        .map(
          (card) => <String, String>{
            'term': card.term.trim(),
            'meaning': card.definition.trim(),
            'pinyin': card.pronunciation.trim(),
          },
        )
        .toList();
    final vocabularyJson = const JsonEncoder.withIndent('  ').convert(
      vocabulary,
    );
    final suggestedParagraphs = cards.isEmpty
        ? 0
        : (cards.length / 5).ceil();
    return '''
Hãy tạo JSON để import vào app luyện viết.

Ngôn ngữ đích: $languageName ($code)
Chủ đề/ngữ cảnh: $topic
Mức độ: ${info.label}
Số câu tiếng Việt mỗi đoạn: khoảng $promptSentences câu.
Yêu cầu: $promptInstruction.

Học phần hiện tại: ${course?.title ?? 'Chưa chọn học phần'}

Danh sách từ vựng học phần hiện tại JSON (đã trộn ngẫu nhiên, tổng ${cards.length} từ/cụm):
$vocabularyJson

Yêu cầu tạo đoạn:
- Tự đếm tổng số từ vựng trong JSON.
- Tự tính số đoạn phù hợp để phủ hết từ vựng.
- Mỗi đoạn dùng linh hoạt khoảng 4-6 từ/cụm từ khác nhau.
- Công thức gợi ý: số đoạn = làm tròn lên của tổng số từ vựng / 5. Với danh sách này, số đoạn gợi ý là $suggestedParagraphs.
- Nếu còn dư từ, phân bổ vào các đoạn cuối.
- Ưu tiên dùng gần hết từ vựng, nhưng không ép nếu câu bị mất tự nhiên.
- Mỗi đoạn phải có tổ hợp từ vựng khác nhau, tránh lặp lại nếu chưa cần.
- Nội dung giống TOEIC Part 1: mô tả người, đồ vật, văn phòng, thiết bị, cảnh làm việc.
- Đoạn tiếng Việt phải tự nhiên, ngắn, thực tế, không văn phong AI.
- targetText là bản viết đúng bằng ngôn ngữ đích, cùng ý với vietnameseText.
- Dùng từ vựng tự nhiên trong targetText; vietnameseText phải giữ cùng ý để người học dịch/viết lại.
- Độ khó phải bám đúng mức độ đã chọn.
- Không dùng từ quá khó, không viết dài.

Cách trả lời:
- Mỗi đoạn đặt trong một text box/code block JSON riêng để dễ sao chép.
- Ghi rõ: Đoạn 1, Đoạn 2, Đoạn 3...
- Không gộp nhiều đoạn vào một JSON lớn.
- Mỗi text box chỉ chứa đúng 1 object JSON theo schema sau:

{
  "title": "tiêu đề ngắn",
  "topic": "chủ đề",
  "difficulty": "${info.label}",
  "vietnameseText": "đoạn tiếng Việt để người học nhìn và viết lại",
  "targetText": "bản đúng bằng ngôn ngữ đích để app dùng chấm",
  "targetLanguageName": "$languageName",
  "targetLanguageCode": "$code",
  "usedVocabulary": ["từ/cụm đã dùng nếu có"],
  "contextNote": "ghi chú ngắn bằng tiếng Việt"
}
''';
  }

  Future<void> _copyPrompt() async {
    if (_selectedCourse == null) {
      _showMessage('Hãy chọn học phần trước');
      return;
    }
    final cards = await _loadVocabulary(limit: null);
    await Clipboard.setData(
      ClipboardData(text: _buildImportPrompt(cards)),
    );
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
      _showSettings = false;
      _buildClozeItems();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scrollToWidget(BuildContext widgetContext) async {
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    try {
      Scrollable.ensureVisible(
        widgetContext,
        alignment: 0.15,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {}
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
    Widget? iconWidget,
  }) {
    final button = SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: iconWidget ?? Icon(icon, size: 18),
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
    final courseLanguageCode = course?.languageCode.trim().isNotEmpty == true
        ? course!.languageCode.trim()
        : 'en-US';
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
          _dropdown<String>(
            value: _targetLanguageOverride.isEmpty
                ? '__course__'
                : _targetLanguageOverride,
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: '__course__',
                child: Text(
                  'Theo học phần · ${_languageName(courseLanguageCode)} ($courseLanguageCode)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...const {
                'en-US': 'Tiếng Anh (en-US)',
                'zh-TW': 'Tiếng Trung phồn thể (zh-TW)',
                'ja-JP': 'Tiếng Nhật (ja-JP)',
                'ko-KR': 'Tiếng Hàn (ko-KR)',
                'fr-FR': 'Tiếng Pháp (fr-FR)',
                'de-DE': 'Tiếng Đức (de-DE)',
                'es-ES': 'Tiếng Tây Ban Nha (es-ES)',
              }.entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _targetLanguageOverride = value == '__course__'
                    ? ''
                    : (value ?? '');
                _script = null;
                _grade = null;
                _hints = null;
              });
            },
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
              primary: false,
              iconWidget: geminiColorIcon(size: 19),
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
              .max(80, math.min(180, item.answer.length * 14.0))
              .toDouble(),
          child: Builder(
            builder: (textFieldContext) => TextField(
              controller: item.controller,
              cursorColor: Color(0xff9ab9ff),
              textAlign: TextAlign.center,
              onTap: () => _scrollToWidget(textFieldContext),
              textInputAction: i == _clozeItems.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onEditingComplete: () {
                if (i == _clozeItems.length - 1) {
                  FocusScope.of(context).unfocus();
                  return;
                }
                FocusScope.of(context).nextFocus();
              },
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.fromLTRB(4, 2, 4, 5),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xffb7ccff),
                    width: 2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xff4257ff),
                    width: 2.4,
                  ),
                ),
              ),
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
    final submission = _gradedSubmission.isNotEmpty
        ? _gradedSubmission
        : (_submissionText() ?? '');
    final scoreColor = grade.score >= 70
        ? Color(0xff18b875)
        : grade.score >= 50
            ? Color(0xffd99a27)
            : Color(0xffef5b64);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${grade.score}/100',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (grade.overallFeedback.isNotEmpty) ...[
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    grade.overallFeedback,
                    style: TextStyle(color: Color(0xffb8c8ff), height: 1.4),
                  ),
                ),
              ],
            ],
          ),
          if (submission.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Bài bạn đã viết', style: _titleStyle(15)),
            SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xff0d1018),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Color(0xff344266)),
              ),
              child: Text.rich(
                _highlightWritingIssues(submission, grade.issues),
                style: TextStyle(
                  color: Colors.white,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (grade.issues.isNotEmpty) ...[
            SizedBox(height: 12),
            ...grade.issues.map(
              (issue) => Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xff241114),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xff8f2931)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (issue.wrongText.isNotEmpty)
                          Text(
                            issue.wrongText,
                            style: TextStyle(
                              color: Color(0xffff7f87),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (issue.correction.isNotEmpty)
                          Text(
                            issue.correction,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (issue.explanation.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          issue.explanation,
                          style: TextStyle(
                            color: Color(0xffb8c8ff),
                            height: 1.35,
                          ),
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xff0d1018),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Color(0xff344266)),
              ),
              child: SelectableText(
                grade.suggestedRewrite,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextSpan _highlightWritingIssues(
    String submission,
    List<_WritingIssue> issues,
  ) {
    final lowerSubmission = submission.toLowerCase();
    final ranges = <({int start, int end})>[];
    final sortedIssues = [...issues]
      ..sort((a, b) => b.wrongText.length.compareTo(a.wrongText.length));

    for (final issue in sortedIssues) {
      final wrongText = issue.wrongText.trim();
      if (wrongText.isEmpty) continue;
      final needle = wrongText.toLowerCase();
      var searchFrom = 0;
      var matched = false;
      while (searchFrom < lowerSubmission.length) {
        final start = lowerSubmission.indexOf(needle, searchFrom);
        if (start < 0) break;
        final end = start + wrongText.length;
        final overlaps = ranges.any(
          (range) => start < range.end && end > range.start,
        );
        if (!overlaps) {
          ranges.add((start: start, end: end));
          matched = true;
          break;
        }
        searchFrom = start + 1;
      }

      if (matched) continue;

      // Gemini đôi khi giữ nguyên chữ nhưng đổi khoảng trắng/xuống dòng.
      // Cho phép khoảng trắng linh hoạt để vẫn tô đúng đoạn trong bài nộp.
      final words = wrongText.split(RegExp(r'\s+'));
      if (words.length < 2) continue;
      final flexiblePattern = words.map(RegExp.escape).join(r'\s+');
      for (final match in RegExp(
        flexiblePattern,
        caseSensitive: false,
        unicode: true,
      ).allMatches(submission)) {
        final overlaps = ranges.any(
          (range) => match.start < range.end && match.end > range.start,
        );
        if (overlaps) continue;
        ranges.add((start: match.start, end: match.end));
        break;
      }
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    if (ranges.isEmpty) return TextSpan(text: submission);

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: submission.substring(cursor, range.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              color: Color(0xff8f272f),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Color(0xffc84a54), width: 0.8),
            ),
            child: Text(
              submission.substring(range.start, range.end),
              style: TextStyle(
                color: Color(0xfffff1f2),
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xffffa0a6),
              ),
            ),
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < submission.length) {
      spans.add(TextSpan(text: submission.substring(cursor)));
    }
    return TextSpan(children: spans);
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
              Builder(
                builder: (textFieldContext) => TextField(
                  controller: _answerController,
                  minLines: 7,
                  maxLines: 14,
                  onTap: () => _scrollToWidget(textFieldContext),
                  style: TextStyle(color: Colors.white, height: 1.5),
                  decoration: _inputDecoration(
                    _practiceMode == 'dictation'
                        ? 'Chép lại toàn bộ nội dung vừa nghe'
                        : 'Viết lại toàn bộ ý ở trên bằng ngôn ngữ đích',
                  ),
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
                  primary: false,
                  iconWidget: geminiColorIcon(size: 19),
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
        toolbarHeight: 66,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back),
        ),
        title: Text(
          'Luyện viết',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
        actions: [
          IconButton(
            tooltip: _showSettings ? 'Ẩn thiết lập' : 'Hiện thiết lập',
            onPressed: () => setState(() => _showSettings = !_showSettings),
            icon: Icon(Icons.tune_rounded),
          ),
          SizedBox(width: 4),
        ],
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
                              if (_showSettings) ...[
                                _buildSettingsPanel(),
                                SizedBox(height: 14),
                              ],
                              _buildWorkspace(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showSettings) ...[
                              SizedBox(
                                width: 340,
                                child: _buildSettingsPanel(),
                              ),
                              SizedBox(width: 14),
                            ],
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
