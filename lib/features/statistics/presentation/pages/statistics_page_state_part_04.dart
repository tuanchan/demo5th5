part of flutterflashcard_main;

extension StatisticsPageStatePart04 on _StatisticsPageState {
  Widget _buildHardCoursesPanel(StatisticsData data) {
    return this._dashCard(
      title: 'HỌC PHẦN NHIỀU THẺ KHÓ NHẤT',
      minHeight: 240,
      child: data.hardCourseItems.isEmpty
          ? SizedBox(
              height: 130,
              child: Center(child: this._dashEmpty('Không có thẻ khó nào')),
            )
          : Column(
              children: data.hardCourseItems.map((item) {
                var maxHard = 1;
                for (final course in data.hardCourseItems) {
                  maxHard = math.max(maxHard, course.hardCards);
                }
                final widthFactor = (item.hardCards / maxHard)
                    .clamp(0.04, 1.0)
                    .toDouble();
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _dashText,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${item.hardCards}/${item.totalCards}',
                            style: TextStyle(
                              color: _dashMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: widthFactor,
                          minHeight: 8,
                          backgroundColor: _dashPanel2,
                          color: _dashRed,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }


  Widget _dashEmpty(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _dashMuted,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }


  double _percent(int value, int total) {
    if (total <= 0) return 0;
    return (value / total * 100).clamp(0, 100).toDouble();
  }


  Widget _buildError(String text) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            this._buildTopBar(),
            Spacer(),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.red,
                    size: 42,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Không tải được thống kê',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: this.reloadStatistics,
                    icon: Icon(Icons.refresh_rounded),
                    label: Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.onAccentButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(StatisticsData data) {
    return Container(
      margin: EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          this._buildTopBar(onDark: true),
          SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: StatisticsDonutPainter(
                    percent: data.completionPercent / 100,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    progressColor: AppColors.green,
                    strokeWidth: 13,
                  ),
                  child: Center(
                    child: Text(
                      '${data.completionPercent}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng thống kê',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      data.totalCards == 0
                          ? 'Chưa có thẻ để thống kê'
                          : '${data.masteredCards}/${data.totalCards} thẻ đã thuộc cấp ${ReviewScheduler.masteredLevel}+',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    this._buildMiniHeaderPill(
                      icon: Icons.local_fire_department_rounded,
                      text: '${data.needReviewCards} thẻ cần ôn',
                    ),
                    SizedBox(height: 8),
                    this._buildMiniHeaderPill(
                      icon: Icons.today_rounded,
                      text: '${data.reviewedTodayCards} thẻ đã ôn hôm nay',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTopBar({bool onDark = false}) {
    final color = onDark ? Colors.white : AppColors.text;
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withOpacity(0.13) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onDark
                    ? Colors.white.withOpacity(0.25)
                    : AppColors.border,
              ),
            ),
            child: Icon(Icons.arrow_back_rounded, color: color),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Thống Kê',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: this.reloadStatistics,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withOpacity(0.13) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onDark
                    ? Colors.white.withOpacity(0.25)
                    : AppColors.border,
              ),
            ),
            child: Icon(Icons.refresh_rounded, color: color),
          ),
        ),
      ],
    );
  }


  Widget _buildMiniHeaderPill({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.yellow),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOverviewGrid(StatisticsData data) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.22,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: [
        this._buildStatCard(
          'Cần ôn',
          data.needReviewCards.toString(),
          Icons.replay_rounded,
          AppColors.red,
        ),
        this._buildStatCard(
          'Hôm nay',
          data.reviewedTodayCards.toString(),
          Icons.today_rounded,
          AppColors.green,
        ),
        this._buildStatCard(
          'Đã thuộc',
          data.masteredCards.toString(),
          Icons.check_circle_rounded,
          AppColors.yellow,
        ),
        this._buildStatCard(
          'Tổng thẻ',
          data.totalCards.toString(),
          Icons.style_rounded,
          AppColors.blue,
        ),
      ],
    );
  }


  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.35),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 46,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
