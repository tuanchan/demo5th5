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
          'Bạn vẫn có thể dùng app mà không cần đăng nhập.',
          style: TextStyle(
            color: Color(0xff91a0bd),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 14),
        // Google Sign-In button
        InkWell(
          onTap: () => this._signInWithGoogle(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xff202634), width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icon/google-icon-logo-svgrepo-com.svg',
                  width: 20,
                  height: 20,
                ),
                SizedBox(width: 10),
                Text(
                  'Đăng nhập bằng Google',
                  style: TextStyle(
                    color: Color(0xfff8fbff),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        // Email Sign-Up / Sign-In button
        Row(
          children: [
            Expanded(
              child: this._actionButton(
                text: 'Đăng ký email',
                icon: Icons.email_rounded,
                color: Color(0xff9ab9ff),
                onTap: () => this._showEmailAuthDialog(context, isSignUp: true),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: this._actionButton(
                text: 'Đăng nhập email',
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

  Future<void> _signInWithGoogle(BuildContext ctx) async {
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

      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      if (mounted) {
        setState(() {});
        showAppToast(ctx, 'Đang chuyển đến Google...');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(ctx, 'Đăng nhập Google thất bại: $e');
      }
    }
  }

  Future<void> _showEmailAuthDialog(
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
    return message;
  }
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
