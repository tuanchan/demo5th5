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
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 8),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 18),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 10, 6),
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
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Spacer(),
                  this.buildCardIcon(Icons.edit, openEditCardDialog),
                  this.buildGeminiCardIcon(openGeminiExampleDialog),
                  this.buildCardIcon(Icons.volume_up_outlined, playCurrentCardAudio),
                  this.buildCardIcon(Icons.mic_none, openMicOverlay),
                  this.buildCardIcon(
                    isStarred ? Icons.star : Icons.star_border,
                    toggleStar,
                    active: isStarred,
                  ),
                  this.buildCardIcon(Icons.delete_outline, deleteCurrentCard),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    mainText.isEmpty ? "Chưa có thẻ" : mainText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: mainText.length > 40 ? 34 : 48,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ),
              ),
            ),
            subText.trim().isEmpty
                ? SizedBox(height: 48)
                : Container(
                    height: 56,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
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
        child: Container(
          width: 34,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 21,
            color: active ? Color(0xffffb020) : AppColors.border,
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
        child: Container(
          width: 34,
          height: 32,
          alignment: Alignment.center,
          child: geminiColorIcon(size: 21),
        ),
      ),
    );
  }


  Widget buildCompletionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel.withOpacity(0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 64,
                color: AppColors.border,
              ),
              SizedBox(height: 14),
              Text(
                "Hoàn thành bộ thẻ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                progressTracking
                    ? "Đã thuộc $progressKnownCount thẻ, chưa thuộc $progressUnknownCount thẻ."
                    : "Bạn đã đi hết $displayTotal thẻ.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 12,
                children: [
                  this.buildFinishButton(
                    text: "Học lại",
                    icon: Icons.refresh_rounded,
                    color: AppColors.yellow,
                    onTap: this.restartStudy,
                  ),
                  this.buildFinishButton(
                    text: "Thẻ chưa thuộc",
                    icon: Icons.school_outlined,
                    color: AppColors.red,
                    onTap: this.restartUnknownCards,
                  ),
                  this.buildFinishButton(
                    text: "Đặt lại ghi nhớ",
                    icon: Icons.restart_alt_rounded,
                    color: Colors.white,
                    onTap: this.resetMemorizedCards,
                  ),
                  this.buildFinishButton(
                    text: "Thoát",
                    icon: Icons.logout_rounded,
                    color: AppColors.blue,
                    onTap: this.exitFlashCards,
                  ),
                ],
              ),
            ],
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
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.onSolidButton),
            SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: AppColors.onSolidButton,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget buildBottomBar() {
    return Container(
      width: double.infinity,
      height: 86,
      padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              this.buildRoundNavButton(
                icon: progressTracking ? Icons.close : Icons.chevron_left,
                onTap: showCompletion
                    ? null
                    : progressTracking
                    ? () => this.moveCard(-1)
                    : (canPrev ? () => this.moveCard(-1) : null),
                color: progressTracking ? AppColors.red : AppColors.panel,
                iconColor: progressTracking ? AppColors.red : null,
                chromeless: progressTracking,
              ),
              Container(
                width: 76,
                alignment: Alignment.center,
                child: Text(
                  "$displayIndex / $displayTotal",
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              this.buildRoundNavButton(
                icon: progressTracking ? Icons.check : Icons.chevron_right,
                onTap: showCompletion ? null : () => this.moveCard(1),
                color: progressTracking ? AppColors.green : AppColors.panel,
                iconColor: progressTracking ? AppColors.green : null,
                chromeless: progressTracking,
              ),
            ],
          ),
          if (progressTracking)
            Positioned(
              right: 0,
              child: Opacity(
                opacity: _progressHistory.isNotEmpty ? 1.0 : 0.28,
                child: GestureDetector(
                  onTap: _progressHistory.isNotEmpty ? undoLastCard : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.border,
                          offset: Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.undo_rounded,
                      color: AppColors.onIconButton,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
