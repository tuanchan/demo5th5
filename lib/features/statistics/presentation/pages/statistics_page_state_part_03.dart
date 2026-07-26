part of flutterflashcard_main;

extension StatisticsPageStatePart03 on _StatisticsPageState {
  Widget _dashRow(List<Widget> children, {required List<int> flexes}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(flex: flexes[i], child: children[i]),
          if (i < children.length - 1) SizedBox(width: 16),
        ],
      ],
    );
  }


  Widget _dashCard({
    required String title,
    required Widget child,
    double minHeight = 220,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _dashPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dashBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          Container(height: 1, color: _dashBorder.withOpacity(0.35)),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }


  Widget _buildSrsDistributionPanel(StatisticsData data) {
    return this._dashCard(
      title: 'PHÂN BỐ CẤP ĐỘ SRS',
      child: Column(
        children: data.srsItems.map((item) {
          final percent = this._percent(item.count, data.totalCards);
          return Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.label} (${item.subtitle})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dashMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${item.count} (${percent.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: _dashText,
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
                    value: data.totalCards <= 0
                        ? 0
                        : item.count / data.totalCards,
                    minHeight: 8,
                    backgroundColor: _dashPanel2,
                    color: item.color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildDueSchedulePanel(StatisticsData data) {
    return this._dashCard(
      title: 'LỊCH THẺ ĐẾN HẠN (7 NGÀY TỚI)',
      minHeight: 306,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: DueSchedulePainter(
                items: data.dueScheduleItems,
                lineColor: _dashBlue,
                textColor: _dashMuted,
                gridColor: _dashBorder.withOpacity(0.35),
              ),
              child: SizedBox.expand(),
            ),
          ),
          SizedBox(height: 14),
          this._buildDueReviewButton(data),
        ],
      ),
    );
  }


  Widget _buildLanguageDistributionPanel(StatisticsData data) {
    return this._dashCard(
      title: 'CƠ CẤU NGÔN NGỮ HỌC',
      minHeight: 242,
      child: data.languageItems.isEmpty
          ? this._dashEmpty('Chưa có dữ liệu ngôn ngữ')
          : Row(
              children: [
                SizedBox(
                  width: 126,
                  height: 126,
                  child: CustomPaint(
                    painter: LanguageDonutPainter(
                      items: data.languageItems,
                      total: data.totalCards,
                      trackColor: _dashPanel2,
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: data.languageItems.map((item) {
                      final percent = this._percent(
                        item.count,
                        data.totalCards,
                      ).round();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _dashMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${item.count} thẻ ($percent%)',
                              style: TextStyle(
                                color: _dashText,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLiveActivityPanel(StatisticsData data) {
    var maxReviews = 1;
    for (final item in data.activityItems) {
      maxReviews = math.max(maxReviews, item.reviewCount);
    }

    return this._dashCard(
      title: 'HOẠT ĐỘNG NGƯỜI DÙNG',
      minHeight: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.activityItems.map((item) {
                final ratio = item.reviewCount / maxReviews;
                final barHeight =
                    item.reviewCount == 0 ? 4.0 : math.max(10.0, 78 * ratio);
                final isToday = item.date.year == DateTime.now().year &&
                    item.date.month == DateTime.now().month &&
                    item.date.day == DateTime.now().day;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        item.reviewCount.toString(),
                        style: TextStyle(
                          color: isToday ? _dashText : _dashMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      SizedBox(
                        height: 78,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 240),
                            width: 18,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? _dashBlue
                                  : _dashBlue.withOpacity(0.48),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isToday ? _dashText : _dashMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activitySummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _dashMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 7),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOverviewPanel(StatisticsData data) {
    return this._dashCard(
      title: 'CHỈ SỐ TỔNG QUAN',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620 ? 2 : 4;
          return GridView.count(
            crossAxisCount: columns,
            childAspectRatio: columns == 2 ? 1.25 : 1.28,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              this._dashMetric(
                'TỔNG SỐ THẺ',
                data.totalCards.toString(),
                '',
                _dashText,
              ),
              this._dashMetric(
                'SỐ NGÔN NGỮ',
                data.languageCount.toString(),
                '',
                _dashText,
              ),
              this._dashMetric(
                'THẺ ĐÃ THUỘC',
                data.masteredCards.toString(),
                'SRS cấp 5 trở lên',
                _dashGreen,
              ),
              this._dashMetric(
                'THẺ CHƯA THUỘC',
                data.unmasteredCards.toString(),
                '',
                _dashText,
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildMemoryChallengePanel(StatisticsData data) {
    return this._dashCard(
      title: 'CHỈ SỐ GHI NHỚ & THỬ THÁCH',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 440 ? 1 : 2;
          return GridView.count(
            crossAxisCount: columns,
            // Two-column cards need enough vertical room for the label,
            // value and a two-line note at Windows text scale factors.
            childAspectRatio: columns == 1 ? 2.6 : 1.65,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              this._dashMetric(
                'THẺ ĐẾN HẠN',
                data.needReviewCards.toString(),
                'thẻ cần ôn tập hôm nay',
                _dashOrange,
              ),
              this._dashMetric(
                'THẺ KHÓ',
                data.hardCards.toString(),
                'chưa thuộc > 5 lần',
                _dashRed,
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _dashMetric(
    String label,
    String value,
    String note,
    Color valueColor,
  ) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dashPanel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _dashBorder.withOpacity(0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 5),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusRatioPanel(StatisticsData data) {
    final reviewing = data.learningCards + data.reviewingCards;

    return this._dashCard(
      title: 'TỈ LỆ TRẠNG THÁI THẺ',
      minHeight: 240,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          this._statusRing(
            'Đã thuộc',
            data.masteredCards,
            data.totalCards,
            _dashGreen,
          ),
          this._statusRing('Đang ôn', reviewing, data.totalCards, _dashBlue),
          this._statusRing('Thẻ khó', data.hardCards, data.totalCards, _dashRed),
        ],
      ),
    );
  }


  Widget _statusRing(String label, int value, int total, Color color) {
    final percent = this._percent(value, total).round();
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: StatisticsDonutPainter(
                percent: total <= 0 ? 0 : value / total,
                backgroundColor: _dashPanel2,
                progressColor: color,
                strokeWidth: 7,
              ),
              child: Center(
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: _dashText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

}
