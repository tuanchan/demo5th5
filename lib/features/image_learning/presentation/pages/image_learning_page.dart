part of flutterflashcard_main;

class ImageVocabularyDetection {
  final String term;
  final String pronunciation;
  final String meaningVi;
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;
  final double labelX;
  final double labelY;

  const ImageVocabularyDetection({
    required this.term,
    required this.pronunciation,
    required this.meaningVi,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.labelX,
    required this.labelY,
  });

  factory ImageVocabularyDetection.fromJson(
    Map<String, dynamic> json,
    int index,
  ) {
    double number(Object? value, double fallback) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed == null) return fallback;
      return parsed > 1 ? parsed / 1000 : parsed;
    }

    final fallbackTop = 0.08 + (index % 8) * 0.105;
    var xMin = 0.06;
    var yMin = fallbackTop;
    var xMax = 0.34;
    var yMax = math.min(0.96, fallbackTop + 0.08);
    var labelX = index.isEven ? 0.04 : 0.62;
    var labelY = fallbackTop;
    final box = json['box'] ?? json['boundingBox'] ?? json['bounding_box'];
    if (box is List && box.length >= 4) {
      // Gemini vision uses [yMin, xMin, yMax, xMax], normalized to 0..1000.
      yMin = number(box[0], yMin);
      xMin = number(box[1], xMin);
      yMax = number(box[2], yMax);
      xMax = number(box[3], xMax);
    } else if (box is Map) {
      xMin = number(box['xMin'] ?? box['left'], xMin);
      yMin = number(box['yMin'] ?? box['top'], yMin);
      xMax = number(box['xMax'] ?? box['right'], xMax);
      yMax = number(box['yMax'] ?? box['bottom'], yMax);
    }
    final labelPoint =
        json['labelPoint'] ?? json['label_point'] ?? json['labelAnchor'];
    if (labelPoint is List && labelPoint.length >= 2) {
      labelY = number(labelPoint[0], labelY);
      labelX = number(labelPoint[1], labelX);
    } else if (labelPoint is Map) {
      labelX = number(labelPoint['x'] ?? labelPoint['left'], labelX);
      labelY = number(labelPoint['y'] ?? labelPoint['top'], labelY);
    }

    xMin = xMin.clamp(0.0, 0.98).toDouble();
    yMin = yMin.clamp(0.0, 0.98).toDouble();
    xMax = xMax.clamp(xMin + 0.01, 1.0).toDouble();
    yMax = yMax.clamp(yMin + 0.01, 1.0).toDouble();
    labelX = labelX.clamp(0.01, 0.99).toDouble();
    labelY = labelY.clamp(0.01, 0.99).toDouble();
    return ImageVocabularyDetection(
      term: (json['term'] ?? json['word'] ?? json['text'])
              ?.toString()
              .trim() ??
          '',
      pronunciation:
          (json['pronunciation'] ?? json['pinyin'] ?? json['romanization'])
                  ?.toString()
                  .trim() ??
              '',
      meaningVi:
          (json['meaningVi'] ?? json['meaning_vi'] ?? json['meaning'])
                  ?.toString()
                  .trim() ??
              '',
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      labelX: labelX,
      labelY: labelY,
    );
  }

  factory ImageVocabularyDetection.fromStoredJson(
    Map<String, dynamic> json,
  ) {
    double value(String key) =>
        (json[key] as num?)?.toDouble() ??
        double.tryParse(json[key]?.toString() ?? '') ??
        0;
    return ImageVocabularyDetection(
      term: json['term']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      meaningVi: json['meaningVi']?.toString() ?? '',
      xMin: value('xMin'),
      yMin: value('yMin'),
      xMax: value('xMax'),
      yMax: value('yMax'),
      labelX: value('labelX'),
      labelY: value('labelY'),
    );
  }

  Map<String, Object?> toJson() => {
        'term': term,
        'pronunciation': pronunciation,
        'meaningVi': meaningVi,
        'xMin': xMin,
        'yMin': yMin,
        'xMax': xMax,
        'yMax': yMax,
        'labelX': labelX,
        'labelY': labelY,
      };
}

class ImageLearningEntry {
  final String id;
  final String displayName;
  final String originalPath;
  final String annotatedPath;
  final String languageCode;
  final String languageName;
  final DateTime createdAt;
  final List<ImageVocabularyDetection> vocabulary;

  const ImageLearningEntry({
    required this.id,
    required this.displayName,
    required this.originalPath,
    required this.annotatedPath,
    required this.languageCode,
    required this.languageName,
    required this.createdAt,
    required this.vocabulary,
  });

  factory ImageLearningEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['vocabulary'];
    return ImageLearningEntry(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString().trim().isNotEmpty == true
          ? json['displayName'].toString().trim()
          : 'Ảnh học ${json['id']?.toString() ?? ''}',
      originalPath: json['originalPath']?.toString() ?? '',
      annotatedPath: json['annotatedPath']?.toString() ?? '',
      languageCode: json['languageCode']?.toString() ?? 'und',
      languageName: json['languageName']?.toString() ?? 'Đa ngôn ngữ',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      vocabulary: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => ImageVocabularyDetection.fromStoredJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'originalPath': originalPath,
        'annotatedPath': annotatedPath,
        'languageCode': languageCode,
        'languageName': languageName,
        'createdAt': createdAt.toIso8601String(),
        'vocabulary': vocabulary.map((item) => item.toJson()).toList(),
      };

  ImageLearningEntry copyWith({String? displayName}) {
    return ImageLearningEntry(
      id: id,
      displayName: displayName ?? this.displayName,
      originalPath: originalPath,
      annotatedPath: annotatedPath,
      languageCode: languageCode,
      languageName: languageName,
      createdAt: createdAt,
      vocabulary: vocabulary,
    );
  }
}

