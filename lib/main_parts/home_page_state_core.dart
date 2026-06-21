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

class _HomePageState extends State<HomePage> {
  bool isOpen = false;
  double _homeDragStartX = 0;
  bool _openedByEdgeSwipe = false;

  bool isLoadingCourses = false;
  bool _duePopupShown = false;
  List<CourseListItem> courses = [];
  CourseListItem? selectedHomeCourse;
  String courseSortType = "updatedDesc";
  String courseLanguageFilter = "all";


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

  @override
  void initState() {
    super.initState();
    this.loadInitialCourses();
  }

  @override
  void dispose() {
    courseSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildHomePagePage(context);
  }
}
