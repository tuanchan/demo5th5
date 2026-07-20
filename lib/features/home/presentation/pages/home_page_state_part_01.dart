part of flutterflashcard_main;

extension HomePageStatePart01 on _HomePageState {
  static const Color _homeBg = Color(0xff000000);
  static const Color _homePanel = Color(0xff07090d);
  static const Color _homeBorder = Color(0xff202634);
  static const Color _homeText = Color(0xfff8fbff);
  static const Color _homeMuted = Color(0xff91a0bd);
  static const Color _homeBlue = Color(0xff9ab9ff);

  Widget _buildHomePagePage(BuildContext context) {
    return Scaffold(
      backgroundColor: _homeBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return Column(
              children: [
                this._buildWebHomeTopBar(compact),
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) {
                      if (_isHomeNavExpanded) {
                        setState(() => _isHomeNavExpanded = false);
                      }
                    },
                    child: this._buildWebHomeDashboard(compact),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWebHomeTopBar(bool compact) {
    final actions = <Widget>[
      this._homeNavButton('Học thẻ', this.openFlashCards),
      this._homeNavButton('Thống kê', this.openStatistics),
      this._homeNavButton('Kiểm tra', this.openReviewPractice),
      this._homeNavButton('Viết', this.openWritingPractice),
      this._homeNavButton('Luyện nói', () {}),
      this._homeNavButton('Tạo học phần', this.openCreateCourse),
      StreamBuilder<AuthState>(
        stream: SupabaseConfig.onAuthStateChange,
        builder: (context, _) => this._buildHomeAccountButton(),
      ),
      IconButton(
        tooltip: 'Cài đặt API',
        onPressed: this.openSettingsPage,
        icon: Icon(Icons.settings_outlined, color: _homeMuted, size: 21),
      ),
    ];

    if (!compact) {
      return Container(
        height: 84,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _homeBg,
          border: Border(bottom: BorderSide(color: _homeBorder)),
        ),
        child: Row(
          children: [
            this._buildHomeBrand(),
            SizedBox(width: 20),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  runSpacing: 2,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _homeBg,
          border: Border(bottom: BorderSide(color: _homeBorder)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 84,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 10, 0),
                child: Row(
                  children: [
                    Expanded(child: this._buildHomeBrand()),
                    IconButton(
                      tooltip: _isHomeNavExpanded ? 'Đóng menu' : 'Mở menu',
                      onPressed: () {
                        setState(() {
                          _isHomeNavExpanded = !_isHomeNavExpanded;
                        });
                      },
                      icon: AnimatedRotation(
                        turns: _isHomeNavExpanded ? 0.25 : 0,
                        duration: Duration(milliseconds: 220),
                        child: Icon(
                          _isHomeNavExpanded
                              ? Icons.close_rounded
                              : Icons.menu_rounded,
                          color: _homeText,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isHomeNavExpanded)
              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: actions,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeAccountButton() {
    final user = SupabaseConfig.currentUser;
    final metadata = user?.userMetadata;
    final avatarUrl = metadata?['avatar_url']?.toString() ??
        metadata?['picture']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Tooltip(
      message: user == null ? 'Đăng nhập hoặc đăng ký' : 'Tài khoản',
      child: Semantics(
        button: true,
        label: user == null ? 'Đăng nhập hoặc đăng ký' : 'Mở tài khoản',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (user == null) {
              await this._showHomeAuthPage();
            } else {
              await this.openSettingsPage();
            }
          },
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: hasAvatar
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.account_circle_outlined,
                          color: _homeMuted,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.account_circle_outlined,
                      color: _homeMuted,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHomeAuthPage() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FlashcardsLoginPage(
          initialAuthMode: AuthMode.login,
          onGoogleLogin: this._signInWithGoogleFromHome,
          translateAuthError: this._translateHomeAuthError,
        ),
      ),
    );
    if (!mounted || loggedIn != true) return;
    setState(() {});
    if (SupabaseConfig.isLoggedIn) {
      showAppToast(context, 'Đăng nhập thành công!');
    }
  }

  Future<String?> _signInWithGoogleFromHome() async {
    try {
      String? redirectTo;
      if (kIsWeb) {
        redirectTo = null;
      } else if (Platform.isAndroid || Platform.isIOS) {
        redirectTo = 'com.example.flutterflashcard://login-callback/';
      } else {
        redirectTo = 'http://localhost:3000/';
        _globalDesktopOAuthServer ??= _DesktopOAuthServer();
        await _globalDesktopOAuthServer!.start((code) async {
          try {
            await SupabaseConfig.client.auth.exchangeCodeForSession(code);
            if (mounted) {
              setState(() {});
              showAppToast(context, 'Đăng nhập thành công!');
            }
          } catch (error) {
            if (mounted) {
              showAppToast(context, 'Xác thực tài khoản thất bại: $error');
            }
          } finally {
            await _globalDesktopOAuthServer!.stop();
          }
        });
      }

      final launched = await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: !kIsWeb && Platform.isIOS
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        throw StateError('Không thể mở trang đăng nhập Google');
      }
      return null;
    } catch (error) {
      return 'Đăng nhập Google thất bại: $error';
    }
  }

  String _translateHomeAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (lower.contains('email not confirmed')) {
      return 'Vui lòng xác nhận email trước khi đăng nhập';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'Email này đã được đăng ký';
    }
    if (lower.contains('error sending confirmation email') ||
        lower.contains('smtp')) {
      return 'Không gửi được email xác thực. Hãy kiểm tra cấu hình SMTP.';
    }
    return message;
  }

  Widget _buildHomeBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 10),
        Flexible(
          child: this._buildAnimatedHomeLogoText(),
        ),
      ],
    );
  }

  Widget _buildAnimatedHomeLogoText() {
    const logoText = 'FLASH\nCARDS';
    final logoStyle = TextStyle(
      fontSize: 28,
      height: 0.92,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w900,
    );

    Widget movingBeam({required bool second}) {
      return AnimatedBuilder(
        animation: _homeLogoAnimation,
        builder: (context, child) {
          final value = _homeLogoAnimation.value;
          final active = second ? value >= 0.5 : value < 0.5;
          final progress = second ? (value - 0.5) * 2 : value * 2;
          final center = second
              ? -1.6 + (progress * 3.2)
              : 1.6 - (progress * 3.2);
          return Opacity(
            opacity: active ? 1 : 0,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: second
                      ? Alignment(center - 0.9, 1)
                      : Alignment(center - 0.9, -1),
                  end: second
                      ? Alignment(center + 0.9, -1)
                      : Alignment(center + 0.9, 1),
                  colors: const [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 0.5, 0.58, 1],
                ).createShader(bounds);
              },
              child: child,
            ),
          );
        },
        child: Text(
          logoText,
          maxLines: 2,
          style: logoStyle.copyWith(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        Text(
          logoText,
          maxLines: 2,
          style: logoStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..color = Colors.white.withOpacity(0.86),
          ),
        ),
        movingBeam(second: false),
        movingBeam(second: true),
      ],
    );
  }

  Widget _homeNavButton(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: () {
        if (_isHomeNavExpanded) {
          setState(() => _isHomeNavExpanded = false);
        }
        onTap();
      },
      style: TextButton.styleFrom(
        foregroundColor: _homeBlue,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        minimumSize: Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      child: Text(text),
    );
  }

  Widget _buildWebHomeDashboard(bool compact) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1200),
        child: AnimatedPadding(
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 24,
            0,
            compact ? 20 : 24,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: this._buildHomeDashboardGrid(compact)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeading() {
    final activeTopic = _activeHomeTopic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeTopic?.name ?? 'Danh sách chủ đề',
          style: TextStyle(
            color: _homeText,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          activeTopic == null
              ? 'Có ${visibleTopics.length} chủ đề'
              : 'Có ${this.visibleCoursesForTopic(activeTopic.id).length} học phần',
          style: TextStyle(color: _homeBlue, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDashboardFilters(bool compact) {
    final search = SizedBox(
      height: 42,
      child: TextField(
        controller: courseSearchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: _homeText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: _activeHomeTopic == null
              ? 'Tìm chủ đề...'
              : 'Tìm học phần...',
          hintStyle: TextStyle(
            color: _homeBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: _homeBg,
          contentPadding: EdgeInsets.symmetric(horizontal: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _homeBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _homeBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xff4b6aaf)),
          ),
        ),
      ),
    );

    final filter = PopupMenuButton<String>(
      tooltip: 'Sắp xếp và lọc',
      initialValue: courseSortType,
      color: Color(0xff0b0d12),
      onSelected: this.setCourseSortType,
      itemBuilder: (_) => [
        this._homePopupItem('updatedDesc', 'Mặc định'),
        this._homePopupItem('az', 'A-Z'),
        this._homePopupItem('za', 'Z-A'),
        this._homePopupItem('cardsDesc', 'Nhiều thẻ nhất'),
        this._homePopupItem('cardsAsc', 'Ít thẻ nhất'),
      ],
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
        decoration: BoxDecoration(
          color: _homeBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _homeBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_rounded, color: _homeText, size: 22),
            if (!compact) ...[
              SizedBox(width: 8),
              Text(
                courseSortType == 'updatedDesc'
                    ? 'Mặc định'
                    : courseSortLabel,
                style: TextStyle(
                  color: _homeText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: _homeText, size: 20),
          ],
        ),
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: search),
          SizedBox(width: 12),
          filter,
        ],
      );
    }
    return Row(children: [SizedBox(width: 240, child: search), SizedBox(width: 12), filter]);
  }

