part of flutterflashcard_main;

class _DueReviewLaunchInfo {
  final int count;
  final int courseId;
  final String courseTitle;
  final String languageCode;

  _DueReviewLaunchInfo({
    required this.count,
    required this.courseId,
    required this.courseTitle,
    required this.languageCode,
  });
}





enum _DueStudyAction { flash, review }





Future<_DueReviewLaunchInfo?> _loadDueReviewLaunchInfo() async {
  final db = await AppDatabase.instance.database;
  final now = DateTime.now();
  final tomorrowStart = DateTime(now.year, now.month, now.day).add(
    getDuration(days: 1),
  );
  final dueBefore = tomorrowStart.toIso8601String();

  final countRows = await db.rawQuery(
    '''
    SELECT COUNT(*) AS count
    FROM cards ca
    INNER JOIN courses c ON c.id = ca.courseId
    INNER JOIN review_states rs ON rs.cardId = ca.id
    WHERE ca.deletedAt IS NULL
      AND ca.isHidden = 0
      AND c.deletedAt IS NULL
      AND COALESCE(rs.repetitionCount, 0) > 0
      AND rs.nextReviewAt IS NOT NULL
      AND rs.nextReviewAt < ?
    ''',
    [dueBefore],
  );

  final count = countRows.isEmpty ? 0 : _dbInt(countRows.first['count']);
  if (count <= 0) return null;

  final firstRows = await db.rawQuery(
    '''
    SELECT
      ca.courseId,
      c.title AS courseTitle,
      c.languageCode
    FROM cards ca
    INNER JOIN courses c ON c.id = ca.courseId
    INNER JOIN review_states rs ON rs.cardId = ca.id
    WHERE ca.deletedAt IS NULL
      AND ca.isHidden = 0
      AND c.deletedAt IS NULL
      AND COALESCE(rs.repetitionCount, 0) > 0
      AND rs.nextReviewAt IS NOT NULL
      AND rs.nextReviewAt < ?
    ORDER BY
      rs.nextReviewAt ASC,
      ca.position ASC,
      ca.id ASC
    LIMIT 1
    ''',
    [dueBefore],
  );

  if (firstRows.isEmpty) return null;
  final row = firstRows.first;

  return _DueReviewLaunchInfo(
    count: count,
    courseId: _dbInt(row['courseId']),
    courseTitle: row['courseTitle']?.toString() ?? '',
    languageCode: row['languageCode']?.toString() ?? 'zh-TW',
  );
}





Future<void> _openDueReviewFlow(
  BuildContext context, {
  _DueReviewLaunchInfo? initialInfo,
}) async {
  final info = initialInfo ?? await _loadDueReviewLaunchInfo();
  if (!context.mounted) return;

  if (info == null || info.count <= 0) {
    showAppToast(context, 'Hôm nay chưa có thẻ đến hạn');
    return;
  }

  final action = await _showDueStudyTypeDialog(context, info);
  if (!context.mounted || action == null) return;

  if (action == _DueStudyAction.flash) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashCardsPage(
          courseId: info.courseId,
          courseTitle: 'Thẻ đến hạn hôm nay',
          dueOnly: true,
        ),
      ),
    );
    return;
  }

  final presetMode = await _showDueReviewModeDialog(context);
  if (!context.mounted || presetMode == null) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReviewPracticePage(
        courseId: info.courseId,
        courseTitle: 'Ôn thẻ đến hạn hôm nay',
        courseLanguageCode: info.languageCode,
        dueOnly: true,
        presetMode: presetMode,
      ),
    ),
  );
}





Future<bool?> _showDueTodayReminderDialog(
  BuildContext context,
  _DueReviewLaunchInfo info,
) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 430),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: _dueDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: AppColors.border,
                size: 54,
              ),
              SizedBox(height: 10),
              Text(
                'Hôm nay có ${info.count} thẻ đến hạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có thể học flash card hoặc chọn kiểu kiểm tra để ôn ngay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _dueOutlineButton(
                      text: 'Đóng',
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _dueSolidButton(
                      text: 'Ôn tập',
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.green,
                      onTap: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}





Future<_DueStudyAction?> _showDueStudyTypeDialog(
  BuildContext context,
  _DueReviewLaunchInfo info,
) async {
  return showDialog<_DueStudyAction>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 460),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: _dueDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${info.count} thẻ đến hạn hôm nay',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Chọn cách ôn tập',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close_rounded, color: AppColors.border),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _dueActionTile(
                title: 'Học thẻ',
                subtitle: 'Mở màn hình flash card chỉ gồm thẻ đến hạn.',
                icon: Icons.style_rounded,
                color: AppColors.yellow,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.flash),
              ),
              SizedBox(height: 12),
              _dueActionTile(
                title: 'Ôn tập',
                subtitle: 'Chọn phương thức kiểm tra cho thẻ đến hạn.',
                icon: Icons.school_rounded,
                color: AppColors.green,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.review),
              ),
            ],
          ),
        ),
      );
    },
  );
}





Future<String?> _showDueReviewModeDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: _dueDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn phương thức kiểm tra',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close_rounded, color: AppColors.border),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _dueActionTile(
                title: 'Trắc nghiệm 4 đáp án',
                subtitle: 'Chọn đáp án đúng cho từng thẻ.',
                icon: Icons.checklist_rounded,
                color: AppColors.blue,
                onTap: () => Navigator.pop(dialogContext, 'multipleChoice'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Tự luận',
                subtitle: 'Gõ câu trả lời rồi kiểm tra kết quả.',
                icon: Icons.edit_note_rounded,
                color: AppColors.green,
                onTap: () => Navigator.pop(dialogContext, 'essay'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Nghe',
                subtitle: 'Nghe âm thanh và chọn đáp án.',
                icon: Icons.hearing_rounded,
                color: AppColors.yellow,
                onTap: () => Navigator.pop(dialogContext, 'listening'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Kiểm tra cặp thẻ',
                subtitle: 'Ghép cặp từ vựng với nghĩa phù hợp.',
                icon: Icons.grid_view_rounded,
                color: AppColors.blue,
                onTap: () => Navigator.pop(dialogContext, 'matchingPairs'),
              ),
              SizedBox(height: 10),
              _dueActionTile(
                title: 'Kiểm tra tổng hợp',
                subtitle: 'Học tập với các dạng bài trắc nghiệm, tự luận và nghe.',
                icon: Icons.dashboard_customize_rounded,
                color: AppColors.red,
                onTap: () => Navigator.pop(dialogContext, 'sentence'),
              ),
            ],
          ),
        ),
      );
    },
  );
}


BoxDecoration _dueDialogDecoration() {
  return BoxDecoration(
    color: Color(0xfff6f1fb),
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: AppColors.border, width: 1.4),
    boxShadow: [
      BoxShadow(color: AppColors.border, offset: Offset(0, 7), blurRadius: 0),
      BoxShadow(
        color: Color(0x26000000),
        offset: Offset(0, 18),
        blurRadius: 28,
      ),
    ],
  );
}





Widget _dueActionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.3),
        boxShadow: [
          BoxShadow(color: AppColors.border, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: Icon(icon, color: AppColors.border, size: 23),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppColors.border),
        ],
      ),
    ),
  );
}
