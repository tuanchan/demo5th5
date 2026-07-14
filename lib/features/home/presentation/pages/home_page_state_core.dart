part of flutterflashcard_main;

const String _courseSortSettingKey = 'home.courseSortType';
const String _courseLanguageFilterSettingKey =
    'home.courseLanguageFilter';
const Set<String> _courseSortTypes = {
  'updatedDesc',
  'az',
  'za',
  'cardsDesc',
  'cardsAsc',
};

int _naturalCompareText(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  final pattern = RegExp(r'\d+|\D+');
  final leftParts = pattern.allMatches(left).map((m) => m.group(0)!).toList();
  final rightParts = pattern.allMatches(right).map((m) => m.group(0)!).toList();
  final length = math.min(leftParts.length, rightParts.length);

  for (var i = 0; i < length; i++) {
    final leftPart = leftParts[i];
    final rightPart = rightParts[i];
    final leftIsNumber = int.tryParse(leftPart) != null;
    final rightIsNumber = int.tryParse(rightPart) != null;

    if (leftIsNumber && rightIsNumber) {
      final leftNumber = leftPart.replaceFirst(RegExp(r'^0+'), '');
      final rightNumber = rightPart.replaceFirst(RegExp(r'^0+'), '');
      final normalizedLeft = leftNumber.isEmpty ? '0' : leftNumber;
      final normalizedRight = rightNumber.isEmpty ? '0' : rightNumber;

      final lengthCompare = normalizedLeft.length.compareTo(
        normalizedRight.length,
      );
      if (lengthCompare != 0) return lengthCompare;

      final numberCompare = normalizedLeft.compareTo(normalizedRight);
      if (numberCompare != 0) return numberCompare;

      final zeroCompare = leftPart.length.compareTo(rightPart.length);
      if (zeroCompare != 0) return zeroCompare;
      continue;
    }

    final partCompare = leftPart.compareTo(rightPart);
    if (partCompare != 0) return partCompare;
  }

  final partCountCompare = leftParts.length.compareTo(rightParts.length);
  if (partCountCompare != 0) return partCountCompare;

  return left.compareTo(right);
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool isOpen = false;
  bool _isHomeNavExpanded = false;
  late final AnimationController _homeLogoAnimation;
  final ScrollController _homeCourseScrollController = ScrollController();
  final ScrollController _homeTopicScrollController = ScrollController();
  late final StreamSubscription<SyncResult> _homeSyncSubscription;
  final GlobalKey _homeCourseViewportKey = GlobalKey();
  final GlobalKey _homeBackCardKey = GlobalKey();
  final GlobalKey _homeFirstCourseCardKey = GlobalKey();
  final GlobalKey _homeTopicViewportKey = GlobalKey();
  final GlobalKey _homeCreateTopicCardKey = GlobalKey();
  int _homeCoursePage = 1;
  bool _showFloatingTopicBack = false;
  bool _homeCourseAtBottom = false;
  bool _showFloatingTopicTop = false;
  double _homeDragStartX = 0;
  bool _openedByEdgeSwipe = false;

  bool isLoadingCourses = false;
  bool _duePopupShown = false;
  List<CourseTopicItem> topics = [];
  List<CourseListItem> courses = [];
  CourseTopicItem? _activeHomeTopic;
  CourseListItem? selectedHomeCourse;
  String courseSortType = "updatedDesc";
  String courseLanguageFilter = "all";
  final Set<int> expandedTopicIds = {};


  List<String> get courseLanguageFilters {
    final languages = courses
        .map((course) => course.languageCode.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
    languages.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return languages;
  }

  List<CourseListItem> get visibleCourses {
    final keyword = courseSearchController.text.trim().toLowerCase();
    final filtered = courses.where((course) {
      final courseLanguage = course.languageCode.trim();
      final matchesLanguage =
          courseLanguageFilter == "all" ||
          courseLanguage.toLowerCase() == courseLanguageFilter.toLowerCase();

      if (!matchesLanguage) return false;
      if (keyword.isEmpty) return true;

      return course.title.toLowerCase().contains(keyword) ||
          courseLanguage.toLowerCase().contains(keyword) ||
          this.languageNameFromCode(courseLanguage).toLowerCase().contains(keyword);
    }).toList();

    switch (courseSortType) {
      case "az":
        filtered.sort(
          (a, b) => _naturalCompareText(a.title, b.title),
        );
        break;
      case "za":
        filtered.sort(
          (a, b) => _naturalCompareText(b.title, a.title),
        );
        break;
      case "cardsDesc":
        filtered.sort((a, b) => b.cardCount.compareTo(a.cardCount));
        break;
      case "cardsAsc":
        filtered.sort((a, b) => a.cardCount.compareTo(b.cardCount));
        break;
      default:
        break;
    }

    return filtered;
  }

  List<CourseTopicItem> get visibleTopics {
    final keyword = courseSearchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      final allTopics = topics.toList();
      this.sortVisibleTopics(allTopics);
      return allTopics;
    }

    final topicIds = visibleCourses
        .map((course) => course.topicId)
        .whereType<int>()
        .toSet();
    final filtered = topics.where((topic) {
      return topic.name.toLowerCase().contains(keyword) ||
          topicIds.contains(topic.id);
    }).toList();
    this.sortVisibleTopics(filtered);
    return filtered;
  }

  void sortVisibleTopics(List<CourseTopicItem> items) {
    switch (courseSortType) {
      case "az":
        items.sort((a, b) => _naturalCompareText(a.name, b.name));
        break;
      case "za":
        items.sort((a, b) => _naturalCompareText(b.name, a.name));
        break;
      case "cardsDesc":
        items.sort((a, b) {
          final compare = b.cardCount.compareTo(a.cardCount);
          return compare != 0 ? compare : _naturalCompareText(a.name, b.name);
        });
        break;
      case "cardsAsc":
        items.sort((a, b) {
          final compare = a.cardCount.compareTo(b.cardCount);
          return compare != 0 ? compare : _naturalCompareText(a.name, b.name);
        });
        break;
      default:
        items.sort((a, b) {
          final compare = b.latestCourseAt.compareTo(a.latestCourseAt);
          return compare != 0 ? compare : _naturalCompareText(a.name, b.name);
        });
        break;
    }
  }

  List<CourseListItem> visibleCoursesForTopic(int topicId) {
    final keyword = courseSearchController.text.trim().toLowerCase();
    final filtered = courses.where((course) {
      if (course.topicId != topicId) return false;
      if (keyword.isEmpty) return true;

      final courseLanguage = course.languageCode.trim();
      return course.title.toLowerCase().contains(keyword) ||
          courseLanguage.toLowerCase().contains(keyword) ||
          this.languageNameFromCode(courseLanguage).toLowerCase().contains(keyword);
    }).toList();

    switch (courseSortType) {
      case "az":
        filtered.sort((a, b) => _naturalCompareText(a.title, b.title));
        break;
      case "za":
        filtered.sort((a, b) => _naturalCompareText(b.title, a.title));
        break;
      case "cardsDesc":
        filtered.sort((a, b) => b.cardCount.compareTo(a.cardCount));
        break;
      case "cardsAsc":
        filtered.sort((a, b) => a.cardCount.compareTo(b.cardCount));
        break;
      default:
        break;
    }

    return filtered;
  }

  String get courseSortLabel {
    switch (courseSortType) {
      case "az":
        return "A-Z";
      case "za":
        return "Z-A";
      case "cardsDesc":
        return "Nhiều thẻ";
      case "cardsAsc":
        return "Ít thẻ";
      default:
        return "Mới nhất";
    }
  }

  final TextEditingController courseSearchController = TextEditingController();

  List<DropdownMenuItem<String>> buildLanguageItems() {
    return [
      DropdownMenuItem(
        value: "Tiếng Trung Phồn thể (Traditional Chinese)",
        child: Text("Tiếng Trung Phồn thể"),
      ),
      DropdownMenuItem(
        value: "Tiếng Trung Giản thể (Simplified Chinese)",
        child: Text("Tiếng Trung Giản thể"),
      ),
      DropdownMenuItem(value: "Tiếng Anh (English)", child: Text("Tiếng Anh")),
      DropdownMenuItem(value: "Tiếng Đức (German)", child: Text("Tiếng Đức")),
      DropdownMenuItem(
        value: "Tiếng Nhật (Japanese)",
        child: Text("Tiếng Nhật"),
      ),
      DropdownMenuItem(value: "Tiếng Hàn (Korean)", child: Text("Tiếng Hàn")),
      DropdownMenuItem(
        value: "Tiếng Việt (Vietnamese)",
        child: Text("Tiếng Việt"),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _homeSyncSubscription = SupabaseSyncService.instance.syncCompleted.listen(
      (_) {
        if (mounted) this.loadCourses();
      },
    );
    _homeLogoAnimation = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();
    _homeCourseScrollController.addListener(() {
      if (!_homeCourseScrollController.hasClients) return;
      final offset = _homeCourseScrollController.offset;
      final atBottom =
          _homeCourseScrollController.position.extentAfter <= 8;
      var shouldShowBack = offset >= 390;
      final backBox = _homeBackCardKey.currentContext?.findRenderObject();
      final viewportBox =
          _homeCourseViewportKey.currentContext?.findRenderObject();
      if (backBox is RenderBox && viewportBox is RenderBox) {
        final backBottom =
            backBox.localToGlobal(Offset(0, backBox.size.height)).dy;
        final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
        shouldShowBack = backBottom <= viewportTop;
      }
      if (mounted &&
          (shouldShowBack != _showFloatingTopicBack ||
              atBottom != _homeCourseAtBottom)) {
        setState(() {
          _showFloatingTopicBack = shouldShowBack;
          _homeCourseAtBottom = atBottom;
        });
      }
    });
    _homeTopicScrollController.addListener(() {
      if (!_homeTopicScrollController.hasClients) return;
      var shouldShow = _homeTopicScrollController.offset >= 390;
      final createCardBox =
          _homeCreateTopicCardKey.currentContext?.findRenderObject();
      final viewportBox =
          _homeTopicViewportKey.currentContext?.findRenderObject();
      if (createCardBox is RenderBox && viewportBox is RenderBox) {
        final cardBottom = createCardBox
            .localToGlobal(Offset(0, createCardBox.size.height))
            .dy;
        final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
        shouldShow = cardBottom <= viewportTop;
      }
      if (mounted && shouldShow != _showFloatingTopicTop) {
        setState(() => _showFloatingTopicTop = shouldShow);
      }
    });
    this.loadInitialCourses();
  }

  @override
  void dispose() {
    _homeSyncSubscription.cancel();
    _homeLogoAnimation.dispose();
    _homeCourseScrollController.dispose();
    _homeTopicScrollController.dispose();
    courseSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildHomePagePage(context);
  }
}