  PopupMenuItem<String> _homePopupItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(label, style: TextStyle(color: _homeText)),
    );
  }

  Widget _buildHomeDashboardGrid(bool compact) {
    if (isLoadingCourses) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xff5f82d7)),
      );
    }
    final activeTopic = _activeHomeTopic;
    if (activeTopic != null) {
      return this._buildHomeCourseGrid(activeTopic, compact);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 580
                ? 2
                : 2;
        final spacing = constraints.maxWidth < 580 ? 12.0 : 20.0;
        final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Stack(
          children: [
            Positioned.fill(
              child: SizedBox.expand(
                key: _homeTopicViewportKey,
                child: SingleChildScrollView(
                  controller: _homeTopicScrollController,
                  child: Column(
                    children: [
                      this._buildScrollableHomeDashboardHeader(compact),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: width,
                            child: this._buildHomeCourseActionCard(
                              key: _homeCreateTopicCardKey,
                              icon: Icons.add_rounded,
                              label: 'Tạo chủ đề',
                              onTap: this.openCreateTopicDialog,
                            ),
                          ),
                          ...visibleTopics.map((topic) {
                            return SizedBox(
                              width: width,
                              child: this._buildHomeTopicCard(topic),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                ignoring: !_showFloatingTopicTop,
                child: AnimatedScale(
                  scale: _showFloatingTopicTop ? 1 : 0.75,
                  duration: Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _showFloatingTopicTop ? 1 : 0,
                    duration: Duration(milliseconds: 160),
                    child: Material(
                      color: Color(0xff07090d),
                      shape: CircleBorder(
                        side: BorderSide(
                          color: Color(0xff2563eb),
                          width: 1.2,
                        ),
                      ),
                      elevation: 8,
                      child: IconButton(
                        tooltip: 'Cuộn lên đầu trang',
                        onPressed: this._scrollHomeTopicToTop,
                        icon: SvgPicture.asset(
                          'assets/icon/arrow-up-solid-full.svg',
                          width: 19,
                          height: 19,
                          colorFilter: ColorFilter.mode(
                            Color(0xff3983ff),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeTopicCard(CourseTopicItem topic) {
    final isMobile = MediaQuery.of(context).size.width < 580;
    final cardHeight = isMobile ? 140.0 : 200.0;
    return InkWell(
      onTap: () {
        courseSearchController.clear();
        setState(() {
          _activeHomeTopic = topic;
          selectedHomeCourse = null;
          _homeCoursePage = 1;
          _showFloatingTopicBack = false;
          _homeCourseAtBottom = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final firstCourseContext = _homeFirstCourseCardKey.currentContext;
          if (firstCourseContext != null) {
            Scrollable.ensureVisible(
              firstCourseContext,
              alignment: 0,
              duration: Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          } else if (_homeCourseScrollController.hasClients) {
            _homeCourseScrollController.jumpTo(0);
          }
        });
      },
      onLongPress: () => this.openEditTopicDialog(topic),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: cardHeight,
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        decoration: BoxDecoration(
          color: _homePanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _homeBorder),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: PopupMenuButton<String>(
                tooltip: 'Tùy chọn chủ đề',
                color: Color(0xff0b0d12),
                onSelected: (value) {
                  if (value == 'edit') this.openEditTopicDialog(topic);
                  if (value == 'delete') this.confirmDeleteTopic(topic);
                },
                itemBuilder: (_) => [
                  this._homePopupItem('edit', 'Sửa'),
                  this._homePopupItem('delete', 'Xóa'),
                ],
                icon: Icon(Icons.more_horiz_rounded, color: _homeMuted),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: isMobile ? 8.0 : 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoShrinkText(
                      topic.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _homeText,
                        fontSize: isMobile ? 20 : 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 9),
                    AutoShrinkText(
                      '${topic.courseCount} học phần · ${topic.cardCount} thẻ',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _homeMuted,
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCourseGrid(CourseTopicItem topic, bool compact) {
    final topicCourses = this._homeCoursesForTopicWithoutSorting(topic.id);
    final totalPages = math.max(1, (topicCourses.length / 10).ceil()).toInt();
    if (_homeCoursePage > totalPages) _homeCoursePage = totalPages;
    final start = (_homeCoursePage - 1) * 10;
    final pageCourses = topicCourses.skip(start).take(10).toList();
    this._sortHomeCoursePage(pageCourses);

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                key: _homeCourseViewportKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 580
                            ? 2
                            : 2;
                    final spacing = constraints.maxWidth < 580 ? 12.0 : 20.0;
                    final width =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                            columns;
                    final cards = <Widget>[
                      this._buildHomeCourseActionCard(
                        key: _homeBackCardKey,
                        icon: Icons.arrow_back_rounded,
                        label: 'Quay lại',
                        onTap: this._leaveHomeTopic,
                      ),
                      this._buildHomeCourseActionCard(
                        icon: Icons.add_rounded,
                        label: 'Tạo học phần',
                        onTap: this.openCreateCourse,
                      ),
                      ...pageCourses.asMap().entries.map(
                        (entry) {
                          final course = entry.value;
                          final isFirst = entry.key == 0;
                          final isSelected = selectedHomeCourse?.id == course.id;
                          return this._buildWebCourseTile(
                            course,
                            key: isSelected
                                ? _homeSelectedCourseCardKey
                                : (isFirst ? _homeFirstCourseCardKey : null),
                          );
                        },
                      ),
                    ];

                    return SingleChildScrollView(
                      controller: _homeCourseScrollController,
                      child: Column(
                        children: [
                          this._buildScrollableHomeDashboardHeader(compact),
                          Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: cards
                                .map(
                                  (card) => SizedBox(width: width, child: card),
                                )
                                .toList(),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: this._buildHomePagination(totalPages),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        AnimatedPositioned(
          duration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          right: 8,
          bottom: _homeCourseAtBottom ? 58 : 8,
          child: IgnorePointer(
            ignoring: !_showFloatingTopicBack,
            child: AnimatedScale(
              scale: _showFloatingTopicBack ? 1 : 0.75,
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _showFloatingTopicBack ? 1 : 0,
                duration: Duration(milliseconds: 160),
                child: Material(
                  color: Color(0xff07090d),
                  shape: CircleBorder(
                    side: BorderSide(color: Color(0xff2563eb), width: 1.2),
                  ),
                  elevation: 8,
                  child: IconButton(
                    tooltip: 'Cuộn lên đầu trang',
                    onPressed: this._scrollHomeCourseToTop,
                    icon: SvgPicture.asset(
                      'assets/icon/arrow-up-solid-full.svg',
                      width: 19,
                      height: 19,
                      colorFilter: ColorFilter.mode(
                        Color(0xff3983ff),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<CourseListItem> _homeCoursesForTopicWithoutSorting(int topicId) {
    final keyword = courseSearchController.text.trim().toLowerCase();
    return courses.where((course) {
      if (course.topicId != topicId) return false;
      if (keyword.isEmpty) return true;

      final languageCode = course.languageCode.trim();
      return course.title.toLowerCase().contains(keyword) ||
          languageCode.toLowerCase().contains(keyword) ||
          this.languageNameFromCode(languageCode).toLowerCase().contains(keyword);
    }).toList();
  }

  void _sortHomeCoursePage(List<CourseListItem> pageCourses) {
    switch (courseSortType) {
      case 'az':
        pageCourses.sort((a, b) => _naturalCompareText(a.title, b.title));
        break;
      case 'za':
        pageCourses.sort((a, b) => _naturalCompareText(b.title, a.title));
        break;
      case 'cardsDesc':
        pageCourses.sort((a, b) => b.cardCount.compareTo(a.cardCount));
        break;
      case 'cardsAsc':
        pageCourses.sort((a, b) => a.cardCount.compareTo(b.cardCount));
        break;
      default:
        break;
    }
  }

  void _scrollHomeCourseToTop() {
    if (!_homeCourseScrollController.hasClients) return;
    _homeCourseScrollController.animateTo(
      0,
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollHomeTopicToTop() {
    if (!_homeTopicScrollController.hasClients) return;
    _homeTopicScrollController.animateTo(
      0,
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateHomeToCourse(int courseId) {
    if (!mounted) return;

    // Find the course
    final matchCourse = courses.where((c) => c.id == courseId);
    if (matchCourse.isEmpty) return;
    final course = matchCourse.first;

    // Find the topic
    final topicId = course.topicId;
    CourseTopicItem? matchTopic;
    if (topicId != null) {
      final topicMatches = topics.where((t) => t.id == topicId);
      if (topicMatches.isNotEmpty) matchTopic = topicMatches.first;
    }

    if (matchTopic == null) return;

    // Calculate the page number for this course
    final topicCourses = this._homeCoursesForTopicWithoutSorting(matchTopic.id);
    final courseIndex = topicCourses.indexWhere((c) => c.id == courseId);
    final page = courseIndex >= 0 ? (courseIndex ~/ 10) + 1 : 1;

    courseSearchController.clear();
    setState(() {
      _activeHomeTopic = matchTopic;
      selectedHomeCourse = course;
      _homeCoursePage = page;
      _showFloatingTopicBack = false;
      _homeCourseAtBottom = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedCourseContext = _homeSelectedCourseCardKey.currentContext;
      if (selectedCourseContext != null) {
        Scrollable.ensureVisible(
          selectedCourseContext,
          alignment: 0.5,
          duration: Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        final firstCourseContext = _homeFirstCourseCardKey.currentContext;
        if (firstCourseContext != null) {
          Scrollable.ensureVisible(
            firstCourseContext,
            alignment: 0,
            duration: Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        } else if (_homeCourseScrollController.hasClients) {
          _homeCourseScrollController.jumpTo(0);
        }
      }
    });
  }

  Widget _buildScrollableHomeDashboardHeader(bool compact) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 48 : 24, bottom: 20),
      child: Column(
        children: [
          if (compact) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: this._buildDashboardHeading(),
            ),
            SizedBox(height: 16),
            this._buildDashboardFilters(compact),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                this._buildDashboardHeading(),
                Spacer(),
                this._buildDashboardFilters(compact),
              ],
            ),
          SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: _homeBorder),
        ],
      ),
    );
  }

  void _leaveHomeTopic() {
    courseSearchController.clear();
    setState(() {
      _activeHomeTopic = null;
      selectedHomeCourse = null;
      _homeCoursePage = 1;
      _showFloatingTopicBack = false;
      _homeCourseAtBottom = false;
    });
  }

  Widget _buildHomePagination(int totalPages) {
    final items = this._homePaginationItems(totalPages, _homeCoursePage);
    return SizedBox(
      height: 48,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              this._homePaginationButton(
                label: '«',
                enabled: _homeCoursePage > 1,
                onTap: () => this._setHomeCoursePage(_homeCoursePage - 1),
              ),
              ...items.map((item) {
                if (item == null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '…',
                      style: TextStyle(
                        color: _homeMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }
                return this._homePaginationButton(
                  label: '$item',
                  selected: item == _homeCoursePage,
                  onTap: () => this._setHomeCoursePage(item),
                );
              }),
              this._homePaginationButton(
                label: '»',
                enabled: _homeCoursePage < totalPages,
                onTap: () => this._setHomeCoursePage(_homeCoursePage + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<int?> _homePaginationItems(int totalPages, int currentPage) {
    if (totalPages <= 7) {
      return List<int>.generate(totalPages, (index) => index + 1);
    }
    if (currentPage <= 4) return [1, 2, 3, 4, 5, null, totalPages];
    if (currentPage >= totalPages - 3) {
      return [
        1,
        null,
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    }
    return [
      1,
      null,
      currentPage - 1,
      currentPage,
      currentPage + 1,
      null,
      totalPages,
    ];
  }

  Widget _homePaginationButton({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: BoxConstraints(minWidth: 38),
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: selected
                ? Border.all(color: Color(0xff2563eb), width: 1.2)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Color(0x592563eb),
                      blurRadius: 0,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? _homeText : _homeMuted.withOpacity(0.42),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  void _setHomeCoursePage(int page) {
    if (page == _homeCoursePage || page < 1) return;
    setState(() {
      _homeCoursePage = page;
      selectedHomeCourse = null;
      _showFloatingTopicBack = false;
      _homeCourseAtBottom = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firstCourseContext = _homeFirstCourseCardKey.currentContext;
      if (!mounted || firstCourseContext == null) return;
      Scrollable.ensureVisible(
        firstCourseContext,
        alignment: 0,
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildHomeCourseActionCard({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 580;
    final cardHeight = isMobile ? 140.0 : 200.0;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        foregroundPainter: _HomeDashedBorderPainter(
          color: Color(0xff4579d8),
          radius: 12,
          strokeWidth: 1.5,
        ),
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: _homePanel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Color(0xff3983ff), size: isMobile ? 22 : 27),
              SizedBox(height: isMobile ? 10 : 18),
              AutoShrinkText(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: Color(0xff3983ff),
                  fontSize: isMobile ? 13 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCourseTile(CourseListItem course, {Key? key}) {
    final selected = selectedHomeCourse?.id == course.id;
    final srsStars = course.srsLevel.clamp(0, 8).toInt();
    final displayedSrsStars = srsStars == 0 ? 1 : srsStars;
    final isMobile = MediaQuery.of(context).size.width < 580;
    final cardHeight = isMobile ? 140.0 : 200.0;
    return InkWell(
      key: key,
      onTap: () {
        if (selectedHomeCourse?.id != course.id) {
          setState(() => selectedHomeCourse = course);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Color(0xff2563eb) : _homeBorder,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: ImageFiltered(
                  enabled: selected,
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(0xff101b35)
                                : _homePanel,
                            image: DecorationImage(
                              image: AssetImage('assets/icon/app_icon.png'),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.52),
                                BlendMode.darken,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Stack(
                  children: [
            Align(
              alignment: Alignment.topRight,
              child: PopupMenuButton<String>(
                tooltip: 'Tùy chọn học phần',
                color: Color(0xff0b0d12),
                onSelected: (value) {
                  if (value == 'edit') this.openEditCourseDialog(course);
                  if (value == 'delete') this.confirmDeleteCourse(course);
                },
                itemBuilder: (_) => [
                  this._homePopupItem('edit', 'Sửa'),
                  this._homePopupItem('delete', 'Xóa'),
                ],
                icon: Icon(Icons.more_vert_rounded, color: _homeMuted),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(right: 34),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.hasLocalNameConflict) ...[
                      Tooltip(
                        message: 'HP LOCAL',
                        child: SvgPicture.asset(
                          'assets/icon/triangle-exclamation-solid-full.svg',
                          width: isMobile ? 15 : 19,
                          height: isMobile ? 15 : 19,
                          colorFilter: ColorFilter.mode(
                            Color(0xffffc107),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    Expanded(
                      child: AutoShrinkText(
                        course.title,
                        maxLines: 2,
                        style: TextStyle(
                          color: _homeText,
                          fontSize: isMobile ? 15 : 19,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: 'SRS cấp $srsStars',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        displayedSrsStars,
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            right: index == displayedSrsStars - 1 ? 0 : 3,
                          ),
                          child: SvgPicture.asset(
                            'assets/icon/star-solid-full.svg',
                            width: isMobile ? 11 : 13,
                            height: isMobile ? 11 : 13,
                            colorFilter: ColorFilter.mode(
                              srsStars == 0
                                  ? _homeMuted.withOpacity(0.65)
                                  : Color(0xffffc107),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  AutoShrinkText(
                    '${course.cardCount} thẻ · ${course.languageCode}',
                    maxLines: 1,
                    style: TextStyle(
                      color: _homeText,
                      fontSize: isMobile ? 12 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
                  ],
                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x78000000),
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
            if (selected)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: isMobile ? 112 : 132,
                      height: isMobile ? 36 : 40,
                      child: OutlinedButton.icon(
                        onPressed: () => this.openFlashCards(course),
                        icon: Icon(Icons.style_rounded, size: 17),
                        label: Text('Học thẻ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xd90b0d12),
                          side: BorderSide(color: Color(0xff4f7ee8)),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          textStyle: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 7 : 9),
                    SizedBox(
                      width: isMobile ? 112 : 132,
                      height: isMobile ? 36 : 40,
                      child: OutlinedButton.icon(
                        onPressed: () => this.openReviewPractice(course),
                        icon: SvgPicture.asset(
                          'assets/icon/lightbulb-solid-full.svg',
                          width: 17,
                          height: 17,
                          colorFilter: ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: Text('Kiểm tra'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xd90b0d12),
                          side: BorderSide(color: Color(0xff4f7ee8)),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          textStyle: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 7 : 9),
                    SizedBox(
                      width: isMobile ? 112 : 132,
                      height: isMobile ? 36 : 40,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            this.openVocabularyReminderSettings(course),
                        icon: SvgPicture.asset(
                          'assets/icon/bell-solid-full.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: Text('Toast'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xd90b0d12),
                          side: BorderSide(color: Color(0xff4f7ee8)),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          textStyle: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const _HomeDashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    const dashLength = 7.0;
    const gapLength = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeDashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class AutoShrinkText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final double minFontSize;
  final double minSingleLineFontSize;
  final TextAlign textAlign;
  final TextOverflow overflow;

  const AutoShrinkText(
    this.text, {
    Key? key,
    required this.style,
    this.maxLines = 2,
    this.minFontSize = 10,
    this.minSingleLineFontSize = 13,
    this.textAlign = TextAlign.left,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || maxWidth.isInfinite) {
          return Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          );
        }

        final double maxFontSize = style.fontSize ?? 14.0;

        // 1. Try to fit on 1 line if maxLines > 1
        if (maxLines > 1) {
          for (double s = maxFontSize; s >= minSingleLineFontSize; s -= 1.0) {
            final textPainter = TextPainter(
              text: TextSpan(text: text, style: style.copyWith(fontSize: s)),
              maxLines: 1,
              textDirection: TextDirection.ltr,
              textAlign: textAlign,
            );
            textPainter.layout(maxWidth: maxWidth);
            if (!textPainter.didExceedMaxLines) {
              return Text(
                text,
                maxLines: 1,
                overflow: overflow,
                textAlign: textAlign,
                style: style.copyWith(fontSize: s),
              );
            }
          }
        }

        // 2. Try to fit within maxLines
        double chosenFontSize = minFontSize;
        for (double s = maxFontSize; s >= minFontSize; s -= 1.0) {
          final textPainter = TextPainter(
            text: TextSpan(text: text, style: style.copyWith(fontSize: s)),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
          );
          textPainter.layout(maxWidth: maxWidth);
          if (!textPainter.didExceedMaxLines) {
            chosenFontSize = s;
            break;
          }
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: style.copyWith(fontSize: chosenFontSize),
        );
      },
    );
  }
}
