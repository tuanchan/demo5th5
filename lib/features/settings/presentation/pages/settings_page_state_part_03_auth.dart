part of flutterflashcard_main;

extension SettingsPageStateAuth on _SettingsPageState {
  void _resumeAccountSyncStatus() {
    final activeSync = SupabaseSyncService.instance.activeSync;
    if (activeSync == null) return;

    accountSyncing = true;
    unawaited(
      activeSync.then((result) {
        if (!mounted) return;
        setState(() {
          accountSyncing = false;
          accountSyncSucceeded = !result.hasError;
          accountSyncMessage = result.hasError
              ? 'Đồng bộ thất bại: ${result.error}'
              : result.downloadSummary;
        });
      }),
    );
  }

  /// Build the account / auth section card for the settings page.
  Widget _buildAccountSection() {
    return FutureBuilder<_AuthDisplayInfo>(
      future: _loadAuthDisplayInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data ?? _AuthDisplayInfo.anonymous();
        return this._sectionCard(
          title: 'Tài khoản',
          icon: Icons.person_rounded,
          child: info.isLoggedIn
              ? this._buildLoggedInContent(info)
              : this._buildLoggedOutContent(),
        );
      },
    );
  }

  Widget _buildLoggedOutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đăng nhập để đồng bộ dữ liệu giữa các thiết bị.\n'
          'Hỗ trợ email, xác thực tài khoản và Google.',
          style: TextStyle(
            color: Color(0xff91a0bd),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: this._actionButton(
                text: 'Đăng ký',
                icon: Icons.person_add_alt_1_rounded,
                color: Color(0xff9ab9ff),
                onTap: () => this._showEmailAuthDialog(context, isSignUp: true),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: this._actionButton(
                text: 'Đăng nhập',
                icon: Icons.login_rounded,
                color: Color(0xff8ee88b),
                onTap: () => this._showEmailAuthDialog(context, isSignUp: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoggedInContent(_AuthDisplayInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User info row
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xff202634), width: 1.0),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  color: Color(0xff202634),
                  child: (info.avatarUrl != null && info.avatarUrl!.isNotEmpty)
                      ? Image.network(
                          info.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person_rounded, color: Color(0xff9ab9ff));
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xff9ab9ff),
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(Icons.person_rounded, color: Color(0xff9ab9ff)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xfff8fbff),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      info.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff91a0bd),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        // Sync + Logout buttons
        Row(
          children: [
            Expanded(
              child: this._actionButton(
                text: accountSyncing ? 'Đang đồng bộ...' : 'Đồng bộ dữ liệu',
                icon: Icons.sync_rounded,
                color: Color(0xff8ee88b),
                onTap: accountSyncing
                    ? () {}
                    : () => this._syncData(context),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: this._actionButton(
                text: 'Đăng xuất',
                icon: Icons.logout_rounded,
                color: Color(0xffffff9f),
                onTap: () => this._signOut(context),
              ),
            ),
          ],
        ),
        if (accountSyncing || accountSyncMessage.isNotEmpty) ...[
          SizedBox(height: 12),
          this._buildAccountSyncStatus(),
        ],
      ],
    );
  }

  Widget _buildAccountSyncStatus() {
    final succeeded = accountSyncSucceeded;
    final accent = accountSyncing
        ? Color(0xff9ab9ff)
        : (succeeded == true ? Color(0xff8ee88b) : Color(0xffff9f9f));

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (accountSyncing)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: accent,
                  ),
                )
              else
                Icon(
                  succeeded == true
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: accent,
                  size: 19,
                ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  accountSyncing
                      ? 'Đang đồng bộ dữ liệu...'
                      : accountSyncMessage,
                  style: TextStyle(
                    color: Color(0xfff8fbff),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (accountSyncing) ...[
            SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                color: accent,
                backgroundColor: Color(0xff202634),
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Đang đẩy dữ liệu lên và tải thay đổi mới nhất về thiết bị.',
              style: TextStyle(
                color: Color(0xff91a0bd),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== Auth actions ==========

  Future<String?> _signInWithGoogle(BuildContext ctx) async {
    try {
      String? redirectTo;
      if (kIsWeb) {
        redirectTo = null;
      } else if (Platform.isAndroid || Platform.isIOS) {
        redirectTo = 'com.example.flutterflashcard://login-callback/';
      } else {
        // Windows/macOS/Linux desktop loopback redirect
        redirectTo = 'http://localhost:3000/';
        
        // Start the local web server to capture the code exchange
        _globalDesktopOAuthServer ??= _DesktopOAuthServer();
        await _globalDesktopOAuthServer!.start((code) async {
          try {
            await SupabaseConfig.client.auth.exchangeCodeForSession(code);
            if (mounted) {
              setState(() {});
              showAppToast(ctx, 'Đăng nhập thành công!');
            }
          } catch (e) {
            if (mounted) {
              showAppToast(ctx, 'Xác thực tài khoản thất bại: $e');
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
      if (mounted) {
        setState(() {});
        showAppToast(ctx, 'Đang chuyển đến Google...');
      }
      return null;
    } catch (e) {
      final message = 'Đăng nhập Google thất bại: $e';
      if (mounted) {
        showAppToast(ctx, message);
      }
      return message;
    }
  }

  Future<void> _showEmailAuthDialog(
    BuildContext ctx, {
    required bool isSignUp,
  }) async {
    final loggedIn = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(
        builder: (_) => _FlashcardsLoginPage(
          initialAuthMode: isSignUp ? AuthMode.signup : AuthMode.login,
          onGoogleLogin: () => this._signInWithGoogle(ctx),
          translateAuthError: this._translateAuthError,
        ),
      ),
    );

    if (!mounted || loggedIn != true) return;
    setState(() {});
    if (SupabaseConfig.isLoggedIn) {
      showAppToast(ctx, 'Đăng nhập thành công!');
      unawaited(this._syncData(ctx));
    }
  }

  Future<void> _showLegacyEmailAuthDialog(
    BuildContext ctx, {
    required bool isSignUp,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? errorMessage;

    await showDialog(
      context: ctx,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xff07090d),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xff202634), width: 1.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSignUp ? 'Đăng ký tài khoản' : 'Đăng nhập',
                              style: TextStyle(
                                color: Color(0xfff8fbff),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Color(0xff91a0bd),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: Color(0xfff8fbff),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Color(0xff91a0bd)),
                          filled: true,
                          fillColor: Color(0xff000000),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Color(0xff91a0bd),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xff202634),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xff9ab9ff),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: TextStyle(
                          color: Color(0xfff8fbff),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          labelStyle: TextStyle(color: Color(0xff91a0bd)),
                          filled: true,
                          fillColor: Color(0xff000000),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xff91a0bd),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xff202634),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xff9ab9ff),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: this._actionButton(
                              text: isSignUp ? 'Đăng ký' : 'Đăng nhập',
                              icon: isSignUp
                                  ? Icons.person_add_rounded
                                  : Icons.login_rounded,
                              color: Color(0xff8ee88b),
                              onTap: () async {
                                final email = emailController.text.trim();
                                final password = passwordController.text.trim();

                                if (email.isEmpty || password.isEmpty) {
                                  setDialogState(() {
                                    errorMessage =
                                        'Vui lòng nhập email và mật khẩu';
                                  });
                                  return;
                                }

                                if (password.length < 6) {
                                  setDialogState(() {
                                    errorMessage =
                                        'Mật khẩu phải ít nhất 6 ký tự';
                                  });
                                  return;
                                }

                                try {
                                  if (isSignUp) {
                                    await SupabaseConfig.client.auth.signUp(
                                      email: email,
                                      password: password,
                                    );
                                    if (!dialogContext.mounted) return;
                                    Navigator.pop(dialogContext);
                                    if (mounted) {
                                      setState(() {});
                                      showAppToast(
                                        ctx,
                                        'Đăng ký thành công! Kiểm tra email để xác nhận.',
                                      );
                                    }
                                  } else {
                                    await SupabaseConfig.client.auth
                                        .signInWithPassword(
                                      email: email,
                                      password: password,
                                    );
                                    if (!dialogContext.mounted) return;
                                    Navigator.pop(dialogContext);
                                    if (mounted) {
                                      setState(() {});
                                      showAppToast(
                                        ctx,
                                        'Đăng nhập thành công!',
                                      );
                                      // Auto-sync after login
                                      this._syncData(ctx);
                                    }
                                  }
                                } on AuthException catch (e) {
                                  setDialogState(() {
                                    errorMessage =
                                        _translateAuthError(e.message);
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    errorMessage = 'Có lỗi: $e';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _syncData(BuildContext ctx) async {
    if (accountSyncing) return;
    if (mounted) {
      setState(() {
        accountSyncing = true;
        accountSyncSucceeded = null;
        accountSyncMessage = '';
      });
    }
    showAppToast(ctx, 'Đang đồng bộ dữ liệu...');

    SyncResult result;
    try {
      result = await SupabaseSyncService.instance.syncAll();
    } catch (error) {
      result = SyncResult(pushed: 0, pulled: 0, error: error.toString());
    }

    if (mounted) {
      if (result.hasError) {
        setState(() {
          accountSyncing = false;
          accountSyncSucceeded = false;
          accountSyncMessage = 'Đồng bộ thất bại: ${result.error}';
        });
        showAppToast(ctx, 'Đồng bộ thất bại: ${result.error}');
      } else {
        setState(() {
          accountSyncing = false;
          accountSyncSucceeded = true;
          accountSyncMessage = result.downloadSummary;
        });
        showAppToast(
          ctx,
          result.downloadSummary,
        );
      }
    }
  }

  Future<void> _signOut(BuildContext ctx) async {
    if (SupabaseSyncService.instance.isSyncing) {
      if (ctx.mounted) {
        showAppToast(
          ctx,
          'Đang đồng bộ dữ liệu. Vui lòng đợi hoàn tất trước khi đăng xuất.',
        );
      }
      return;
    }

    try {
      await SupabaseConfig.client.auth.signOut();
      if (mounted) {
        setState(() {});
        showAppToast(ctx, 'Đã đăng xuất');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(ctx, 'Đăng xuất thất bại: $e');
      }
    }
  }

  // ========== Helpers ==========

  Future<_AuthDisplayInfo> _loadAuthDisplayInfo() async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return _AuthDisplayInfo.anonymous();

    final meta = user.userMetadata;
    return _AuthDisplayInfo(
      isLoggedIn: true,
      email: user.email ?? '',
      displayName: meta?['full_name']?.toString() ??
          meta?['display_name']?.toString() ??
          meta?['name']?.toString() ??
          user.email?.split('@').first ??
          'Người dùng',
      avatarUrl: meta?['avatar_url']?.toString() ??
          meta?['picture']?.toString(),
    );
  }

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'Email này đã được đăng ký';
    }
    if (lower.contains('invalid email')) {
      return 'Email không hợp lệ';
    }
    if (lower.contains('weak password') ||
        lower.contains('at least')) {
      return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Quá nhiều lần thử. Vui lòng đợi một lát.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Vui lòng xác nhận email trước khi đăng nhập';
    }
    if (lower.contains('email address not authorized')) {
      return 'SMTP Supabase chưa cho phép gửi tới email này';
    }
    if (lower.contains('error sending confirmation email') ||
        lower.contains('smtp')) {
      return 'Không gửi được email xác thực. Hãy kiểm tra cấu hình SMTP.';
    }
    return message;
  }
}


const int _signupEmailOtpLength = 8;


class _FlashcardsLoginPage extends StatefulWidget {
  final AuthMode initialAuthMode;
  final Future<String?> Function() onGoogleLogin;
  final String Function(String message) translateAuthError;

  const _FlashcardsLoginPage({
    required this.initialAuthMode,
    required this.onGoogleLogin,
    required this.translateAuthError,
  });

  @override
  State<_FlashcardsLoginPage> createState() => _FlashcardsLoginPageState();
}


class _FlashcardsLoginPageState extends State<_FlashcardsLoginPage> {
  bool _loginCompleted = false;
  bool _googleLoginBusy = false;
  bool _showGoogleLogin = false;
  bool _showOtpScreen = false;
  bool _verifyingOtp = false;
  Timer? _googleRevealTimer;
  Timer? _otpScreenTimer;
  String? _pendingVerificationEmail;
  String? _otpError;
  TextEditingController? _otpControllerValue;

  TextEditingController get _otpController =>
      _otpControllerValue ??= TextEditingController();

  @override
  void initState() {
    super.initState();
    // flutter_login waits 1s, opens the card for 400ms, then reveals the
    // form for 1150ms. Show Google only after that complete sequence.
    _scheduleGoogleReveal(const Duration(milliseconds: 2600));
  }

  void _scheduleGoogleReveal(Duration delay, {bool hideFirst = false}) {
    _googleRevealTimer?.cancel();
    if (hideFirst && _showGoogleLogin) {
      setState(() => _showGoogleLogin = false);
    }
    _googleRevealTimer = Timer(delay, () {
      if (mounted) setState(() => _showGoogleLogin = true);
    });
  }

  void _handleAuthModeSwitch(AuthMode _) {
    // Signup/login field transition takes 800ms plus a 150ms finishing pass.
    _scheduleGoogleReveal(
      const Duration(milliseconds: 950),
      hideFirst: true,
    );
  }

  @override
  void dispose() {
    _googleRevealTimer?.cancel();
    _otpScreenTimer?.cancel();
    _otpControllerValue?.dispose();
    super.dispose();
  }

  String? get _emailRedirectTo {
    if (kIsWeb) return Uri.base.origin;
    if (Platform.isAndroid || Platform.isIOS) {
      return 'com.example.flutterflashcard://login-callback/';
    }
    return null;
  }

  Future<String?> _login(LoginData data) async {
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: data.name.trim(),
        password: data.password,
      );
      final user = response.user;
      if (user == null) return 'Không tìm thấy tài khoản';

      if (user.emailConfirmedAt == null) {
        await SupabaseConfig.client.auth.signOut();
        if (mounted) {
          setState(() => _pendingVerificationEmail = data.name.trim());
        }
        return 'Email chưa được xác thực. Hãy mở email xác nhận rồi đăng nhập lại.';
      }

      _loginCompleted = true;
      return null;
    } on AuthException catch (error) {
      return widget.translateAuthError(error.message);
    } catch (error) {
      return 'Không thể đăng nhập: $error';
    }
  }

  Future<String?> _signup(SignupData data) async {
    final email = data.name?.trim() ?? '';
    final password = data.password ?? '';
    if (email.isEmpty || password.isEmpty) {
      return 'Vui lòng nhập email và mật khẩu';
    }

    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo,
      );
      if (response.user == null) return 'Không thể tạo tài khoản';

      // Confirm email phải được bật trong Supabase. Không giữ phiên đăng nhập
      // trước khi người dùng xác thực địa chỉ email.
      if (response.session != null) {
        await SupabaseConfig.client.auth.signOut();
        return 'Supabase chưa bật Confirm email. Hãy bật xác thực email rồi thử lại.';
      }
      _pendingVerificationEmail = email;
      _otpController.clear();
      _otpError = null;
      _otpScreenTimer?.cancel();
      // Let flutter_login finish its signup-to-login transition before
      // replacing the form with the OTP verification screen.
      _otpScreenTimer = Timer(const Duration(milliseconds: 950), () {
        if (mounted) setState(() => _showOtpScreen = true);
      });
      _loginCompleted = false;
      return null;
    } on AuthException catch (error) {
      return widget.translateAuthError(error.message);
    } catch (error) {
      return 'Không thể đăng ký: $error';
    }
  }

  Future<String?> _recoverPassword(String email) async {
    try {
      var redirectTo = _emailRedirectTo;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        redirectTo = 'http://localhost:3000/';
        _globalDesktopOAuthServer ??= _DesktopOAuthServer();
        await _globalDesktopOAuthServer!.start((code) async {
          try {
            await SupabaseConfig.client.auth.exchangeCodeForSession(code);
            if (mounted) await showPasswordResetDialog(context);
          } finally {
            await _globalDesktopOAuthServer!.stop();
          }
        });
      }
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
      return null;
    } on AuthException catch (error) {
      return widget.translateAuthError(error.message);
    } catch (error) {
      return 'Không thể gửi email đặt lại mật khẩu: $error';
    }
  }

  Future<String?> _googleLogin() async {
    final error = await widget.onGoogleLogin();
    if (error == null) _loginCompleted = true;
    return error;
  }

  Future<void> _handleGoogleSvgLogin() async {
    if (_googleLoginBusy) return;
    setState(() => _googleLoginBusy = true);
    final error = await _googleLogin();
    if (!mounted) return;
    setState(() => _googleLoginBusy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _resendVerificationEmail() async {
    final email = _pendingVerificationEmail;
    if (email == null) return;
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _emailRedirectTo,
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _otpError = null;
        _showOtpScreen = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi lại mã OTP tới $email')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.translateAuthError(error.message))),
      );
    }
  }

  Future<void> _verifySignupOtp() async {
    if (_verifyingOtp) return;
    final email = _pendingVerificationEmail;
    final token = _otpController.text.trim();
    if (email == null) return;
    if (token.length != _signupEmailOtpLength) {
      setState(
        () => _otpError =
            'Vui lòng nhập đủ $_signupEmailOtpLength số',
      );
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });
    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      if (response.user == null) {
        throw const AuthException('Không thể xác thực mã OTP');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifyingOtp = false;
        _otpError = error.message.toLowerCase().contains('expired')
            ? 'Mã OTP đã hết hạn. Hãy gửi lại mã mới.'
            : 'Mã OTP không đúng hoặc đã hết hạn';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifyingOtp = false;
        _otpError = 'Không thể xác thực: $error';
      });
    }
  }

  Widget _buildOtpVerificationScreen(ThemeData darkTheme) {
    final email = _pendingVerificationEmail!;
    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 390),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icon/app_icon.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'XÁC THỰC EMAIL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xfff8fbff),
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nhập mã OTP $_signupEmailOtpLength số đã gửi tới\n$email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xff91a0bd),
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 28),
                        _EmailOtpCodeField(
                          controller: _otpController,
                          enabled: !_verifyingOtp,
                          onCompleted: _verifySignupOtp,
                        ),
                        if (_otpError != null) ...[
                          SizedBox(height: 12),
                          Text(
                            _otpError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xffff7f87),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                _verifyingOtp ? null : _verifySignupOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff4257ff),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _verifyingOtp
                                ? SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'XÁC THỰC',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _verifyingOtp
                              ? null
                              : _resendVerificationEmail,
                          icon: Icon(Icons.mark_email_unread_rounded, size: 18),
                          label: Text('Gửi lại mã OTP'),
                          style: TextButton.styleFrom(
                            foregroundColor: Color(0xff9ab9ff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  tooltip: 'Quay lại đăng nhập',
                  onPressed: _verifyingOtp
                      ? null
                      : () {
                          setState(() {
                            _showOtpScreen = false;
                            _otpError = null;
                          });
                        },
                  icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationNotice() {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _resendVerificationEmail,
          style: TextButton.styleFrom(
            foregroundColor: Color(0xff9ab9ff),
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(Icons.mark_email_unread_rounded, size: 18),
          label: Text(
            'Gửi lại email',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Mật khẩu cần có cả chữ và số';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Color(0xff000000),
      colorScheme: ColorScheme.dark(
        primary: Color(0xff4257ff),
        secondary: Color(0xff9ab9ff),
        surface: Color(0xff0b0d12),
        error: Color(0xffff7f87),
      ),
    );

    if (_showOtpScreen && _pendingVerificationEmail != null) {
      return _buildOtpVerificationScreen(darkTheme);
    }

    return Theme(
      data: darkTheme,
      child: Stack(
        children: [
          FlutterLogin(
            title: 'FLASH CARDS',
            logo: AssetImage('assets/icon/app_icon.png'),
            initialAuthMode: widget.initialAuthMode,
            userType: LoginUserType.email,
            onLogin: _login,
            onSignup: _signup,
            onRecoverPassword: _recoverPassword,
            onSubmitAnimationCompleted: () {
              if (_loginCompleted && mounted) Navigator.pop(context, true);
            },
            loginProviders: const [],
            loginAfterSignUp: false,
            headerWidget: _pendingVerificationEmail == null
                ? null
                : _buildVerificationNotice(),
            navigateBackAfterRecovery: true,
            scrollable: true,
            disableCustomPageTransformer: true,
            onSwitchAuthMode: _handleAuthModeSwitch,
            validateUserImmediately: true,
            userValidator: _validateEmail,
            passwordValidator: _validatePassword,
            messages: LoginMessages(
              userHint: 'Email',
              passwordHint: 'Mật khẩu',
              confirmPasswordHint: 'Nhập lại mật khẩu',
              forgotPasswordButton: 'Quên mật khẩu?',
              loginButton: 'ĐĂNG NHẬP',
              signupButton: 'ĐĂNG KÝ',
              recoverPasswordButton: 'GỬI EMAIL KHÔI PHỤC',
              recoverPasswordIntro: 'Khôi phục mật khẩu',
              recoverPasswordDescription:
                  'Nhập email để nhận liên kết đặt lại mật khẩu.',
              goBackButton: 'QUAY LẠI',
              confirmPasswordError: 'Mật khẩu nhập lại không khớp',
              recoverPasswordSuccess:
                  'Đã gửi email khôi phục. Hãy kiểm tra hộp thư.',
              signUpSuccess:
                  'Đã gửi email xác thực. Hãy xác nhận trước khi đăng nhập.',
              flushbarTitleError: 'Không thành công',
              flushbarTitleSuccess: 'Thành công',
              providersTitleFirst: 'Hoặc đăng nhập',
              providersTitleSecond: 'với',
            ),
            theme: LoginTheme(
              primaryColor: Color(0xff000000),
              pageColorLight: Color(0xff000000),
              pageColorDark: Color(0xff000000),
              accentColor: Color(0xff9ab9ff),
              errorColor: Color(0xffff7f87),
              switchAuthTextColor: Color(0xff9ab9ff),
              logoWidth: 0.42,
              titleStyle: TextStyle(
                color: Color(0xfff8fbff),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
              bodyStyle: TextStyle(color: Color(0xff91a0bd)),
              textFieldStyle: TextStyle(
                color: Color(0xfff8fbff),
                fontWeight: FontWeight.w700,
              ),
              buttonStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              cardTheme: CardTheme(
                color: Color(0xff0b0d12),
                surfaceTintColor: Colors.transparent,
                elevation: 18,
                margin: EdgeInsets.only(top: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Color(0xff242b3a)),
                ),
              ),
              inputTheme: InputDecorationTheme(
                filled: true,
                fillColor: Color(0xff11151d),
                labelStyle: TextStyle(color: Color(0xff91a0bd)),
                prefixIconColor: Color(0xff9ab9ff),
                suffixIconColor: Color(0xff91a0bd),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xff2a3342)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(0xff4257ff),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xffff7f87)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(0xffff7f87),
                    width: 1.5,
                  ),
                ),
              ),
              buttonTheme: LoginButtonTheme(
                backgroundColor: Color(0xff4257ff),
                splashColor: Color(0xff7281ff),
                highlightColor: Color(0xff3346da),
                elevation: 0,
                highlightElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            footer: 'Đồng bộ an toàn với tài khoản của bạn',
          ),
          if (_showGoogleLogin &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 94,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Tooltip(
                    message: 'Đăng nhập với Google',
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        onTap: _googleLoginBusy
                            ? null
                            : _handleGoogleSvgLogin,
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        radius: 24,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: _googleLoginBusy
                                ? SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Color(0xff9ab9ff),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    'assets/icon/google-icon-logo-svgrepo-com.svg',
                                    width: 27,
                                    height: 27,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _EmailOtpCodeField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCompleted;

  const _EmailOtpCodeField({
    required this.controller,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  State<_EmailOtpCodeField> createState() => _EmailOtpCodeFieldState();
}


class _EmailOtpCodeFieldState extends State<_EmailOtpCodeField> {
  final FocusNode _focusNode = FocusNode();
  String? _lastCompletedCode;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleCodeChanged);
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _EmailOtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleCodeChanged);
      widget.controller.addListener(_handleCodeChanged);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _handleCodeChanged() {
    final code = widget.controller.text;
    if (mounted) setState(() {});
    if (code.length == _signupEmailOtpLength &&
        code != _lastCompletedCode) {
      _lastCompletedCode = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) widget.onCompleted();
      });
    } else if (code.length < _signupEmailOtpLength) {
      _lastCompletedCode = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleCodeChanged);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focusNode.requestFocus : null,
      child: SizedBox(
        height: 58,
        child: Stack(
          children: [
            Row(
              children: List.generate(_signupEmailOtpLength, (index) {
                final isActive = widget.enabled &&
                    _focusNode.hasFocus &&
                    index == code.length.clamp(0, _signupEmailOtpLength - 1);
                return Expanded(
                  child: Container(
                    height: 56,
                    margin: EdgeInsets.only(
                      right: index == _signupEmailOtpLength - 1 ? 0 : 5,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(0xff11151d),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isActive
                            ? Color(0xff9ab9ff)
                            : Color(0xff2a3342),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      index < code.length ? code[index] : '',
                      style: TextStyle(
                        color: Color(0xfff8fbff),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_signupEmailOtpLength),
                  ],
                  onSubmitted: (_) {
                    if (widget.controller.text.length ==
                        _signupEmailOtpLength) {
                      widget.onCompleted();
                    }
                  },
                  decoration: InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


Future<void> showPasswordResetDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  var obscurePassword = true;
  var saving = false;
  String? errorMessage;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          InputDecoration decoration(String label) => InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Color(0xff91a0bd)),
            filled: true,
            fillColor: Color(0xff11151d),
            suffixIcon: IconButton(
              onPressed: () => setDialogState(
                () => obscurePassword = !obscurePassword,
              ),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Color(0xff91a0bd),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xff2a3342)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xff4257ff), width: 1.5),
            ),
          );

          return Dialog(
            backgroundColor: Color(0xff0b0d12),
            insetPadding: EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Color(0xff242b3a)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đặt mật khẩu mới',
                      style: TextStyle(
                        color: Color(0xfff8fbff),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Mật khẩu cần ít nhất 8 ký tự, gồm chữ và số.',
                      style: TextStyle(color: Color(0xff91a0bd)),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: TextStyle(color: Colors.white),
                      decoration: decoration('Mật khẩu mới'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscurePassword,
                      style: TextStyle(color: Colors.white),
                      decoration: decoration('Nhập lại mật khẩu'),
                    ),
                    if (errorMessage != null) ...[
                      SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Color(0xffff7f87)),
                      ),
                    ],
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final password = passwordController.text;
                                final valid = password.length >= 8 &&
                                    RegExp(r'[A-Za-z]').hasMatch(password) &&
                                    RegExp(r'[0-9]').hasMatch(password);
                                if (!valid) {
                                  setDialogState(() {
                                    errorMessage =
                                        'Mật khẩu cần ít nhất 8 ký tự, gồm chữ và số';
                                  });
                                  return;
                                }
                                if (password != confirmController.text) {
                                  setDialogState(() {
                                    errorMessage = 'Mật khẩu nhập lại không khớp';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  saving = true;
                                  errorMessage = null;
                                });
                                try {
                                  await SupabaseConfig.client.auth.updateUser(
                                    UserAttributes(password: password),
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (context.mounted) {
                                    showAppToast(
                                      context,
                                      'Đã cập nhật mật khẩu',
                                    );
                                  }
                                } on AuthException catch (error) {
                                  setDialogState(() {
                                    saving = false;
                                    errorMessage = error.message;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff4257ff),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: saving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'CẬP NHẬT MẬT KHẨU',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  passwordController.dispose();
  confirmController.dispose();
}


class _AuthDisplayInfo {
  final bool isLoggedIn;
  final String email;
  final String displayName;
  final String? avatarUrl;

  _AuthDisplayInfo({
    required this.isLoggedIn,
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  factory _AuthDisplayInfo.anonymous() => _AuthDisplayInfo(
        isLoggedIn: false,
        email: '',
        displayName: '',
      );
}

_DesktopOAuthServer? _globalDesktopOAuthServer;

class _DesktopOAuthServer {
  HttpServer? _server;

  Future<void> start(Function(String code) onCodeReceived) async {
    await stop();
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      _server!.listen((HttpRequest request) async {
        final code = request.uri.queryParameters['code'];
        final response = request.response;
        
        response.headers.contentType = ContentType.html;

        if (code != null && code.isNotEmpty) {
          response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Đăng nhập thành công</title>
  <style>
    body {
      font-family: sans-serif;
      background-color: #07090d;
      color: #f8fbff;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background-color: #121824;
      padding: 30px;
      border-radius: 12px;
      text-align: center;
      border: 1px solid #202634;
      box-shadow: 0 4px 12px rgba(0,0,0,0.5);
    }
    h1 { color: #8ee88b; margin-top: 0; }
    p { margin: 8px 0; color: #91a0bd; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Đăng nhập thành công!</h1>
    <p>Bạn đã đăng nhập thành công vào ứng dụng Flashcard.</p>
    <p>Bây giờ bạn có thể đóng trình duyệt này và quay lại ứng dụng.</p>
  </div>
</body>
</html>
''');
          await response.close();
          onCodeReceived(code);
        } else {
          response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Đăng nhập thất bại</title>
  <style>
    body {
      font-family: sans-serif;
      background-color: #07090d;
      color: #f8fbff;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background-color: #121824;
      padding: 30px;
      border-radius: 12px;
      text-align: center;
      border: 1px solid #202634;
      box-shadow: 0 4px 12px rgba(0,0,0,0.5);
    }
    h1 { color: #ff6b6b; margin-top: 0; }
    p { margin: 8px 0; color: #91a0bd; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Đăng nhập thất bại</h1>
    <p>Không tìm thấy mã xác thực trong URL chuyển hướng.</p>
  </div>
</body>
</html>
''');
          await response.close();
        }
      });
    } catch (e) {
      debugPrint('Error starting local server: \$e');
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}
