part of flutterflashcard_main;

Widget _dueSolidButton({
  required String text,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.onSolidButton, size: 20),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSolidButton,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}





Widget _dueOutlineButton({
  required String text,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.onIconButton, size: 20),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onIconButton,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}





class _SrsEditorItem {
  final int cardId;
  final int courseId;
  final String term;
  final String definition;
  final String courseTitle;
  final String languageCode;
  final int level;
  final double easeFactor;
  final int intervalDays;
  final int repetitionCount;
  final int correctCount;
  final int wrongCount;
  final String lastReviewedAt;
  final String nextReviewAt;

  _SrsEditorItem({
    required this.cardId,
    required this.courseId,
    required this.term,
    required this.definition,
    required this.courseTitle,
    required this.languageCode,
    required this.level,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.lastReviewedAt,
    required this.nextReviewAt,
  });

  factory _SrsEditorItem.fromMap(Map<String, Object?> map) {
    return _SrsEditorItem(
      cardId: _dbInt(map['cardId']),
      courseId: _dbInt(map['courseId']),
      term: map['term']?.toString() ?? '',
      definition: map['definition']?.toString() ?? '',
      courseTitle: map['courseTitle']?.toString() ?? '',
      languageCode: map['languageCode']?.toString() ?? '',
      level: _dbInt(map['level']),
      easeFactor: _dbDouble(map['easeFactor'], 2.5),
      intervalDays: _dbInt(map['intervalDays']),
      repetitionCount: _dbInt(map['repetitionCount']),
      correctCount: _dbInt(map['correctCount']),
      wrongCount: _dbInt(map['wrongCount']),
      lastReviewedAt: map['lastReviewedAt']?.toString() ?? '',
      nextReviewAt: map['nextReviewAt']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'cardId': cardId,
      'courseId': courseId,
      'term': term,
      'definition': definition,
      'courseTitle': courseTitle,
      'languageCode': languageCode,
      'level': level,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'repetitionCount': repetitionCount,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'lastReviewedAt': lastReviewedAt,
      'nextReviewAt': nextReviewAt,
    };
  }
}





class _SrsEditorCourse {
  final int id;
  final String title;
  final String languageCode;
  final int cardCount;
  final int reviewedCount;
  final int dueCount;

  _SrsEditorCourse({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.cardCount,
    required this.reviewedCount,
    required this.dueCount,
  });
}
