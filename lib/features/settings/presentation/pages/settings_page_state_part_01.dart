part of flutterflashcard_main;

extension SettingsPageStatePart01 on _SettingsPageState {
  Widget _buildSettingsPagePage(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff000000),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  this._roundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context, true),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cài Đặt',
                      style: TextStyle(
                        color: Color(0xfff8fbff),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              this._sectionCard(
                title: 'Gemini API Key',
                icon: Icons.key_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: geminiApiKeyController,
                      obscureText: !showGeminiApiKey,
                      style: TextStyle(
                        color: Color(0xfff8fbff),
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập API key Gemini',
                        hintStyle: TextStyle(color: Color(0xff91a0bd)),
                        filled: true,
                        fillColor: Color(0xff07090d),
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(12),
                          child: geminiColorIcon(size: 20),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => showGeminiApiKey = !showGeminiApiKey,
                          ),
                          icon: Icon(
                            showGeminiApiKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Color(0xff91a0bd),
                          ),
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
                    SizedBox(height: 10),
                    Text(
                      geminiKeyMessage,
                      style: TextStyle(
                        color: Color(0xff91a0bd),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: this._actionButton(
                            text: 'Lưu key',
                            icon: Icons.save_rounded,
                            color: Color(0xff8ee88b),
                            onTap: this.saveGeminiApiKey,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._actionButton(
                            text: 'Lấy key',
                            icon: Icons.open_in_new_rounded,
                            color: Color(0xfff5c400),
                            onTap: this.openGeminiApiKeyPage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              this._buildAccountSection(),
              SizedBox(height: 14),
              this._sectionCard(
                title: 'Đối chiếu & Xuất bản Database',
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Các tùy chọn dành cho Nhà phát triển để đồng bộ SQLite và Supabase, hoặc đóng gói dữ liệu vào assets.',
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
                            text: 'Xuất sang Assets',
                            icon: Icons.input_rounded,
                            color: Color(0xff8ee88b),
                            onTap: () async {
                              try {
                                final res = await BackupManager.exportToProjectAssets();
                                if (mounted) showAppToast(context, res);
                              } catch (e) {
                                if (mounted) showAppToast(context, 'Thất bại: $e');
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._actionButton(
                            text: 'Mở thư mục DB',
                            icon: Icons.folder_open_rounded,
                            color: Color(0xffa1a7fb),
                            onTap: () async {
                              try {
                                await BackupManager.openDbFolder();
                                if (mounted) showAppToast(context, 'Đang mở thư mục database...');
                              } catch (e) {
                                if (mounted) showAppToast(context, 'Thất bại: $e');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  Future<void> loadSettings() async {
    final mode =
        await AppSettingsStore.getString('appearance.themeMode') ?? 'light';
    final geminiApiKey =
        await AppSettingsStore.getString(
          GeminiFlashLiteClient.apiKeySettingKey,
        ) ??
        '';
    if (!mounted) return;
    setState(() {
      themeMode = mode;
      geminiApiKeyController.text = geminiApiKey;
    });
  }


  Future<void> changeThemeMode(String value) async {
    await AppSettingsStore.setString('appearance.themeMode', value);
    await AppColors.load(context: context);
    AppThemeController.instance.bump();
    if (!mounted) return;
    setState(() => themeMode = value);
  }


  Future<void> openGeminiApiKeyPage() async {
    try {
      final opened = await launchUrl(
        _geminiApiKeyUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(
          () => geminiKeyMessage = 'Không mở được trang lấy key Gemini',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => geminiKeyMessage = 'Không mở được trang lấy key Gemini');
    }
  }


  Future<void> saveGeminiApiKey() async {
    final key = geminiApiKeyController.text.trim();
    await AppSettingsStore.setString(
      GeminiFlashLiteClient.apiKeySettingKey,
      key,
    );
    if (!mounted) return;
    setState(() {
      geminiKeyMessage = key.isEmpty
          ? 'Đã xoá key riêng, quay về API key mặc định'
          : 'Đã lưu API key Gemini';
    });
  }


  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Color(0xff07090d),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xff202634), width: 1.0),
        ),
        child: Icon(icon, color: Color(0xfff8fbff), size: 20),
      ),
    );
  }


  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xff07090d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xff202634), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xff9ab9ff), size: 18),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Color(0xfff8fbff),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }


  Widget _actionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xff202634), width: 1.0),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xfff8fbff),
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
