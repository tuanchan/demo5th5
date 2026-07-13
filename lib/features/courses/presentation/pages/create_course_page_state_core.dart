part of flutterflashcard_main;

class _CreateCoursePageState extends State<CreateCoursePage> {
  String termSeparatorType = "tab";
  String cardSeparatorType = "newline";
  String selectedLanguage = "Tiếng Trung Phồn thể (Traditional Chinese)";
  List<CourseTopicItem> availableTopics = [];
  int? selectedTopicId;

  bool showPreview = false;
  List<FlashCardItem> previewItems = [];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  final TextEditingController customTermSepController = TextEditingController(
    text: "|",
  );
  final TextEditingController customCardSepController = TextEditingController(
    text: "###",
  );

  @override
  void initState() {
    super.initState();
    selectedTopicId = widget.initialTopicId;
    this.loadCreateCourseSettings();
  }

  @override
  void dispose() {
    titleController.dispose();
    dataController.dispose();
    customTermSepController.dispose();
    customCardSepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return this._buildCreateCoursePagePage(context);
  }
}
