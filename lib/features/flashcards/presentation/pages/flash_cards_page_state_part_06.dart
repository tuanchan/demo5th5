part of flutterflashcard_main;

extension FlashCardsPageStatePart06 on _FlashCardsPageState {
  Widget buildCardFace({
    required String label,
    required String mainText,
    required String subText,
    required bool isBack,
    required bool isStarred,
    bool showLabelChip = true,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xff000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0x8cffffff), width: 0.75),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (showLabelChip)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 7,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Color(0xff8f96aa),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Spacer(),
                    this.buildCardIcon(Icons.edit, openEditCardDialog),
                    this.buildCardIcon(
                      Icons.volume_up_outlined,
                      playCurrentCardAudio,
                    ),
                    this.buildCardIcon(Icons.mic_none, openMicOverlay),
                    this.buildGeminiCardIcon(openGeminiExampleDialog),
                    this.buildCardIcon(
                      isStarred ? Icons.star : Icons.star_border,
                      toggleStar,
                      active: isStarred,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: this.buildAdaptiveCardText(
                    mainText.isEmpty ? "Chưa có thẻ" : mainText,
                  ),
                ),
              ),
            ),
            !isBack || subText.trim().isEmpty
                ? SizedBox(height: 48)
                : Container(
                    height: 56,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffb8bfd2),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }


  Widget buildAdaptiveCardText(String value) {
    final displayText = value.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final words = displayText
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList(growable: false);
        final baseFontSize = displayText.length > 100
            ? 25.0
            : displayText.length > 70
            ? 29.0
            : displayText.length > 40
            ? 33.0
            : displayText.length > 22
            ? 38.0
            : 44.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;

        double longestWordWidth = 0;
        for (final word in words) {
          final painter = TextPainter(
            text: TextSpan(
              text: word,
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w500,
                fontFamily: 'Segoe UI',
              ),
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout();
          longestWordWidth = math.max(longestWordWidth, painter.width);
        }

        final wordFitScale = longestWordWidth > availableWidth
            ? availableWidth / longestWordWidth
            : 1.0;
        final fontSize = math.max(18.0, baseFontSize * wordFitScale * 0.97);
        final textStyle = TextStyle(
          color: Color(0xffeef0f7),
          fontSize: fontSize,
          height: 1.12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Segoe UI',
        );

        return Semantics(
          label: displayText,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: availableWidth,
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: fontSize * 0.24,
                runSpacing: fontSize * 0.12,
                children: [
                  for (final word in words)
                    Text(
                      word,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                      style: textStyle,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget buildCardIcon(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Color(0x14ffffff),
        splashColor: Color(0x1fffffff),
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: active ? Color(0xffffd166) : Color(0xffcfcfe8),
          ),
        ),
      ),
    );
  }


  Widget buildGeminiCardIcon(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Color(0x14ffffff),
        splashColor: Color(0x1fffffff),
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          child: geminiColorIcon(size: 18),
        ),
      ),
    );
  }

  Widget buildVocabularyTableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhoneTable = constraints.maxWidth < 700;
        final tableWidth = isPhoneTable
            ? math.max(constraints.maxWidth - 36, 260).toDouble()
            : math.max(constraints.maxWidth - 46, 1000).toDouble();
        const indexWidth = 64.0;
        const actionWidth = 72.0;
        final remaining = tableWidth - indexWidth - actionWidth;
        final termWidth = isPhoneTable ? remaining : remaining * 0.27;
        final definitionWidth = isPhoneTable ? 0.0 : remaining * 0.51;
        final pronunciationWidth = isPhoneTable ? 0.0 : remaining * 0.22;

        Widget tableCell({
          required double width,
          required Widget child,
          Color color = const Color(0xff0b0c0f),
          Alignment alignment = Alignment.centerLeft,
          EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 9),
          bool rightBorder = true,
        }) {
          return Container(
            width: width,
            height: 38,
            alignment: alignment,
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              border: Border(
                right: rightBorder
                    ? BorderSide(color: Color(0xff1f2026))
                    : BorderSide.none,
                bottom: BorderSide(color: Color(0xff1f2026)),
              ),
            ),
            child: child,
          );
        }

        Widget headerCell({
          required double width,
          required Widget child,
          Alignment alignment = Alignment.centerLeft,
          bool rightBorder = true,
        }) {
          return Container(
            width: width,
            height: 40,
            alignment: alignment,
            padding: EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: Color(0xff0f1117),
              border: Border(
                right: rightBorder
                    ? BorderSide(color: Color(0xff1f2026))
                    : BorderSide.none,
                bottom: BorderSide(color: Color(0xff1f2026)),
              ),
            ),
            child: child,
          );
        }

        final rows = visibleOrder
            .where((index) => index >= 0 && index < allCards.length)
            .map((index) => allCards[index])
            .toList();

        return Container(
          color: Color(0xff0b0c0f),
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            isPhoneTable ? 18 : 28,
            24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xff000000),
                border: Border.all(color: Color(0xff1f2026)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: isPhoneTable
                    ? NeverScrollableScrollPhysics()
                    : ClampingScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  height: constraints.maxHeight - 42,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          headerCell(
                            width: indexWidth,
                            child: SizedBox.shrink(),
                            alignment: Alignment.center,
                          ),
                          headerCell(
                            width: actionWidth,
                            child: SizedBox.shrink(),
                            alignment: Alignment.center,
                          ),
                          headerCell(
                            width: termWidth,
                            child: Text(
                              'Từ mới',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!isPhoneTable) ...[
                            headerCell(
                              width: definitionWidth,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Định nghĩa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: tableDefinitionVisible
                                        ? 'Ẩn định nghĩa'
                                        : 'Hiện định nghĩa',
                                    onPressed: () {
                                      setState(() {
                                        tableDefinitionVisible =
                                            !tableDefinitionVisible;
                                      });
                                    },
                                    icon: Icon(
                                      tableDefinitionVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Color(0xffcbd5e1),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            headerCell(
                              width: pronunciationWidth,
                              rightBorder: false,
                              child: Text(
                                'Phiên âm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Expanded(
                        child: rows.isEmpty
                            ? Center(
                                child: Text(
                                  'Chưa có từ vựng để hiển thị.',
                                  style: TextStyle(
                                    color: Color(0xffa8b6d6),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: rows.length,
                                itemExtent: 38,
                                itemBuilder: (context, rowIndex) {
                                  final card = rows[rowIndex];
                                  final selected = selectedVocabRow == rowIndex;
                                  final rowColor = selected
                                      ? Color(0xff123dff)
                                      : Color(0xff0b0c0f);
                                  final indexColor = selected
                                      ? Color(0xff123dff)
                                      : Color(0xff0f1117);

                                  void selectRow() {
                                    setState(() {
                                      selectedVocabRow = rowIndex;
                                      currentPos = rowIndex;
                                      isFlipped = false;
                                    });
                                  }

                                  return InkWell(
                                    onTap: selectRow,
                                    child: Row(
                                      children: [
                                        tableCell(
                                          width: indexWidth,
                                          color: indexColor,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${rowIndex + 1}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        tableCell(
                                          width: actionWidth,
                                          color: rowColor,
                                          alignment: Alignment.center,
                                          padding: EdgeInsets.zero,
                                          child: IconButton(
                                            tooltip: 'Sửa',
                                            onPressed: () {
                                              selectRow();
                                              this.openEditCardDialog();
                                            },
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: Color(0xffcbd5e1),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        tableCell(
                                          width: termWidth,
                                          color: rowColor,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  card.term,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Nghe',
                                                onPressed: () {
                                                  selectRow();
                                                  this.playCurrentCardAudio();
                                                },
                                                icon: Icon(
                                                  Icons.volume_up_outlined,
                                                  color: Color(0xffcfd7ff),
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isPhoneTable) ...[
                                          tableCell(
                                            width: definitionWidth,
                                            color: rowColor,
                                            child: Text(
                                              tableDefinitionVisible
                                                  ? card.definition
                                                  : '••••••',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: tableDefinitionVisible
                                                    ? Colors.white
                                                    : Color(0xff94a3b8),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing:
                                                    tableDefinitionVisible
                                                        ? 0
                                                        : 2.2,
                                              ),
                                            ),
                                          ),
                                          tableCell(
                                            width: pronunciationWidth,
                                            color: rowColor,
                                            rightBorder: false,
                                            child: Text(
                                              card.pronunciation,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget buildCompletionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xf7000000),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Color(0x8cffffff), width: 0.75),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Color(0xff141428),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Color(0x405a78ff)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 44,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      size: 38,
                      color: Color(0xff8899ff),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Hoàn thành thẻ ghi nhớ",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffe6e6f0),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      progressTracking
                          ? 'Bạn đã hoàn thành lượt học này.'
                          : 'Bạn đã đi hết $displayTotal thẻ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xff8a8ab4),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (progressTracking) ...[
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Đã thuộc: $progressKnownCount',
                              style: TextStyle(
                                color: Color(0xff6ed296),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Chưa thuộc: $progressUnknownCount',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xffeb7878),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        this.buildFinishButton(
                          text: "Học lại",
                          icon: Icons.refresh_rounded,
                          color: Color(0xffffd166),
                          onTap: this.restartStudy,
                        ),
                        this.buildFinishButton(
                          text: "Thẻ chưa thuộc",
                          icon: Icons.school_outlined,
                          color: Color(0xffff7a95),
                          onTap: this.restartUnknownCards,
                        ),
                        this.buildFinishButton(
                          text: "Đặt lại ghi nhớ",
                          icon: Icons.restart_alt_rounded,
                          color: Color(0xffc0c0d8),
                          onTap: this.resetMemorizedCards,
                        ),
                        this.buildFinishButton(
                          text: "Thoát",
                          icon: Icons.logout_rounded,
                          color: Color(0xff8899ff),
                          onTap: this.exitFlashCards,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget buildFinishButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Color(0x0fffffff),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0x1affffff)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: Color(0xffe6e6f0),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget buildBottomBar() {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      height: 70 + bottomInset,
      padding: EdgeInsets.fromLTRB(18, 8, 18, 10 + bottomInset),
      decoration: BoxDecoration(
        color: Color(0xff000000),
        border: Border(top: BorderSide(color: Color(0xff1f2026))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    this._buildFlashBottomIcon(
                      icon: Icons.undo_rounded,
                      onTap: _progressHistory.isNotEmpty ? undoLastCard : null,
                    ),
                    if (!compact) ...[
                      SizedBox(width: 12),
                      Text(
                        'Theo dõi tiến độ',
                        style: TextStyle(
                          color: Color(0xff9aa3b8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    SizedBox(width: compact ? 8 : 12),
                    GestureDetector(
                      onTap: this.toggleProgressMode,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: 44,
                        height: 24,
                        padding: EdgeInsets.all(2),
                        alignment: progressTracking
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: progressTracking
                              ? Color(0xff3e5cff)
                              : Color(0xff464650),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  this._buildFlashNavButton(
                    icon: progressTracking ? Icons.close : Icons.chevron_left,
                    onTap: showCompletion
                        ? null
                        : progressTracking
                            ? () => this.moveCard(-1)
                            : (canPrev ? () => this.moveCard(-1) : null),
                  ),
                  SizedBox(
                    width: compact ? 58 : 82,
                    child: Text(
                      '$displayIndex / $displayTotal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffeef0f7),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  this._buildFlashNavButton(
                    icon: progressTracking ? Icons.check : Icons.chevron_right,
                    onTap: showCompletion ? null : () => this.moveCard(1),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    this._buildFlashBottomIcon(
                      icon: Icons.shuffle_rounded,
                      active: shuffleEnabled,
                      onTap: this.toggleShuffle,
                    ),
                    SizedBox(width: 6),
                    this._buildFlashBottomIcon(
                      icon: Icons.settings_outlined,
                      onTap: this.openSettingsSheet,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlashNavButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.22 : 1,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }

  Widget _buildFlashBottomIcon({
    required IconData icon,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.28 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(0xff000000),
            border: Border.all(color: Color(0x59ffffff), width: 0.75),
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? Color(0xff4c92f5) : Color(0xff9fa8c8),
          ),
        ),
      ),
    );
  }

  Widget buildRoundNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
    Color? iconColor,
    bool chromeless = false,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.42 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: chromeless
              ? null
              : BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
          child: Icon(icon, color: iconColor ?? AppColors.onIconButton, size: 34),
        ),
      ),
    );
  }


  Widget buildSmallBottomIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: active ? Color(0xffffb020) : AppColors.onIconButton),
    );
  }
}
