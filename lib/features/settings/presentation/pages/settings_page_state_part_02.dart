part of flutterflashcard_main;

extension SettingsPageStatePart02 on _SettingsPageState {
  Future<void> _loadServerLogPath() async {
    final path = await ServerLogService.path ?? '';
    if (!mounted) return;
    setState(() => serverLogPath = path);
  }

  Widget _buildServerLogSection() {
    return this._sectionCard(
      title: 'Log giao tiếp server (Windows)',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File log.txt ghi thời điểm, bảng đồng bộ, số bản ghi gửi/nhận '
            'và lỗi server. Không ghi token, API key hoặc mật khẩu.',
            style: TextStyle(
              color: Color(0xff91a0bd),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          SizedBox(height: 10),
          this._pathBox(
            serverLogPath.isEmpty ? 'Đang tạo log.txt...' : serverLogPath,
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: this._actionButton(
                  text: 'Xem log',
                  icon: Icons.visibility_outlined,
                  color: Color(0xff9ab9ff),
                  onTap: serverLogLoading ? () {} : this._showServerLog,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: this._actionButton(
                  text: 'Mở file',
                  icon: Icons.open_in_new_rounded,
                  color: Color(0xff8ee88b),
                  onTap: this._openServerLog,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: this._actionButton(
                  text: 'Xóa log',
                  icon: Icons.delete_outline_rounded,
                  color: Color(0xffff9f9f),
                  onTap: this._clearServerLog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showServerLog() async {
    setState(() => serverLogLoading = true);
    final content = await ServerLogService.read();
    if (!mounted) return;
    setState(() => serverLogLoading = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Color(0xff07090d),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900, maxHeight: 650),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'log.txt',
                        style: TextStyle(
                          color: Color(0xfff8fbff),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded, color: Color(0xff91a0bd)),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xff202634)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content.isEmpty ? 'Chưa có giao tiếp server nào.' : content,
                        style: TextStyle(
                          color: Color(0xffc8d2e5),
                          fontSize: 11.5,
                          height: 1.45,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openServerLog() async {
    final path = await ServerLogService.path;
    if (path == null) return;
    await ServerLogService.write('log.opened');
    final opened = await launchUrl(
      Uri.file(path, windows: true),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) showAppToast(context, 'Không mở được log.txt');
  }

  Future<void> _clearServerLog() async {
    await ServerLogService.clear();
    await ServerLogService.write('log.cleared');
    if (mounted) showAppToast(context, 'Đã xóa nội dung log.txt');
  }

  Widget _pathBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }


  Widget _colorRow(String key, String label) {
    final current = AppColors.getByKey(key);
    return Container(
      margin: EdgeInsets.only(bottom: 13),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '#${current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((color) {
              return InkWell(
                onTap: () async {
                  await AppColors.saveColor(key, color);
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.value == current.value
                          ? AppColors.text
                          : AppColors.border.withOpacity(0.35),
                      width: color.value == current.value ? 2.4 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
