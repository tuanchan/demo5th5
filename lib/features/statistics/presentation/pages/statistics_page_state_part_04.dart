part of flutterflashcard_main;

extension StatisticsPageStatePart04 on _StatisticsPageState {
  Widget _buildCourseStarsPanel(StatisticsData data) {
    final sortedItems = data.courseItems.toList()
      ..sort((a, b) {
        final byStars = b.srsStars.compareTo(a.srsStars);
        return byStars != 0
            ? byStars
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final items = sortedItems.take(10).toList();

    return this._dashCard(
      title: 'TOP 10 SAO SRS THEO HỌC PHẦN',
      minHeight: 240,
      child: items.isEmpty
          ? SizedBox(
              height: 130,
              child: Center(child: this._dashEmpty('Chưa có học phần nào')),
            )
          : Column(
              children: items.map((item) {
                final value = item.srsStars.clamp(0, 8).toInt();
                return Padding(
                  padding: EdgeInsets.only(bottom: 14),
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
                                color: _dashText,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Color(0xffffcf33),
                                size: 16,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '× $value',
                                style: TextStyle(
                                  color: _dashText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Stack(
                          children: [
                            Container(height: 10, color: _dashPanel2),
                            FractionallySizedBox(
                              widthFactor: value / 8,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xffffb800),
                                      Color(0xffffe56b),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: List.generate(
                                8,
                                (index) => Expanded(
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      border: index == 7
                                          ? null
                                          : Border(
                                              right: BorderSide(
                                                color: _dashBg.withOpacity(0.5),
                                                width: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildCourseSrsCardsPanel(StatisticsData data) {
    final sortedItems = data.courseItems.toList()
      ..sort((a, b) {
        final byTracked = b.srsTrackedCards.compareTo(a.srsTrackedCards);
        return byTracked != 0
            ? byTracked
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final items = sortedItems.take(10).toList();
    var maxTracked = 1;
    for (final item in items) {
      maxTracked = math.max(maxTracked, item.srsTrackedCards);
    }

    return this._dashCard(
      title: 'TOP 10 SỐ THẺ SRS',
      minHeight: 240,
      child: items.isEmpty
          ? SizedBox(
              height: 130,
              child: Center(child: this._dashEmpty('Chưa có học phần nào')),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 7,
                  children: [
                    this._courseSrsLegend('Cấp 1–3', _dashBlue),
                    this._courseSrsLegend('Cấp 4–6', _dashPurple),
                    this._courseSrsLegend('Cấp 7–8', _dashGreen),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '0',
                      style: TextStyle(
                        color: _dashMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Tối đa $maxTracked thẻ SRS',
                      style: TextStyle(
                        color: _dashMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ...items.map((item) {
                  final tracked = item.srsTrackedCards;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 14),
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
                                  color: _dashText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '$tracked/${item.totalCards} thẻ',
                              style: TextStyle(
                                color: _dashMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Stack(
                            children: [
                              Container(height: 12, color: _dashPanel2),
                              if (tracked > 0)
                                FractionallySizedBox(
                                  widthFactor: tracked / maxTracked,
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    height: 12,
                                    child: Row(
                                      children: [
                                        if (item.srsLearningCards > 0)
                                          Expanded(
                                            flex: item.srsLearningCards,
                                            child: Tooltip(
                                              message:
                                                  'Cấp 1–3: ${item.srsLearningCards} thẻ',
                                              child: Container(
                                                color: _dashBlue,
                                              ),
                                            ),
                                          ),
                                        if (item.srsSteadyCards > 0)
                                          Expanded(
                                            flex: item.srsSteadyCards,
                                            child: Tooltip(
                                              message:
                                                  'Cấp 4–6: ${item.srsSteadyCards} thẻ',
                                              child: Container(
                                                color: _dashPurple,
                                              ),
                                            ),
                                          ),
                                        if (item.srsAdvancedCards > 0)
                                          Expanded(
                                            flex: item.srsAdvancedCards,
                                            child: Tooltip(
                                              message:
                                                  'Cấp 7–8: ${item.srsAdvancedCards} thẻ',
                                              child: Container(
                                                color: _dashGreen,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _courseSrsLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: _dashMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