class _PickedLearningImage {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  const _PickedLearningImage({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
}

class _ImageCourseImportChoice {
  final bool createNew;
  final String title;
  final int? courseId;
  final int? topicId;

  const _ImageCourseImportChoice({
    required this.createNew,
    required this.title,
    required this.courseId,
    required this.topicId,
  });
}

class _ImageLanguageOption {
  final String code;
  final String name;
  final String instruction;

  const _ImageLanguageOption(this.code, this.name, this.instruction);
}

class ImageLearningRepository {
  ImageLearningRepository._();

  static Future<Directory> _directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'image_learning'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<File> _manifest() async {
    final directory = await _directory();
    return File(p.join(directory.path, 'manifest.json'));
  }

  static Future<List<ImageLearningEntry>> load() async {
    try {
      final manifest = await _manifest();
      if (!await manifest.exists()) return [];
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! List) return [];
      final entries = decoded
          .whereType<Map>()
          .map(
            (row) => ImageLearningEntry.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((entry) => File(entry.annotatedPath).existsSync())
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (error) {
      debugPrint('LOAD IMAGE LEARNING LIBRARY ERROR: $error');
      return [];
    }
  }

  static Future<void> _writeManifest(List<ImageLearningEntry> entries) async {
    final manifest = await _manifest();
    await manifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        entries.map((entry) => entry.toJson()).toList(),
      ),
      flush: true,
    );
  }

  static Future<ImageLearningEntry> save({
    required Uint8List originalBytes,
    required Uint8List annotatedBytes,
    required String originalExtension,
    required String languageCode,
    required String languageName,
    required List<ImageVocabularyDetection> vocabulary,
    required String displayName,
  }) async {
    final directory = await _directory();
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final safeExtension = originalExtension.toLowerCase().replaceAll('.', '');
    final originalPath = p.join(
      directory.path,
      '${id}_original.${safeExtension.isEmpty ? 'jpg' : safeExtension}',
    );
    final annotatedPath = p.join(directory.path, '${id}_annotated.png');
    await File(originalPath).writeAsBytes(originalBytes, flush: true);
    await File(annotatedPath).writeAsBytes(annotatedBytes, flush: true);

    final entry = ImageLearningEntry(
      id: id,
      displayName: displayName,
      originalPath: originalPath,
      annotatedPath: annotatedPath,
      languageCode: languageCode,
      languageName: languageName,
      createdAt: now,
      vocabulary: vocabulary,
    );
    final entries = await load();
    entries.insert(0, entry);
    await _writeManifest(entries);
    return entry;
  }

  static Future<void> update(List<ImageLearningEntry> entries) {
    return _writeManifest(entries);
  }

  static Future<void> delete(
    ImageLearningEntry target,
    List<ImageLearningEntry> remaining,
  ) async {
    for (final path in [target.originalPath, target.annotatedPath]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _writeManifest(remaining);
  }
}

class ImageLearningPage extends StatefulWidget {
  const ImageLearningPage({super.key});

  @override
  State<ImageLearningPage> createState() => _ImageLearningPageState();
}

class _ImageLearningPageState extends State<ImageLearningPage>
    with WidgetsBindingObserver {
  static const Color _bg = Color(0xff05070c);
  static const Color _panel = Color(0xff0d1421);
  static const Color _panel2 = Color(0xff141c2b);
  static const Color _border = Color(0xff304267);
  static const Color _text = Color(0xfff3f7ff);
  static const Color _muted = Color(0xff93a0b5);
  static const Color _blue = Color(0xff4f6dff);
  static const Color _yellow = Color(0xffffcf33);
  static const String _preferredVisionModel = 'gemini-3.1-flash-lite';
  static const String _languageSettingKey = 'imageLearning.languageCode';
  static const List<String> _annotationFontFallback = [
    'Segoe UI',
    'Microsoft YaHei',
    'Microsoft JhengHei',
    'Yu Gothic',
    'Meiryo',
    'Malgun Gothic',
    'Arial Unicode MS',
  ];
  static const List<_ImageLanguageOption> _languages = [
    _ImageLanguageOption(
      'zh-CN',
      'Tiếng Trung giản thể',
      'Dùng chữ Hán giản thể và pinyin có dấu.',
    ),
    _ImageLanguageOption(
      'zh-TW',
      'Tiếng Trung phồn thể',
      'Dùng chữ Hán phồn thể và pinyin có dấu.',
    ),
    _ImageLanguageOption(
      'en-US',
      'Tiếng Anh',
      'Dùng tiếng Anh và phiên âm IPA dễ đọc.',
    ),
    _ImageLanguageOption(
      'ja-JP',
      'Tiếng Nhật',
      'Dùng chữ Nhật và kana/romaji.',
    ),
    _ImageLanguageOption(
      'ko-KR',
      'Tiếng Hàn',
      'Dùng Hangul và romanization.',
    ),
    _ImageLanguageOption(
      'vi-VN',
      'Tiếng Việt',
      'Dùng tiếng Việt và cách đọc tự nhiên.',
    ),
    _ImageLanguageOption(
      'fr-FR',
      'Tiếng Pháp',
      'Dùng tiếng Pháp và phiên âm/cách đọc.',
    ),
    _ImageLanguageOption(
      'de-DE',
      'Tiếng Đức',
      'Dùng tiếng Đức và phiên âm/cách đọc.',
    ),
    _ImageLanguageOption(
      'es-ES',
      'Tiếng Tây Ban Nha',
      'Dùng tiếng Tây Ban Nha và phiên âm/cách đọc.',
    ),
    _ImageLanguageOption(
      'th-TH',
      'Tiếng Thái',
      'Dùng chữ Thái và romanization.',
    ),
  ];

  final PageController _pageController =
      PageController(viewportFraction: 0.91);
  final ScrollController _thumbnailScrollController = ScrollController();
  List<ImageLearningEntry> _entries = [];
  CameraController? _cameraController;
  bool _loading = true;
  bool _processing = false;
  bool _cameraInitializing = true;
  bool _showCamera = true;
  bool _showImageList = false;
  int _currentIndex = 0;
  double _imageDragDx = 0;
  double _imageDragDy = 0;
  double _imageDragStartLocalY = 0;
  double _imageDragHeight = 1;
  bool _isDraggingImage = false;
  String _status = '';
  String _cameraError = '';
  String _selectedLanguageCode = 'zh-CN';

  ImageLearningEntry? get _currentEntry {
    if (_entries.isEmpty) return null;
    return _entries[_currentIndex.clamp(0, _entries.length - 1).toInt()];
  }

  _ImageLanguageOption get _selectedLanguage {
    return _languages.firstWhere(
      (item) => item.code == _selectedLanguageCode,
      orElse: () => _languages.first,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLibrary();
    _loadPreferences();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed && _showCamera) {
      _initializeCamera();
    }
  }

  Future<void> _loadPreferences() async {
    final saved = await AppSettingsStore.getString(_languageSettingKey);
    if (!mounted || saved == null) return;
    if (_languages.any((item) => item.code == saved)) {
      setState(() => _selectedLanguageCode = saved);
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraInitializing && _cameraController != null) return;
    if (mounted) {
      setState(() {
        _cameraInitializing = true;
        _cameraError = '';
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Không tìm thấy camera');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final previous = _cameraController;
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await previous?.dispose();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraInitializing = false;
        _cameraError = '';
      });
    } catch (error) {
      debugPrint('IMAGE LEARNING CAMERA INIT ERROR: $error');
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _cameraError =
            'Không mở được camera. Bạn vẫn có thể dùng nút Chọn ảnh.';
      });
    }
  }

