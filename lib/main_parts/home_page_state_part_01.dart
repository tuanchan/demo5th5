part of flutterflashcard_main;

extension HomePageStatePart01 on _HomePageState {
  Widget _buildHomePagePage(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _homeDragStartX = details.globalPosition.dx;
          _openedByEdgeSwipe = false;
        },
        onHorizontalDragUpdate: (details) async {
          final isEdgeSwipe = _homeDragStartX <= 38;
          final dragRightEnough = details.delta.dx > 4;
          final distanceEnough =
              details.globalPosition.dx - _homeDragStartX > 24;

          if (!isOpen &&
              !_openedByEdgeSwipe &&
              isEdgeSwipe &&
              dragRightEnough &&
              distanceEnough) {
            _openedByEdgeSwipe = true;
            await this.openMenu();
          }
        },
        onHorizontalDragEnd: (details) async {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 260 && !isOpen && _homeDragStartX <= 90) {
            await this.openMenu();
          } else if (velocity < -260 && isOpen) {
            this.closeMenu();
          }
        },
        child: Stack(
          children: [
            this._buildHomeMainActions(),
            this._buildHomeMenuScrim(),
            this._buildHomeCourseDrawer(),
            this._buildHomeBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeMainActions() {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 110),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Big3DButton(
                    text: "Tạo Cards",
                    icon: Icons.create,
                    color: AppColors.yellow,
                    onTap: this.openCreateCourse,
                  ),
                  SizedBox(height: 28),
                  Big3DButton(
                    text: "Flash Card",
                    icon: Icons.style_outlined,
                    color: AppColors.red,
                    onTap: this.openFlashCards,
                  ),
                  SizedBox(height: 28),
                  Big3DButton(
                    text: "Ôn Tập",
                    icon: Icons.school,
                    color: AppColors.green,
                    onTap: this.openReviewPractice,
                  ),
                  SizedBox(height: 28),
                  Big3DButton(
                    text: "Thống Kê",
                    icon: Icons.insights_rounded,
                    color: AppColors.blue,
                    onTap: this.openStatistics,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeMenuScrim() {
    return IgnorePointer(
      ignoring: !isOpen,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        opacity: isOpen ? 1 : 0,
        child: GestureDetector(
          onTap: this.closeMenu,
          child: Container(color: AppColors.overlay),
        ),
      ),
    );
  }

  Widget _buildHomeBottomNav() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: IgnorePointer(
        ignoring: isOpen,
        child: AnimatedSlide(
          duration: Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          offset: isOpen ? Offset(0, 1.35) : Offset.zero,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOut,
            opacity: isOpen ? 0 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.panel.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.panel.withOpacity(0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        onPressed: this.toggleMenu,
                        icon: Icon(
                          Icons.menu,
                          size: 30,
                          color: AppColors.muted,
                        ),
                      ),
                      IconButton(
                        onPressed: this.openSettingsPage,
                        icon: Icon(
                          Icons.settings_rounded,
                          size: 30,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
