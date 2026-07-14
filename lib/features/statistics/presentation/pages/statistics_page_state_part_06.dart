part of flutterflashcard_main;

extension StatisticsPageStatePart06 on _StatisticsPageState {
  Widget _buildDueReviewButton(StatisticsData data) {
    final dueToday = data.dueScheduleItems.isEmpty
        ? 0
        : data.dueScheduleItems.first.count;

    return GestureDetector(
      onTap: () async {
        await _openDueReviewFlow(context);
        if (mounted) this.reloadStatistics();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: dueToday > 0 ? _dashBlue : _dashPanel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _dashBorder.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: _dashBorder.withOpacity(0.22),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Ôn những thẻ đến hạn',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _dashText,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildDueItem(ReviewDueItem item) {
    final intervalText = item.intervalDays > 0
        ? ' • ngày ${item.intervalDays}'
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.level >= ReviewScheduler.masteredLevel
                  ? AppColors.green
                  : (item.level > 0 ? AppColors.yellow : AppColors.red),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'L${item.level}',
                style: TextStyle(
                  color: AppColors.border,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${item.definition} • ${item.courseTitle} • ôn ${item.repetitionCount} lần$intervalText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<List<_SrsEditorItem>> _loadSrsEditorItems() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        ca.id AS cardId,
        c.id AS courseId,
        ca.term,
        ca.definition,
        ca.pronunciation,
        c.title AS courseTitle,
        c.languageCode,
        COALESCE(rs.level, 0) AS level,
        COALESCE(rs.easeFactor, 2.5) AS easeFactor,
        COALESCE(rs.intervalDays, 0) AS intervalDays,
        COALESCE(rs.repetitionCount, 0) AS repetitionCount,
        COALESCE(rs.correctCount, 0) AS correctCount,
        COALESCE(rs.wrongCount, 0) AS wrongCount,
        COALESCE(rs.lastReviewedAt, '') AS lastReviewedAt,
        COALESCE(rs.nextReviewAt, '') AS nextReviewAt
      FROM cards ca
      INNER JOIN courses c ON c.id = ca.courseId
      LEFT JOIN review_states rs ON rs.cardId = ca.id
      WHERE ca.deletedAt IS NULL
        AND ca.isHidden = 0
        AND c.deletedAt IS NULL
      ORDER BY
        CASE WHEN rs.nextReviewAt IS NULL OR rs.nextReviewAt = '' THEN 1 ELSE 0 END,
        rs.nextReviewAt ASC,
        COALESCE(rs.level, 0) DESC,
        c.title ASC,
        ca.position ASC,
        ca.id ASC
    ''');

    return rows.map(_SrsEditorItem.fromMap).toList();
  }
}
