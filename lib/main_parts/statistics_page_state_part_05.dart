part of flutterflashcard_main;

extension StatisticsPageStatePart05 on _StatisticsPageState {
  Widget _buildChartPanel(StatisticsData data) {
    final correct = data.totalCorrect;
    final wrong = data.totalWrong;
    final maxValue = math.max(1, math.max(correct, wrong));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.query_stats_rounded, color: AppColors.border),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kết quả luyện tập',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Độ chính xác ${data.accuracyPercent}% • ${data.totalAnswered} lượt trả lời',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          this._buildBarRow('Đúng', correct, maxValue, AppColors.green),
          SizedBox(height: 12),
          this._buildBarRow('Sai', wrong, maxValue, AppColors.red),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.accuracyPercent / 100,
              minHeight: 14,
              backgroundColor: AppColors.bg,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBarRow(String label, int value, int maxValue, Color color) {
    final widthFactor = (value / maxValue).clamp(0.04, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withOpacity(0.25)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCourseProgress(StatisticsData data) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiến độ từng học phần',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          if (data.courseItems.isEmpty)
            this._buildEmptyBox('Chưa có học phần nào')
          else
            ...data.courseItems.map(_buildCourseProgressItem),
        ],
      ),
    );
  }


  Widget _buildCourseProgressItem(CourseStatisticsItem item) {
    final isExpanded = _expandedCourseIds.contains(item.id);
    final masteredText = item.masteredTodayCards > 0
        ? ' • Đã thuộc: ${item.masteredTodayCards}'
        : '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedCourseIds.remove(item.id);
          } else {
            _expandedCourseIds.add(item.id);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${item.progressPercent}%',
                    style: TextStyle(
                      color: AppColors.border,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: Duration(milliseconds: 160),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.border,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Hôm nay: ${item.reviewedTodayCards} thẻ đã ôn$masteredText',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Cần ôn: ${item.needReviewCards} • Tiến độ: ${item.masteredCards}/${item.totalCards} • ${item.languageCode}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted.withOpacity(0.86),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: item.progressPercent / 100,
                minHeight: 12,
                backgroundColor: Colors.white,
                color: AppColors.green,
              ),
            ),
            AnimatedCrossFade(
              firstChild: SizedBox.shrink(),
              secondChild: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    this._buildCourseChip(
                      icon: Icons.check_rounded,
                      text: 'Đúng ${item.correctCount}',
                      color: AppColors.green,
                    ),
                    this._buildCourseChip(
                      icon: Icons.close_rounded,
                      text: 'Sai ${item.wrongCount}',
                      color: AppColors.red,
                    ),
                    this._buildCourseChip(
                      icon: Icons.event_note_rounded,
                      text: '${item.sessionCount} buổi',
                      color: AppColors.blue,
                    ),
                    this._buildCourseChip(
                      icon: Icons.workspace_premium_rounded,
                      text: 'Thuộc cấp ${ReviewScheduler.masteredLevel}+',
                      color: AppColors.yellow,
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCourseChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withOpacity(0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.border),
          SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: AppColors.border,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDueCards(StatisticsData data) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.replay_circle_filled_rounded, color: AppColors.border),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thẻ cần ôn lại',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (data.dueItems.isEmpty)
            this._buildEmptyBox('Chưa có thẻ cần ôn, quá ổn')
          else
            ...data.dueItems.map(_buildDueItem),
        ],
      ),
    );
  }

}
