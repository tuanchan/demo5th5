part of flutterflashcard_main;

extension SettingsPageStatePart01 on _SettingsPageState {
  Widget _buildSettingsPagePage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  this._roundIconButton(
                    icon: Icons.restart_alt_rounded,
                    onTap: () async {
                      await AppColors.resetColors(context: context);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              this._sectionCard(
                title: 'Giao diện',
                icon: Icons.dark_mode_rounded,
                child: Column(
                  children: [
                    this._modeTile(
                      'system',
                      'Theo điện thoại',
                      Icons.phone_iphone_rounded,
                    ),
                    this._modeTile('light', 'Sáng', Icons.light_mode_rounded),
                    this._modeTile('dark', 'Tối', Icons.nightlight_round),
                  ],
                ),
              ),
              SizedBox(height: 14),
              this._sectionCard(
                title: 'Gemini API',
                icon: Icons.key_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: geminiApiKeyController,
                      obscureText: !showGeminiApiKey,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập API key Gemini',
                        filled: true,
                        fillColor: AppColors.panel2,
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
                            color: AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.border.withOpacity(0.45),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      geminiKeyMessage,
                      style: TextStyle(
                        color: AppColors.muted,
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
                            color: AppColors.green,
                            onTap: this.saveGeminiApiKey,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._actionButton(
                            text: 'Lấy key',
                            icon: Icons.open_in_new_rounded,
                            color: AppColors.yellow,
                            onTap: this.openGeminiApiKeyPage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              this._sectionCard(
                title: 'Chỉnh màu toàn bộ giao diện',
                icon: Icons.palette_rounded,
                child: Column(
                  children: colorNames.entries
                      .map((entry) => this._colorRow(entry.key, entry.value))
                      .toList(),
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
    geminiApiKeyController.text = geminiApiKey;
    setState(() {
      themeMode = mode;
      geminiKeyMessage = geminiApiKey.trim().isEmpty
          ? 'Đang dùng API key mặc định'
          : 'Đang dùng API key riêng';
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withOpacity(0.14),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.border),
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
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.20),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }


  Widget _modeTile(String value, String text, IconData icon) {
    final active = themeMode == value;
    return InkWell(
      onTap: () => this.changeThemeMode(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.panel2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: active ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (active)
              Text(
                "Đang chọn",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withOpacity(0.35),
              blurRadius: 0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
