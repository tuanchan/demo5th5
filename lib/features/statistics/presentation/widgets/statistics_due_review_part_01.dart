part of flutterflashcard_main;

const Color _dueDialogBackground = Color(0xff07090d);
const Color _dueDialogSurface = Color(0xff0b0d12);
const Color _dueDialogBorder = Color(0xff202634);
const Color _dueDialogText = Color(0xfff8fbff);
const Color _dueDialogMuted = Color(0xff91a0bd);
const Color _dueDialogBlue = Color(0xff9ab9ff);

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

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReviewPracticePage(
        courseId: info.courseId,
        courseTitle: 'Ôn thẻ đến hạn hôm nay',
        courseLanguageCode: info.languageCode,
        dueOnly: true,
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
    barrierColor: Color(0xb3000000),
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
                color: _dueDialogBlue,
                size: 54,
              ),
              SizedBox(height: 10),
              Text(
                'Hôm nay có ${info.count} thẻ đến hạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _dueDialogText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có thể học flash card hoặc chọn kiểu kiểm tra để ôn ngay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _dueDialogMuted,
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
    barrierColor: Color(0xb3000000),
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
                            color: _dueDialogMuted,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Chọn cách ôn tập',
                          style: TextStyle(
                            color: _dueDialogText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close_rounded, color: _dueDialogMuted),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _dueActionTile(
                title: 'Học thẻ',
                subtitle: 'Mở màn hình flash card chỉ gồm thẻ đến hạn.',
                icon: Icons.style_rounded,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.flash),
              ),
              Divider(color: _dueDialogBorder, height: 1),
              _dueActionTile(
                title: 'Ôn tập',
                subtitle: 'Mở thiết lập kiểm tra SRS cho thẻ đến hạn.',
                icon: Icons.school_rounded,
                onTap: () => Navigator.pop(dialogContext, _DueStudyAction.review),
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
    color: _dueDialogBackground,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: _dueDialogBorder, width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 14),
        blurRadius: 30,
      ),
    ],
  );
}





Widget _dueActionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 15),
      child: Row(
        children: [
          Icon(icon, color: _dueDialogBlue, size: 25),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _dueDialogText,
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
                    color: _dueDialogMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: _dueDialogBlue),
        ],
      ),
    ),
  );
}
