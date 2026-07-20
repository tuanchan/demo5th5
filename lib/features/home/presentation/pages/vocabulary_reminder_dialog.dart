part of flutterflashcard_main;

extension HomeVocabularyReminderPart on _HomePageState {
  Future<void> openVocabularyReminderSettings(CourseListItem course) async {
    final config = await VocabularyReminderService.instance.loadConfig(
      course.id,
    );
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VocabularyReminderDialog(
        course: course,
        initialConfig: config,
      ),
    );
    if (saved == true && mounted) {
      this.showHomeMessage('Đã cập nhật Toast cho “${course.title}”');
    }
  }
}

class _VocabularyReminderDialog extends StatefulWidget {
  const _VocabularyReminderDialog({
    required this.course,
    required this.initialConfig,
  });

  final CourseListItem course;
  final VocabularyReminderConfig initialConfig;

  @override
  State<_VocabularyReminderDialog> createState() =>
      _VocabularyReminderDialogState();
}

class _VocabularyReminderDialogState
    extends State<_VocabularyReminderDialog> {
  late bool _enabled;
  late double _intervalMinutes;
  late int _notificationsPerDay;
  late final TextEditingController _intervalController;
  late final TextEditingController _quantityController;
  late int _startHour;
  late int _endHour;
  late bool _includePronunciation;
  late bool _includeDefinition;
  late bool _skipSrsMastered;
  late bool _randomOrder;
  late bool _soundEnabled;
  late bool _showInForeground;
  bool _busy = false;
  String? _message;
  late Future<VocabularyReminderStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _enabled = config.enabled;
    _intervalMinutes = config.intervalMinutes;
    _notificationsPerDay = config.notificationsPerDay;
    _intervalController = TextEditingController(
      text: _formatDecimal(_intervalMinutes),
    );
    _quantityController = TextEditingController(
      text: _notificationsPerDay.toString(),
    );
    _startHour = config.startHour;
    _endHour = config.endHour;
    _includePronunciation = config.includePronunciation;
    _includeDefinition = config.includeDefinition;
    _skipSrsMastered = config.skipSrsMastered;
    _randomOrder = config.randomOrder;
    _soundEnabled = config.soundEnabled;
    _showInForeground = config.showInForeground;
    _statusFuture = VocabularyReminderService.instance.loadStatus(
      widget.course.id,
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool _readCustomScheduleValues() {
    final interval = double.tryParse(
      _intervalController.text.trim().replaceAll(',', '.'),
    );
    final quantity = int.tryParse(_quantityController.text.trim());
    if (interval == null || interval < 0.1 || interval > 1440) {
      setState(() {
        _message = 'Khoảng thời gian phải từ 0.1 đến 1440 phút';
      });
      return false;
    }
    if (quantity == null || quantity < 1 || quantity > 60) {
      setState(() {
        _message = 'Số lượng từ phải từ 1 đến 60 từ mỗi ngày';
      });
      return false;
    }
    _intervalMinutes = interval;
    _notificationsPerDay = quantity;
    return true;
  }

  VocabularyReminderConfig get _config => VocabularyReminderConfig(
        courseId: widget.course.id,
        enabled: _enabled,
        intervalMinutes: _intervalMinutes,
        notificationsPerDay: _notificationsPerDay,
        startHour: _startHour,
        endHour: _endHour,
        includePronunciation: _includePronunciation,
        includeDefinition: _includeDefinition,
        skipSrsMastered: _skipSrsMastered,
        randomOrder: _randomOrder,
        soundEnabled: _soundEnabled,
        showInForeground: _showInForeground,
      );

  Future<void> _save() async {
    if (!_readCustomScheduleValues()) return;
    if (_endHour <= _startHour) {
      setState(() => _message = 'Giờ kết thúc phải sau giờ bắt đầu');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_enabled) {
        final granted =
            await VocabularyReminderService.instance.requestPermission();
        if (!granted) {
          if (mounted) {
            setState(() {
              _message = 'Bạn cần cho phép thông báo trong Cài đặt hệ thống';
            });
          }
          return;
        }
      }
      await VocabularyReminderService.instance.saveConfig(_config);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _message = 'Không thể lập lịch: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testNotification() async {
    if (!_readCustomScheduleValues()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final granted =
          await VocabularyReminderService.instance.requestPermission();
      if (!granted) {
        throw StateError('Chưa được cấp quyền thông báo');
      }
      // Save presentation choices before sending the preview, but preserve the
      // current enabled state and rebuild the real queue as part of the save.
      await VocabularyReminderService.instance.saveConfig(_config);
      await VocabularyReminderService.instance.showTestNotification(
        widget.course.id,
      );
      if (mounted) setState(() => _message = 'Đã gửi một thông báo thử');
    } catch (error) {
      if (mounted) setState(() => _message = 'Không gửi được: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetLearned() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff111722),
        title: const Text(
          'Đặt lại từ đã thuộc?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tất cả từ từng bấm “Đã thuộc” sẽ được đưa lại vào hàng đợi Toast.',
          style: TextStyle(color: Color(0xffaeb8ca)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await VocabularyReminderService.instance.resetLearnedCards(
        widget.course.id,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Đã đưa toàn bộ từ trở lại hàng đợi';
        _statusFuture = VocabularyReminderService.instance.loadStatus(
          widget.course.id,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xff111722);
    const panel2 = Color(0xff192131);
    const border = Color(0xff31405a);
    const text = Color(0xfff4f7fb);
    const muted = Color(0xffaeb8ca);
    const blue = Color(0xff3b82f6);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 590, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: blue.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/icon/bell-solid-full.svg',
                        width: 19,
                        height: 19,
                        colorFilter: const ColorFilter.mode(
                          blue,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'THIẾT LẬP TOAST TỪ VỰNG',
                            style: TextStyle(
                              color: text,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.course.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _switchTile(
                        title: 'Bật Toast cho học phần này',
                        subtitle:
                            'Thông báo vẫn xuất hiện khi app đang nền hoặc đã đóng.',
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                      const SizedBox(height: 14),
                      FutureBuilder<VocabularyReminderStatus>(
                        future: _statusFuture,
                        builder: (context, snapshot) {
                          final status = snapshot.data;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: panel2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              status == null
                                  ? 'Đang đọc trạng thái từ vựng...'
                                  : '${status.eligibleCards} từ đang chờ • '
                                      '${status.learnedCards} đã thuộc • '
                                      '${status.scheduledNotifications} thông báo đã xếp lịch',
                              style: const TextStyle(
                                color: text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const _ReminderSectionTitle('LỊCH THÔNG BÁO'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              label: 'Khoảng thời gian',
                              controller: _intervalController,
                              suffixText: 'phút',
                              hintText: 'VD: 15',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _numberField(
                              label: 'Số lượng mỗi ngày',
                              controller: _quantityController,
                              suffixText: 'từ',
                              hintText: 'VD: 8',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                              label: 'Bắt đầu',
                              value: _startHour,
                              items: List<int>.generate(18, (i) => i + 5),
                              textFor: _hourLabel,
                              onChanged: (value) =>
                                  setState(() => _startHour = value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dropdown(
                              label: 'Kết thúc',
                              value: _endHour,
                              items: List<int>.generate(18, (i) => i + 7),
                              textFor: _hourLabel,
                              onChanged: (value) =>
                                  setState(() => _endHour = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _ReminderSectionTitle('NỘI DUNG & CHỌN TỪ'),
                      const SizedBox(height: 8),
                      _switchTile(
                        title: 'Hiện phiên âm',
                        subtitle: 'Ẩn tự động nếu từ không có phiên âm.',
                        value: _includePronunciation,
                        onChanged: (value) =>
                            setState(() => _includePronunciation = value),
                      ),
                      _switchTile(
                        title: 'Hiện nghĩa',
                        subtitle: 'Tên thông báo luôn là từ vựng.',
                        value: _includeDefinition,
                        onChanged: (value) =>
                            setState(() => _includeDefinition = value),
                      ),
                      _switchTile(
                        title: 'Bỏ qua thẻ đã thành thạo SRS',
                        subtitle: 'Không nhắc thẻ SRS cấp 5 trở lên.',
                        value: _skipSrsMastered,
                        onChanged: (value) =>
                            setState(() => _skipSrsMastered = value),
                      ),
                      _switchTile(
                        title: 'Thứ tự ngẫu nhiên',
                        subtitle: 'Trộn lại sau mỗi vòng học phần.',
                        value: _randomOrder,
                        onChanged: (value) =>
                            setState(() => _randomOrder = value),
                      ),
                      _switchTile(
                        title: 'Âm thanh thông báo',
                        subtitle: 'Vẫn tuân theo chế độ im lặng của thiết bị.',
                        value: _soundEnabled,
                        onChanged: (value) =>
                            setState(() => _soundEnabled = value),
                      ),
                      _switchTile(
                        title: 'Hiện cả khi đang mở app',
                        subtitle:
                            'Trên iOS, mặc định tắt để chỉ nhắc khi bạn rời app.',
                        value: _showInForeground,
                        onChanged: (value) =>
                            setState(() => _showInForeground = value),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff172033),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: const Text(
                          'Cách hoạt động: “Đã thuộc” loại từ khỏi Toast; '
                          '“Chưa thuộc” giữ từ trong vòng ngẫu nhiên. Mỗi câu trả '
                          'lời đặt lại vòng và bù thêm lịch mới. iOS giữ tối đa 64 '
                          'thông báo, app dùng 60 vị trí an toàn và chỉ bật một '
                          'học phần Toast tại một thời điểm.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: const TextStyle(
                            color: Color(0xffffc857),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _testNotification,
                            icon: const Icon(Icons.notifications_active_rounded),
                            label: const Text('Gửi thử'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _resetLearned,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Đặt lại từ đã thuộc'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: border),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Lưu thiết lập'),
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

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xfff4f7fb),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xffaeb8ca),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: value,
        onChanged: _busy ? null : onChanged,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required int value,
    required List<int> items,
    required String Function(int) textFor,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: items.contains(value) ? value : items.first,
      dropdownColor: const Color(0xff192131),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xffaeb8ca)),
        filled: true,
        fillColor: const Color(0xff192131),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff31405a)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff3b82f6)),
        ),
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<int>(
              value: item,
              child: Text(textFor(item)),
            ),
          )
          .toList(),
      onChanged: _busy
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String suffixText,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffixText,
        labelStyle: const TextStyle(color: Color(0xffaeb8ca)),
        hintStyle: const TextStyle(color: Color(0xff718096)),
        suffixStyle: const TextStyle(
          color: Color(0xffaeb8ca),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xff192131),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff31405a)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff3b82f6)),
        ),
      ),
    );
  }

  String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _formatDecimal(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _ReminderSectionTitle extends StatelessWidget {
  const _ReminderSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xff8fb5ff),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}
