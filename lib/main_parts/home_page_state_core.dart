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

class _HomePageState extends State<HomePage> {
  bool isOpen = false;
  double _homeDragStartX = 0;
  bool _openedByEdgeSwipe = false;

  bool isLoadingCourses = false;
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
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case "za":
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
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
