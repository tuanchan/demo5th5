part of flutterflashcard_main;

extension HomeVocabularyReminderPart on _HomePageState {
  Future<void> openVocabularyReminderSettings(CourseListItem course) async {
    final config = await VocabularyReminderService.instance.loadConfig(
      course.id,
    );
    final status = await VocabularyReminderService.instance.loadStatus(
      course.id,
    );
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VocabularyReminderDialog(
        course: course,
        initialConfig: config,
        initialStatus: status,
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
    required this.initialStatus,
  });

  final CourseListItem course;
  final VocabularyReminderConfig initialConfig;
  final VocabularyReminderStatus initialStatus;

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
  late int _startMinute;
  late int _endHour;
  late int _endMinute;
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
    _intervalMinutes = config.enabled ? config.intervalMinutes : 0.5;
    _notificationsPerDay = math.max(1, widget.initialStatus.totalCards);
    _intervalController = TextEditingController(
      text: _formatDecimal(_intervalMinutes),
    );
    _quantityController = TextEditingController(
      text: _notificationsPerDay.toString(),
    );
    _startHour = config.startHour;
    _startMinute = config.startMinute;
    _endHour = config.endHour;
    _endMinute = config.endMinute;
    _includePronunciation = config.includePronunciation;
    _includeDefinition = config.includeDefinition;
    _skipSrsMastered = config.skipSrsMastered;
    _randomOrder = config.randomOrder;
    _soundEnabled = config.soundEnabled;
    _showInForeground = config.showInForeground;
    _statusFuture = Future<VocabularyReminderStatus>.value(
      widget.initialStatus,
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
    if (interval == null || interval < 0.1 || interval > 1440) {
      setState(() {
        _message = 'Khoảng thời gian phải từ 0.1 đến 1440 phút';
      });
      return false;
    }
    _intervalMinutes = interval;
    return true;
  }

  VocabularyReminderConfig get _config => VocabularyReminderConfig(
        courseId: widget.course.id,
        enabled: _enabled,
        intervalMinutes: _intervalMinutes,
        notificationsPerDay: _notificationsPerDay,
        startHour: _startHour,
        startMinute: _startMinute,
        endHour: _endHour,
        endMinute: _endMinute,
        includePronunciation: _includePronunciation,
        includeDefinition: _includeDefinition,
        skipSrsMastered: _skipSrsMastered,
        randomOrder: _randomOrder,
        soundEnabled: _soundEnabled,
        showInForeground: _showInForeground,
      );

  Future<void> _save() async {
    if (!_readCustomScheduleValues()) return;
    final start = _startHour * 60 + _startMinute;
    final end = _endHour * 60 + _endMinute;
    if (end <= start) {
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

  Future<void> _pickTime({required bool isStart}) async {
    final hour = isStart ? _startHour : _endHour;
    final minute = isStart ? _startMinute : _endMinute;
    await dt_picker.DatePicker.showTimePicker(
      context,
      showTitleActions: true,
      currentTime: DateTime(2000, 1, 1, hour, minute),
      locale: dt_picker.LocaleType.vi,
      theme: const dt_picker.DatePickerTheme(
        backgroundColor: Color(0xff192131),
        itemStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        cancelStyle: TextStyle(color: Color(0xffaeb8ca), fontSize: 14),
        doneStyle: TextStyle(
          color: Color(0xff8fb5ff),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      onConfirm: (time) {
        if (!mounted) return;
        setState(() {
          if (isStart) {
            _startHour = time.hour;
            _startMinute = time.minute;
          } else {
            _endHour = time.hour;
            _endMinute = time.minute;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xff111722);
    const panel2 = Color(0xff192131);
    const border = Color(0xff31405a);
    const text = Color(0xfff4f7fb);

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
                    Expanded(
                      child: const Text(
                        'THIẾT LẬP TOAST TỪ VỰNG',
                        style: TextStyle(
                          color: text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
                              hintText: '0.5',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _numberField(
                              label: 'Số lượng từ',
                              controller: _quantityController,
                              suffixText: 'từ',
                              hintText: '',
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _timePickerField(
                              label: 'Bắt đầu',
                              hour: _startHour,
                              minute: _startMinute,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _timePickerField(
                              label: 'Kết thúc',
                              hour: _endHour,
                              minute: _endMinute,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _ReminderSectionTitle('NỘI DUNG & CHỌN TỪ'),
                      const SizedBox(height: 8),
                      _switchTile(
                        title: 'Hiện phiên âm',
                        value: _includePronunciation,
                        onChanged: (value) =>
                            setState(() => _includePronunciation = value),
                      ),
                      _switchTile(
                        title: 'Hiện nghĩa',
                        value: _includeDefinition,
                        onChanged: (value) =>
                            setState(() => _includeDefinition = value),
                      ),
                      _switchTile(
                        title: 'Bỏ qua thẻ đã thành thạo SRS',
                        value: _skipSrsMastered,
                        onChanged: (value) =>
                            setState(() => _skipSrsMastered = value),
                      ),
                      _switchTile(
                        title: 'Thứ tự ngẫu nhiên',
                        value: _randomOrder,
                        onChanged: (value) =>
                            setState(() => _randomOrder = value),
                      ),
                      _switchTile(
                        title: 'Âm thanh thông báo',
                        value: _soundEnabled,
                        onChanged: (value) =>
                            setState(() => _soundEnabled = value),
                      ),
                      _switchTile(
                        title: 'Hiện cả khi đang mở app',
                        value: _showInForeground,
                        onChanged: (value) =>
                            setState(() => _showInForeground = value),
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
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff3b82f6),
                              side: const BorderSide(color: Color(0xff3b82f6)),
                            ),
                            onPressed: _busy ? null : _testNotification,
                            child: const Text('Gửi thử'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff3b82f6),
                              side: const BorderSide(color: Color(0xff3b82f6)),
                            ),
                            onPressed: _busy ? null : _resetLearned,
                            child: const Text('Đặt lại từ đã thuộc'),
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
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff60a5fa),
                      ),
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff2563eb),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xff1e3a8a),
                      ),
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lưu thiết lập'),
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
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xff2563eb),
        onChanged: _busy ? null : onChanged,
      ),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String suffixText,
    required String hintText,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      readOnly: readOnly,
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

  Widget _timePickerField({
    required String label,
    required int hour,
    required int minute,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xff192131),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _busy ? null : onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xffaeb8ca)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xff31405a)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xff31405a)),
            ),
          ),
          child: Text(
            '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

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