  Future<void> _loadLibrary() async {
    final entries = await ImageLearningRepository.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _currentIndex = 0;
      _loading = false;
    });
  }

  String _mimeTypeForName(String name) {
    final extension = p.extension(name).toLowerCase();
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<_PickedLearningImage?> _pickFromFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) return null;
    return _PickedLearningImage(
      bytes: bytes,
      name: picked.name,
      mimeType: _mimeTypeForName(picked.name),
    );
  }

  Future<Uint8List> _analysisBytes(Uint8List original) async {
    final codec = await ui.instantiateImageCodec(original);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final originalWidth = image.width;
    final originalHeight = image.height;
    final maxSide = math.max(image.width, image.height);
    if (maxSide <= 1600) {
      image.dispose();
      codec.dispose();
      return original;
    }
    final scale = 1600 / maxSide;
    image.dispose();
    codec.dispose();
    final resizedCodec = await ui.instantiateImageCodec(
      original,
      targetWidth: math.max(1, (originalWidth * scale).round()).toInt(),
      targetHeight: math.max(1, (originalHeight * scale).round()).toInt(),
    );
    final resizedFrame = await resizedCodec.getNextFrame();
    final data = await resizedFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    resizedFrame.image.dispose();
    resizedCodec.dispose();
    if (data == null) return original;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  String _analysisPrompt() {
    final language = _selectedLanguage;
    return '''
Phân tích ảnh học tập, tự nhận diện các đồ vật chính rồi tạo dữ liệu ghi chú
theo phong cách scrapbook dễ thương.

Ngôn ngữ người dùng đã chọn: ${language.name} (${language.code}).
${language.instruction}

Mỗi đồ vật có nhãn nền đen bo góc viền trắng, chữ gồm đúng 3 dòng:
1. từ bằng ${language.name};
2. cách đọc chuẩn của từ đó;
3. nghĩa tiếng Việt ngắn, đúng chính tả.
Nghĩa tiếng Việt sẽ được hiển thị màu vàng. Thêm mũi tên viết tay trắng chỉ
đúng vật thể.

Góc trên trái sẽ có bảng từ vựng dạng sổ tay nền đen, liệt kê toàn bộ từ đã
gắn nhãn. Bố cục cần có khoảng trống để trang trí sticker pastel như balo,
xe buýt, thỏ, ngôi sao, tim và nốt nhạc. Giữ ảnh gốc rõ nét, không che vật
thể quan trọng, chữ đúng chính tả, bố cục cân đối. Các đồ vật nhỏ cần box sát
vật thể để app vẽ border trắng tách biệt và dễ nhận diện.

Hãy chọn 8-16 vật thể rõ ràng, hữu ích nhất:
- term bắt buộc là tên vật thể bằng ${language.name}, không sao chép ngôn ngữ
  ngẫu nhiên đang xuất hiện trên ảnh;
- pronunciation là cách đọc chuẩn phù hợp với ${language.code};
- meaningVi luôn là nghĩa tiếng Việt tự nhiên;
- box là vùng sát vật thể theo [yMin, xMin, yMax, xMax];
- labelPoint là vị trí bảng ghi chú theo [y, x], ưu tiên khoảng trống gần vật;
- các labelPoint không chồng lên nhau, không đặt trên bảng từ vựng góc trái.

Tọa độ đều là số nguyên từ 0 đến 1000.
Chỉ trả JSON đúng cấu trúc:
{
  "languageCode": "${language.code}",
  "languageName": "${language.name}",
  "items": [
    {
      "term": "từ trong ngôn ngữ đích",
      "pronunciation": "cách đọc",
      "meaningVi": "nghĩa tiếng Việt",
      "box": [0, 0, 1000, 1000],
      "labelPoint": [0, 0]
    }
  ]
}
Không thêm markdown, không giải thích ngoài JSON, không bịa vật thể.
''';
  }

  Map<String, dynamic> _decodeAnalysis(String raw) {
    var text = raw.trim();
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('AI không trả về object JSON');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Uint8List> _drawAnnotations(
    Uint8List original,
    List<ImageVocabularyDetection> items,
  ) async {
    final codec = await ui.instantiateImageCodec(original);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final longestSide = math.max(source.width, source.height);
    final outputScale = longestSide > 2400 ? 2400 / longestSide : 1.0;
    final outputWidth =
        math.max(1, (source.width * outputScale).round()).toInt();
    final outputHeight =
        math.max(1, (source.height * outputScale).round()).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final width = outputWidth.toDouble();
    final height = outputHeight.toDouble();
    final baseFont = (width / 43).clamp(17.0, 38.0).toDouble();
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, width / 440).toDouble()
      ..strokeCap = StrokeCap.round;
    final targetPaint = Paint()..color = _yellow.withOpacity(0.98);
    final bubblePaint = Paint()..color = const Color(0xe81b1e24);
    final bubbleBorder = Paint()
      ..color = Colors.white.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, width / 650).toDouble();
    final smallObjectBorder = Paint()
      ..color = Colors.white.withOpacity(0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, width / 520).toDouble();

    final summaryWidth = math
        .min(width * 0.5, math.max(width * 0.34, 300.0))
        .toDouble();
    final summaryHeight = math
        .min(
          height * 0.45,
          math.max(baseFont * 5.2, baseFont * (items.length * 0.78 + 2.2)),
        )
        .toDouble();
    final summaryRect = Rect.fromLTWH(
      baseFont * 0.45,
      baseFont * 0.45,
      summaryWidth,
      summaryHeight,
    );
    final summaryRRect = RRect.fromRectAndRadius(
      summaryRect,
      Radius.circular(baseFont * 0.65),
    );
    canvas.drawRRect(summaryRRect, bubblePaint);
    canvas.drawRRect(summaryRRect, bubbleBorder);
    final summaryTitle = TextPainter(
      text: TextSpan(
        text: 'TỪ VỰNG HÔM NAY · ${_selectedLanguage.name}',
        style: TextStyle(
          color: _yellow,
          fontSize: baseFont * 0.68,
          fontWeight: FontWeight.w900,
          fontFamilyFallback: _annotationFontFallback,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: summaryWidth - baseFont);
    summaryTitle.paint(
      canvas,
      Offset(summaryRect.left + baseFont * 0.5, summaryRect.top + baseFont * 0.5),
    );
    final rowsTop = summaryRect.top + baseFont * 1.45;
    final availableRowsHeight =
        summaryRect.bottom - rowsTop - baseFont * 0.35;
    final rowHeight = availableRowsHeight / math.max(1, items.length);
    final summaryFont =
        math.min(baseFont * 0.58, rowHeight * 0.7).clamp(8.0, 19.0).toDouble();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final row = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${index + 1}. ${item.term}',
              style: const TextStyle(color: Colors.white),
            ),
            if (item.pronunciation.isNotEmpty)
              TextSpan(
                text: '  ${item.pronunciation}',
                style: const TextStyle(color: Color(0xffd7deeb)),
              ),
            TextSpan(
              text: '  ${item.meaningVi}',
              style: const TextStyle(color: Color(0xffffdf54)),
            ),
          ],
          style: TextStyle(
            fontSize: summaryFont,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: _annotationFontFallback,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: summaryWidth - baseFont);
      row.paint(
        canvas,
        Offset(
          summaryRect.left + baseFont * 0.5,
          rowsTop + index * rowHeight,
        ),
      );
    }
    for (var ring = 0; ring < 6; ring++) {
      final center = Offset(
        summaryRect.left + baseFont * (0.8 + ring * 1.05),
        summaryRect.top,
      );
      canvas.drawCircle(center, baseFont * 0.17, bubbleBorder);
    }

    void drawStar(Offset center, double radius, Color color) {
      final path = Path();
      for (var point = 0; point < 10; point++) {
        final angle = -math.pi / 2 + point * math.pi / 5;
        final pointRadius = point.isEven ? radius : radius * 0.45;
        final offset = Offset(
          center.dx + math.cos(angle) * pointRadius,
          center.dy + math.sin(angle) * pointRadius,
        );
        if (point == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, bubbleBorder);
    }

    void drawHeart(Offset center, double size) {
      final path = Path()
        ..moveTo(center.dx, center.dy + size * 0.45)
        ..cubicTo(
          center.dx - size,
          center.dy - size * 0.12,
          center.dx - size * 0.52,
          center.dy - size,
          center.dx,
          center.dy - size * 0.42,
        )
        ..cubicTo(
          center.dx + size * 0.52,
          center.dy - size,
          center.dx + size,
          center.dy - size * 0.12,
          center.dx,
          center.dy + size * 0.45,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xffff91b8));
      canvas.drawPath(path, bubbleBorder);
    }

    void drawMusicNote(Offset center, double size) {
      final notePaint = Paint()
        ..color = const Color(0xffa9b8ff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, size * 0.18)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx, center.dy - size),
        Offset(center.dx, center.dy + size * 0.42),
        notePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - size),
        Offset(center.dx + size * 0.72, center.dy - size * 0.72),
        notePaint,
      );
      canvas.drawCircle(
        Offset(center.dx - size * 0.25, center.dy + size * 0.55),
        size * 0.32,
        Paint()..color = const Color(0xffa9b8ff),
      );
    }

    drawStar(
      Offset(width - baseFont * 1.1, baseFont * 1.2),
      baseFont * 0.65,
      const Color(0xffffdb66),
    );
    drawHeart(
      Offset(width - baseFont * 1.35, height - baseFont * 1.2),
      baseFont * 0.65,
    );
    drawMusicNote(
      Offset(baseFont * 1.05, height - baseFont * 1.3),
      baseFont * 0.68,
    );

    final placedBubbles = <Rect>[summaryRect];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final target = Rect.fromLTRB(
        item.xMin * width,
        item.yMin * height,
        item.xMax * width,
        item.yMax * height,
      );
      final safeTarget = target.intersect(Rect.fromLTWH(0, 0, width, height));
      final targetAreaRatio =
          safeTarget.width * safeTarget.height / (width * height);
      if (targetAreaRatio < 0.055) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            safeTarget.inflate(baseFont * 0.12),
            Radius.circular(baseFont * 0.32),
          ),
          smallObjectBorder,
        );
      }

      final bubbleWidth = math
          .min(width * 0.39, math.max(width * 0.26, 230.0))
          .toDouble();
      final bubbleHeight = baseFont * 3.5;
      final fallbackLabelX =
          safeTarget.center.dx < width * 0.5 ? 0.03 : 0.97;
      final labelX = item.labelX > 0 ? item.labelX : fallbackLabelX;
      final labelY =
          item.labelY > 0 ? item.labelY : safeTarget.center.dy / height;
      var bubbleLeft = (labelX * width - bubbleWidth / 2)
          .clamp(10.0, width - bubbleWidth - 10.0)
          .toDouble();
      var bubbleTop = (labelY * height - bubbleHeight / 2)
          .clamp(10.0, height - bubbleHeight - 10.0)
          .toDouble();
      var bubbleRect =
          Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight);
      for (var attempt = 0; attempt < 14; attempt++) {
        final overlaps = placedBubbles.any(
          (placed) => placed.inflate(baseFont * 0.18).overlaps(bubbleRect),
        );
        if (!overlaps) break;
        final row = (attempt ~/ 2) + 1;
        final direction = attempt.isEven ? 1.0 : -1.0;
        bubbleTop = (labelY * height -
                bubbleHeight / 2 +
                direction * row * (bubbleHeight + baseFont * 0.28))
            .clamp(10.0, height - bubbleHeight - 10.0)
            .toDouble();
        if (attempt >= 8) {
          bubbleLeft = (bubbleLeft +
                  (attempt.isEven ? bubbleWidth * 0.52 : -bubbleWidth * 0.52))
              .clamp(10.0, width - bubbleWidth - 10.0)
              .toDouble();
        }
        bubbleRect =
            Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight);
      }
      placedBubbles.add(bubbleRect);
      final bubble = RRect.fromRectAndRadius(
        bubbleRect,
        Radius.circular(baseFont * 0.62),
      );

      final targetPoint = safeTarget.center;
      final startPoint = Offset(
        targetPoint.dx < bubbleRect.left
            ? bubbleRect.left
            : targetPoint.dx > bubbleRect.right
                ? bubbleRect.right
                : bubbleRect.center.dx,
        targetPoint.dy < bubbleRect.top
            ? bubbleRect.top
            : targetPoint.dy > bubbleRect.bottom
                ? bubbleRect.bottom
                : bubbleRect.center.dy,
      );
      final controlPoint = Offset(
        startPoint.dx + (targetPoint.dx - startPoint.dx) * 0.52,
        startPoint.dy,
      );
      final leader = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          targetPoint.dx,
          targetPoint.dy,
        );
      canvas.drawPath(leader, linePaint);
      final arrowAngle = math.atan2(
        targetPoint.dy - controlPoint.dy,
        targetPoint.dx - controlPoint.dx,
      );
      final arrowSize = baseFont * 0.48;
      canvas.drawLine(
        targetPoint,
        Offset(
          targetPoint.dx -
              arrowSize * math.cos(arrowAngle - math.pi / 5),
          targetPoint.dy -
              arrowSize * math.sin(arrowAngle - math.pi / 5),
        ),
        linePaint,
      );
      canvas.drawLine(
        targetPoint,
        Offset(
          targetPoint.dx -
              arrowSize * math.cos(arrowAngle + math.pi / 5),
          targetPoint.dy -
              arrowSize * math.sin(arrowAngle + math.pi / 5),
        ),
        linePaint,
      );
      canvas.drawCircle(
        targetPoint,
        math.max(3.0, baseFont * 0.15).toDouble(),
        targetPaint,
      );
      canvas.drawRRect(bubble, bubblePaint);
      canvas.drawRRect(bubble, bubbleBorder);

      void drawText(
        String text,
        double top,
        Color color,
        double fontSize,
        FontWeight weight,
      ) {
        if (text.trim().isEmpty) return;
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: weight,
              height: 1.05,
              fontFamilyFallback: _annotationFontFallback,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bubbleWidth - baseFont);
        painter.paint(
          canvas,
          Offset(bubbleLeft + baseFont * 0.5, bubbleTop + top),
        );
      }

      drawText(
        item.term,
        baseFont * 0.34,
        Colors.white,
        baseFont,
        FontWeight.w800,
      );
      drawText(
        item.pronunciation,
        baseFont * 1.35,
        const Color(0xffd7deeb),
        baseFont * 0.72,
        FontWeight.w600,
      );
      drawText(
        item.meaningVi,
        baseFont * 2.18,
        const Color(0xffffdf54),
        baseFont * 0.78,
        FontWeight.w700,
      );
    }

    final picture = recorder.endRecording();
    final output = await picture.toImage(outputWidth, outputHeight);
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    picture.dispose();
    source.dispose();
    codec.dispose();
    if (data == null) {
      throw Exception('Không thể tạo ảnh chú thích');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  String _displayNameForPicked(_PickedLearningImage picked) {
    final raw = p.basenameWithoutExtension(picked.name).trim();
    if (raw.isNotEmpty && !raw.startsWith('camera_')) return raw;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Ảnh ${two(now.day)}-${two(now.month)}-${now.year} '
        '${two(now.hour)}-${two(now.minute)}';
  }

  Future<void> _captureAndAnalyze() async {
    if (_processing) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initializeCamera();
      if (mounted && !(_cameraController?.value.isInitialized ?? false)) {
        showAppToast(context, 'Camera chưa sẵn sàng, hãy chọn ảnh có sẵn');
      }
      return;
    }
    try {
      final captured = await controller.takePicture();
      final bytes = await captured.readAsBytes();
      await _analyzePicked(
        _PickedLearningImage(
          bytes: bytes,
          name: 'camera_${DateTime.now().microsecondsSinceEpoch}.jpg',
          mimeType: _mimeTypeForName(captured.name),
        ),
      );
    } catch (error) {
      if (mounted) showAppToast(context, 'Không chụp được ảnh: $error');
    }
  }

  Future<void> _chooseAndAnalyze() async {
    if (_processing) return;
    final picked = await _pickFromFiles();
    if (picked != null) await _analyzePicked(picked);
  }

  Future<String> _analyzeWithPreferredModel(
    Uint8List bytes,
    String mimeType,
  ) async {
    try {
      return await GeminiFlashLiteClient.analyzeImage(
        _analysisPrompt(),
        imageBytes: bytes,
        mimeType: mimeType,
        modelOverride: _preferredVisionModel,
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      final modelUnavailable = message.contains('no longer available') ||
          message.contains('not found') ||
          message.contains('model') && message.contains('available');
      if (!modelUnavailable) rethrow;
      debugPrint(
        'PREFERRED IMAGE MODEL UNAVAILABLE, FALL BACK TO LATEST: $error',
      );
      return GeminiFlashLiteClient.analyzeImage(
        _analysisPrompt(),
        imageBytes: bytes,
        mimeType: mimeType,
        modelOverride: GeminiFlashLiteClient.defaultModel,
      );
    }
  }

  Future<void> _analyzePicked(_PickedLearningImage picked) async {
    if (_processing) return;
    if (!mounted) return;

    setState(() {
      _processing = true;
      _status = 'Đang đọc ảnh và nhận diện vật thể...';
    });
    try {
      final analysisBytes = await _analysisBytes(picked.bytes);
      final response = await _analyzeWithPreferredModel(
        analysisBytes,
        analysisBytes.length == picked.bytes.length
            ? picked.mimeType
            : 'image/png',
      );
      if (!mounted) return;
      setState(() => _status = 'Đang tạo ảnh chú thích...');
      final decoded = _decodeAnalysis(response);
      final rawItems = decoded['items'];
      if (rawItems is! List) {
        throw const FormatException('AI không trả về danh sách từ vựng');
      }
      final vocabulary = rawItems
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => ImageVocabularyDetection.fromJson(
              Map<String, dynamic>.from(entry.value),
              entry.key,
            ),
          )
          .where(
            (item) => item.term.isNotEmpty && item.meaningVi.isNotEmpty,
          )
          .take(20)
          .toList();
      if (vocabulary.isEmpty) {
        throw const FormatException('Không nhận diện được từ vựng trong ảnh');
      }
      final annotated = await _drawAnnotations(picked.bytes, vocabulary);
      final saved = await ImageLearningRepository.save(
        originalBytes: picked.bytes,
        annotatedBytes: annotated,
        originalExtension: p.extension(picked.name),
        languageCode: _selectedLanguage.code,
        languageName: _selectedLanguage.name,
        vocabulary: vocabulary,
        displayName: _displayNameForPicked(picked),
      );
      if (!mounted) return;
      setState(() {
        _entries.insert(0, saved);
        _currentIndex = 0;
        _showCamera = false;
        _showImageList = false;
        _status = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      });
      showAppToast(context, 'Đã nhận diện ${vocabulary.length} từ trong ảnh');
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Phân tích ảnh thất bại: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _status = '';
        });
      }
    }
  }

  Future<void> _saveAnnotatedImage(ImageLearningEntry entry) async {
    try {
      final bytes = await File(entry.annotatedPath).readAsBytes();
      final safeName = entry.displayName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final fileName =
          '${safeName.isEmpty ? 'hoc_anh_${entry.id}' : safeName}.png';
      final target = await FilePicker.saveFile(
        dialogTitle: 'Lưu ảnh đã chú thích',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
      if (target == null || !mounted) return;
      final targetFile = File(target);
      if (!await targetFile.exists()) {
        await targetFile.writeAsBytes(bytes, flush: true);
      }
      final savedName = p.basenameWithoutExtension(target).trim();
      if (savedName.isNotEmpty) {
        final updated = entry.copyWith(displayName: savedName);
        final index = _entries.indexWhere((item) => item.id == entry.id);
        if (index >= 0) {
          _entries[index] = updated;
          await ImageLearningRepository.update(_entries);
          if (mounted) setState(() {});
        }
      }
      if (mounted) showAppToast(context, 'Đã lưu ảnh vào máy với tên $savedName');
    } catch (error) {
      if (mounted) showAppToast(context, 'Không lưu được ảnh: $error');
    }
  }

  Future<_ImageCourseImportChoice?> _showCourseImportDialog(
    ImageLearningEntry entry,
  ) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'courses',
      columns: ['id', 'title'],
      where: 'deletedAt IS NULL',
      orderBy: 'lower(title) ASC',
    );
    final topicRows = await db.query(
      'topics',
      columns: ['id', 'name'],
      where: 'deletedAt IS NULL',
      orderBy: 'lower(name) ASC',
    );
    if (!mounted) return null;
    final titleController = TextEditingController(
      text:
          'Học ảnh ${entry.createdAt.day.toString().padLeft(2, '0')}-${entry.createdAt.month.toString().padLeft(2, '0')}',
    );
    var createNew = true;
    var courseSearchQuery = '';
    int? selectedCourseId =
        rows.isEmpty ? null : (rows.first['id'] as num?)?.toInt();
    int? selectedTopicId =
        topicRows.isEmpty ? null : (topicRows.first['id'] as num?)?.toInt();
    final result = await showDialog<_ImageCourseImportChoice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedCourseQuery =
                courseSearchQuery.trim().toLowerCase();
            final filteredCourseRows = normalizedCourseQuery.isEmpty
                ? rows
                : rows.where((row) {
                    final title =
                        row['title']?.toString().toLowerCase() ?? '';
                    return title.contains(normalizedCourseQuery);
                  }).toList();

            Widget modeTab({
              required bool value,
              required IconData icon,
              required String label,
            }) {
              final selected = createNew == value;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setDialogState(() => createNew = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected ? _blue : _panel2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? Icons.check_rounded : icon,
                          size: 16,
                          color: selected ? Colors.white : _muted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 2,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: selected ? Colors.white : _muted,
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: _panel,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              title: const Text(
                'Lưu từ vựng thành học phần',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: math
                    .min(420.0, MediaQuery.sizeOf(context).width - 72)
                    .toDouble(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _panel2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          modeTab(
                            value: true,
                            icon: Icons.add_rounded,
                            label: 'Học phần mới',
                          ),
                          const SizedBox(width: 3),
                          modeTab(
                            value: false,
                            icon: Icons.playlist_add_rounded,
                            label: 'Học phần có sẵn',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (createNew) ...[
                      if (topicRows.isNotEmpty)
                        DropdownButtonFormField<int>(
                          initialValue: selectedTopicId,
                          isExpanded: true,
                          dropdownColor: _panel2,
                          style: const TextStyle(color: _text),
                          decoration: const InputDecoration(
                            labelText: 'Chọn chủ đề',
                            labelStyle: TextStyle(color: _muted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _blue),
                            ),
                          ),
                          items: topicRows.map((row) {
                            return DropdownMenuItem<int>(
                              value: (row['id'] as num).toInt(),
                              child: Text(
                                row['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => selectedTopicId = value,
                        )
                      else
                        const Text(
                          'Chưa có chủ đề: app sẽ tạo chủ đề Học ảnh',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: titleController,
                          style: const TextStyle(color: _text),
                          decoration: const InputDecoration(
                            labelText: 'Tên học phần',
                            labelStyle: TextStyle(color: _muted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _blue),
                            ),
                          ),
                        ),
                    ] else if (rows.isEmpty)
                      const Text(
                        'Chưa có học phần để thêm vào',
                        style: TextStyle(color: _muted),
                      )
                    else ...[
                      TextField(
                        style: const TextStyle(color: _text),
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          final matches = query.isEmpty
                              ? rows
                              : rows.where((row) {
                                  final title = row['title']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  return title.contains(query);
                                }).toList();
                          setDialogState(() {
                            courseSearchQuery = value;
                            final keepsSelection = matches.any(
                              (row) =>
                                  (row['id'] as num?)?.toInt() ==
                                  selectedCourseId,
                            );
                            if (!keepsSelection) {
                              selectedCourseId = matches.isEmpty
                                  ? null
                                  : (matches.first['id'] as num).toInt();
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tìm kiếm học phần',
                          hintText: 'Nhập tên học phần...',
                          labelStyle: TextStyle(color: _muted),
                          hintStyle: TextStyle(color: _muted),
                          prefixIcon:
                              Icon(Icons.search_rounded, color: _muted),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filteredCourseRows.isEmpty)
                        const Text(
                          'Không tìm thấy học phần phù hợp',
                          style: TextStyle(color: _muted),
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            '$courseSearchQuery-$selectedCourseId',
                          ),
                          initialValue: selectedCourseId,
                          isExpanded: true,
                          dropdownColor: _panel2,
                          style: const TextStyle(color: _text),
                          decoration: const InputDecoration(
                            labelText: 'Chọn học phần',
                            labelStyle: TextStyle(color: _muted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _blue),
                            ),
                          ),
                          items: filteredCourseRows.map((row) {
                            return DropdownMenuItem<int>(
                              value: (row['id'] as num).toInt(),
                              child: Text(
                                row['title']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => selectedCourseId = value,
                        ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${entry.vocabulary.length} từ · ${entry.languageName}',
                      style: const TextStyle(color: _muted),
                    ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: _blue),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white54,
                  ),
                  onPressed: (!createNew && selectedCourseId == null)
                      ? null
                      : () {
                          final title = titleController.text.trim();
                          if (createNew && title.isEmpty) return;
                          Navigator.pop(
                            dialogContext,
                            _ImageCourseImportChoice(
                              createNew: createNew,
                              title: title,
                              courseId:
                                  createNew ? null : selectedCourseId,
                              topicId: createNew ? selectedTopicId : null,
                            ),
                          );
                        },
                  child: const Text('Lưu từ vựng'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    return result;
  }

  Future<void> _importVocabulary(ImageLearningEntry entry) async {
    final choice = await _showCourseImportDialog(entry);
    if (choice == null || !mounted) return;
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      var inserted = 0;
      await db.transaction((txn) async {
        int courseId;
        if (choice.createNew) {
          final topicId = choice.topicId ??
              await AppDatabase.instance.ensureActiveTopicByName(
                txn,
                name: 'Học ảnh',
                now: now,
              );
          courseId = await txn.insert('courses', {
            'topicId': topicId,
            'title': choice.title,
            'description': 'Từ vựng nhận diện bằng AI từ ảnh',
            'languageName': entry.languageName,
            'languageCode': entry.languageCode,
            'cardCount': 0,
            'isFavorite': 0,
            'isArchived': 0,
            'createdAt': now,
            'updatedAt': now,
          });
        } else {
          courseId = choice.courseId!;
        }

        final existingRows = await txn.query(
          'cards',
          columns: ['term', 'definition'],
          where: 'courseId = ? AND deletedAt IS NULL',
          whereArgs: [courseId],
        );
        final identities = existingRows
            .map(
              (row) =>
                  '${normalizeText(row['term']?.toString() ?? '')}|${normalizeText(row['definition']?.toString() ?? '')}',
            )
            .toSet();
        final positionRows = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), -1) AS maxPosition '
          'FROM cards WHERE courseId = ? AND deletedAt IS NULL',
          [courseId],
        );
        var position = _dbInt(positionRows.first['maxPosition']) + 1;
        for (final item in entry.vocabulary) {
          final identity =
              '${normalizeText(item.term)}|${normalizeText(item.meaningVi)}';
          if (identities.contains(identity)) continue;
          await txn.insert('cards', {
            'courseId': courseId,
            'term': item.term,
            'definition': item.meaningVi,
            'pronunciation': item.pronunciation,
            'rawText':
                '${item.term}\t${item.meaningVi}\t${item.pronunciation}',
            'inputFormat': 'image_ai',
            'note': 'Nhận diện từ ảnh bằng Gemini',
            'imagePath': entry.annotatedPath,
            'position': position++,
            'isFavorite': 0,
            'isHidden': 0,
            'createdAt': now,
            'updatedAt': now,
          });
          identities.add(identity);
          inserted++;
        }
        await txn.rawUpdate(
          '''
          UPDATE courses
          SET cardCount = (
                SELECT COUNT(*)
                FROM cards
                WHERE courseId = ?
                  AND deletedAt IS NULL
                  AND isHidden = 0
              ),
              updatedAt = ?
          WHERE id = ?
          ''',
          [courseId, now, courseId],
        );
      });
      if (SupabaseConfig.isLoggedIn) {
        unawaited(SupabaseSyncService.instance.syncPendingChanges());
      }
      if (!mounted) return;
      showAppToast(
        context,
        inserted == 0
            ? 'Các từ này đã có trong học phần'
            : 'Đã thêm $inserted từ vào học phần',
      );
    } catch (error) {
      if (mounted) showAppToast(context, 'Không lưu được học phần: $error');
    }
  }

  Future<void> _deleteEntry(ImageLearningEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Xóa ảnh?', style: TextStyle(color: _text)),
        content: const Text(
          'Ảnh gốc, ảnh chú thích và danh sách từ của ảnh này sẽ bị xóa.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final remaining = _entries.where((item) => item.id != entry.id).toList();
    await ImageLearningRepository.delete(entry, remaining);
    if (!mounted) return;
    setState(() {
      _entries = remaining;
      _currentIndex = _entries.isEmpty
          ? 0
          : _currentIndex.clamp(0, _entries.length - 1).toInt();
      if (_entries.isEmpty) {
        _showCamera = true;
        _showImageList = false;
      }
    });
  }

  Widget _bottomActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color color = _text,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        icon: Icon(
          icon,
          size: 23,
          color: onPressed == null ? _muted.withOpacity(0.45) : color,
        ),
      ),
    );
  }

  Future<void> _showZoomableImage(ImageLearningEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (zoomContext) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: const Color(0xee05070c),
              foregroundColor: Colors.white,
              title: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Center(
                    child: Text(
                      '',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            body: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8,
              trackpadScrollCausesScale: true,
              boundaryMargin: const EdgeInsets.all(180),
              clipBehavior: Clip.none,
              child: Center(
                child: Image.file(
                  File(entry.annotatedPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: _muted,
                    size: 58,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageCard(ImageLearningEntry entry, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        var page = _currentIndex.toDouble();
        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          page = _pageController.page ?? page;
        }
        final distance =
            (page - index).abs().clamp(0.0, 1.0).toDouble();
        final scale = 1 - distance * 0.055;
        final angle =
            (page - index).clamp(-1.0, 1.0).toDouble() * 0.018;
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _showZoomableImage(entry),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
              Image.file(
                File(entry.annotatedPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: _muted),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xc9000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${entry.languageName} · ${entry.vocabulary.length} từ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xc9000000),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVocabularyList(
    ImageLearningEntry entry, {
    double? height = 150,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  }) {
    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.7)),
      ),
      child: ListView.separated(
        itemCount: entry.vocabulary.length,
        separatorBuilder: (_, __) => Divider(
          color: _border.withOpacity(0.35),
          height: 12,
        ),
        itemBuilder: (context, index) {
          final item = entry.vocabulary[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.term,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                          fontFamilyFallback: _annotationFontFallback,
                        ),
                      ),
                      if (item.pronunciation.isNotEmpty)
                        TextSpan(
                          text: '  /${item.pronunciation}/',
                          style: const TextStyle(
                            color: _muted,
                            fontFamilyFallback: _annotationFontFallback,
                          ),
                        ),
                      TextSpan(
                        text: '\n${item.meaningVi}',
                        style: const TextStyle(
                          color: _yellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamilyFallback: _annotationFontFallback,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showVocabularyPopup(ImageLearningEntry entry) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.68),
      builder: (dialogContext) {
        final media = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          backgroundColor: _panel,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border),
          ),
          child: SizedBox(
            width: math.min(480.0, media.width - 36).toDouble(),
            height: math.min(560.0, media.height - 56).toDouble(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.style_rounded, color: _blue),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${entry.vocabulary.length} từ · ${entry.languageName}',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                    ],
                  ),
                ),
                const Divider(color: _border, height: 1),
                Expanded(
                  child: _buildVocabularyList(
                    entry,
                    height: null,
                    margin: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLanguageSettings() async {
    var selected = _selectedLanguageCode;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _panel,
              title: const Text(
                'Ngôn ngữ tạo từ vựng',
                style: TextStyle(color: _text),
              ),
              content: SizedBox(
                width: 430,
                height: 410,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI sẽ gọi tên mọi vật thể bằng ngôn ngữ bạn chọn.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: _languages.map((language) {
                          return RadioListTile<String>(
                            value: language.code,
                            groupValue: selected,
                            activeColor: _blue,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              language.name,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              language.code,
                              style: const TextStyle(color: _muted),
                            ),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selected = value);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _selectedLanguageCode = result);
    await AppSettingsStore.setString(_languageSettingKey, result);
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(
                child: CameraPreview(controller),
              )
            else
              Center(
                child: _cameraInitializing
                    ? const CircularProgressIndicator(color: _blue)
                    : Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.no_photography_outlined,
                              color: _yellow,
                              size: 54,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _cameraError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _initializeCamera,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại camera'),
                            ),
                          ],
                        ),
                      ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xd9000000),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _selectedLanguage.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_processing)
              Container(
                color: const Color(0xaa000000),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _yellow),
                      const SizedBox(height: 14),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openEntry(int index) {
    setState(() {
      _currentIndex = index;
      _showCamera = false;
      _showImageList = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  Widget _buildImageLibraryList() {
    if (_entries.isEmpty) {
      return const Center(
        child: Text('Chưa có ảnh đã lưu', style: TextStyle(color: _muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Material(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openEntry(index),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(entry.annotatedPath),
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${entry.languageName} · ${entry.vocabulary.length} từ',
                          style: const TextStyle(
                            color: _yellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatImageDate(entry.createdAt),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatImageDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildImageDeck() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
        final cardHeight =
            constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
        final verticalTouchFactor =
            (((_imageDragStartLocalY / _imageDragHeight) - 0.5)
                        .clamp(-0.5, 0.5) *
                    2)
                .toDouble();
        final dragPercent =
            (_imageDragDx / cardWidth).clamp(-1.0, 1.0).toDouble();
        final rotate = dragPercent * 0.35 * verticalTouchFactor;
        final movingBackward = _imageDragDx > 0;
        final peekIndex = movingBackward
            ? _currentIndex - 1
            : _currentIndex + 1;
        final idlePeekIndex = _currentIndex + 1 < _entries.length
            ? _currentIndex + 1
            : _currentIndex - 1;
        final effectivePeekIndex =
            _isDraggingImage ? peekIndex : idlePeekIndex;
        final farIndex = effectivePeekIndex + (movingBackward ? -1 : 1);

        void resetDrag() {
          setState(() {
            _isDraggingImage = false;
            _imageDragDx = 0;
            _imageDragDy = 0;
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _isDraggingImage = true;
              _imageDragDx = 0;
              _imageDragDy = 0;
              _imageDragHeight = cardHeight;
              _imageDragStartLocalY =
                  details.localPosition.dy.clamp(0.0, cardHeight).toDouble();
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _imageDragDx = (_imageDragDx + details.delta.dx)
                  .clamp(-cardWidth * 0.86, cardWidth * 0.86)
                  .toDouble();
              _imageDragDy = (_imageDragDy + details.delta.dy)
                  .clamp(-cardHeight * 0.34, cardHeight * 0.34)
                  .toDouble();
            });
          },
          onPanEnd: (details) {
            final velocityX = details.velocity.pixelsPerSecond.dx;
            final shouldSwipeLeft =
                _imageDragDx < -cardWidth * 0.28 || velocityX < -650;
            final shouldSwipeRight =
                _imageDragDx > cardWidth * 0.28 || velocityX > 650;
            final nextIndex = shouldSwipeLeft
                ? _currentIndex + 1
                : shouldSwipeRight
                    ? _currentIndex - 1
                    : _currentIndex;
            if (nextIndex >= 0 && nextIndex < _entries.length) {
              setState(() {
                _currentIndex = nextIndex;
                _isDraggingImage = false;
                _imageDragDx = 0;
                _imageDragDy = 0;
              });
            } else {
              resetDrag();
            }
          },
          onPanCancel: resetDrag,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (farIndex >= 0 &&
                  farIndex < _entries.length &&
                  farIndex != _currentIndex)
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, 16),
                    child: Transform.scale(
                      scale: 0.9,
                      child: Opacity(
                        opacity: 0.55,
                        child: _buildImageCard(_entries[farIndex], farIndex),
                      ),
                    ),
                  ),
                ),
              if (effectivePeekIndex >= 0 &&
                  effectivePeekIndex < _entries.length &&
                  effectivePeekIndex != _currentIndex)
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, 8),
                    child: Transform.scale(
                      scale: 0.96,
                      child: _buildImageCard(
                        _entries[effectivePeekIndex],
                        effectivePeekIndex,
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_imageDragDx, _imageDragDy),
                child: Transform.rotate(
                  angle: rotate,
                  child:
                      _buildImageCard(_entries[_currentIndex], _currentIndex),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryDetail(ImageLearningEntry entry) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildImageDeck(),
          ),
        ),
        SizedBox(
          height: 72,
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent ||
                  !_thumbnailScrollController.hasClients) {
                return;
              }
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (resolvedEvent) {
                  if (resolvedEvent is! PointerScrollEvent ||
                      !_thumbnailScrollController.hasClients) {
                    return;
                  }
                  final scrollDelta =
                      resolvedEvent.scrollDelta.dy.abs() >=
                              resolvedEvent.scrollDelta.dx.abs()
                          ? resolvedEvent.scrollDelta.dy
                          : resolvedEvent.scrollDelta.dx;
                  final position = _thumbnailScrollController.position;
                  final target =
                      (_thumbnailScrollController.offset + scrollDelta)
                          .clamp(
                            position.minScrollExtent,
                            position.maxScrollExtent,
                          )
                          .toDouble();
                  _thumbnailScrollController.jumpTo(target);
                },
              );
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _thumbnailScrollController,
                thumbVisibility: _entries.length > 4,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: ListView.separated(
                  controller: _thumbnailScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return InkWell(
                      onTap: () => setState(() => _currentIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: selected ? _blue : _border,
                            width: selected ? 2 : 1,
                          ),
                          image: DecorationImage(
                            image:
                                FileImage(File(_entries[index].annotatedPath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ImageLearningEntry? entry) {
    final showEntryActions =
        !_showCamera && !_showImageList && entry != null;
    VoidCallback? captureAction;
    if (!_processing) {
      captureAction = _showCamera
          ? _captureAndAnalyze
          : () {
              setState(() {
                _showCamera = true;
                _showImageList = false;
              });
              if (!(_cameraController?.value.isInitialized ?? false)) {
                _initializeCamera();
              }
            };
    }
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bottomActionIcon(
            icon: Icons.camera_alt_rounded,
            tooltip: _showCamera ? 'Chụp ảnh' : 'Mở camera',
            color: _blue,
            onPressed: captureAction,
          ),
          const SizedBox(width: 8),
          _bottomActionIcon(
            icon: Icons.add_photo_alternate_rounded,
            tooltip: 'Chọn ảnh',
            onPressed: _processing ? null : _chooseAndAnalyze,
          ),
          if (showEntryActions) ...[
            const SizedBox(width: 8),
            const SizedBox(
              height: 28,
              child: VerticalDivider(color: _border, width: 1),
            ),
            const SizedBox(width: 8),
            _bottomActionIcon(
              icon: Icons.style_rounded,
              tooltip: 'Từ vựng trong ảnh',
              color: _yellow,
              onPressed: () => _showVocabularyPopup(entry!),
            ),
            const SizedBox(width: 8),
            _bottomActionIcon(
              icon: Icons.download_rounded,
              tooltip: 'Lưu ảnh',
              onPressed: () => _saveAnnotatedImage(entry!),
            ),
            const SizedBox(width: 8),
            _bottomActionIcon(
              icon: Icons.library_add_rounded,
              tooltip: 'Lưu từ vựng',
              color: _blue,
              onPressed: () => _importVocabulary(entry!),
            ),
            const SizedBox(width: 8),
            _bottomActionIcon(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Xóa ảnh',
              color: Colors.redAccent,
              onPressed: () => _deleteEntry(entry!),
            ),
          ],
        ],
      ),
    );
  }

  void _handleBack() {
    if ((_showImageList || _showCamera) && _entries.isNotEmpty) {
      setState(() {
        _showImageList = false;
        _showCamera = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _currentEntry;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _text,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Học ảnh',
                      style: TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _entries.isEmpty
                        ? '0/0'
                        : '${_currentIndex + 1}/${_entries.length}',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Danh sách ảnh',
                    onPressed: _entries.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _showCamera = false;
                              _showImageList = !_showImageList;
                            });
                          },
                    icon: SvgPicture.asset(
                      'assets/icon/list-ol-solid-full.svg',
                      width: 19,
                      height: 19,
                      colorFilter: ColorFilter.mode(
                        _showImageList ? _blue : _text,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ngôn ngữ tạo từ vựng',
                    onPressed: _processing ? null : _showLanguageSettings,
                    icon: const Icon(Icons.settings_rounded, color: _text),
                  ),
                ],
              ),
            ),
            if (_processing && !_showCamera)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      color: _yellow,
                      backgroundColor: _panel2,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _showCamera
                  ? _buildCameraView()
                  : _showImageList
                      ? _buildImageLibraryList()
                      : _loading
                          ? const Center(
                              child: CircularProgressIndicator(color: _blue),
                            )
                          : entry == null
                              ? const Center(
                                  child: Text(
                                    'Chưa có ảnh đã phân tích',
                                    style: TextStyle(color: _muted),
                                  ),
                                )
                              : _buildLibraryDetail(entry),
            ),
            _buildBottomControls(entry),
          ],
        ),
      ),
    );
  }
}
