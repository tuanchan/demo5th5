part of flutterflashcard_main;

extension StatisticsPageStatePart01 on _StatisticsPageState {
  Widget _buildStatisticsPagePage(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashBg,
      body: SafeArea(
        child: FutureBuilder<StatisticsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _dashBlue));
            }

            if (snapshot.hasError) {
              return this._buildError(snapshot.error.toString());
            }

            final data = snapshot.data;
            if (data == null) return this._buildError('Không có dữ liệu thống kê');

            return RefreshIndicator(
              onRefresh: () async => this.reloadStatistics(),
              color: _dashBlue,
              backgroundColor: _dashPanel,
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 26),
                      child: this._buildDashboard(data),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }


  String _languageLabelFromCode(String code) {
    switch (code) {
      case 'en-US':
        return 'Tiếng Anh (English)';
      case 'zh-CN':
        return 'Tiếng Trung giản thể';
      case 'de-DE':
        return 'Tiếng Đức (German)';
      case 'ja-JP':
        return 'Tiếng Nhật (Japanese)';
      case 'ko-KR':
        return 'Tiếng Hàn (Korean)';
      case 'vi-VN':
        return 'Tiếng Việt (Vietnamese)';
      case 'zh-TW':
      default:
        return 'Tiếng Trung phồn thể';
    }
  }


  Color _languageColor(int index) {
    const colors = [
      _dashBlue,
      _dashPurple,
      _dashGreen,
      _dashOrange,
      Color(0xff2dd4bf),
      Color(0xfff472b6),
    ];
    return colors[index % colors.length];
  }


  Future<void> _purgeSoftDeletedCourses(Database db) async {
    final rows = await db.query(
      'courses',
      columns: ['id'],
      where: 'deletedAt IS NOT NULL',
    );

    if (rows.isEmpty) return;

    final ids = rows
        .map((row) => this._asInt(row['id']))
        .where((id) => id > 0)
        .toList();

    if (ids.isEmpty) return;

    await db.transaction((txn) async {
      for (final courseId in ids) {
        await txn.delete(
          'study_results',
          where:
              'sessionId IN (SELECT id FROM study_sessions WHERE courseId = ?) OR cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId, courseId],
        );
        await txn.delete(
          'study_sessions',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'review_states',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId],
        );
        await txn.delete(
          'card_examples',
          where: 'cardId IN (SELECT id FROM cards WHERE courseId = ?)',
          whereArgs: [courseId],
        );
        await txn.delete('cards', where: 'courseId = ?', whereArgs: [courseId]);
        await txn.delete(
          'course_tags',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete(
          'import_exports',
          where: 'courseId = ?',
          whereArgs: [courseId],
        );
        await txn.delete('courses', where: 'id = ?', whereArgs: [courseId]);
      }
    });

    for (final courseId in ids) {
      await TtsAudioCache.instance.deleteCourseAudioCache(courseId: courseId);
    }
  }
}

const Color _dashBg = Color(0xff060a12);
const Color _dashPanel = Color(0xff0d1421);
const Color _dashPanel2 = Color(0xff121a28);
const Color _dashBorder = Color(0xff304267);
const Color _dashText = Color(0xffeef4ff);
const Color _dashMuted = Color(0xff93a0b5);
const Color _dashBlue = Color(0xff4f6dff);
const Color _dashPurple = Color(0xff8b65ff);
const Color _dashGreen = Color(0xff21c781);
const Color _dashOrange = Color(0xffffa31a);
const Color _dashRed = Color(0xffff4d57);
