part of flutterflashcard_main;

extension PronunciationOverlayStatePart01 on _PronunciationOverlayState {
  Widget _buildPronunciationOverlayPage(BuildContext context) {
    final pct = (_score * 100).round();
    final isHigh = pct >= 70;
    final isLow = pct < 40;
    final scoreColor = isHigh
        ? AppColors.green
        : isLow
        ? AppColors.red
        : AppColors.blue;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      child: Container(
        constraints: BoxConstraints(maxWidth: 420),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Color(0xfff6f1fb),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.border.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 18),
              blurRadius: 30,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Luyện phát âm',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.border),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (!_hasResult) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 7),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x18000000),
                        offset: Offset(0, 16),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          'Nhận diện phát âm',
                          style: TextStyle(
                            color: AppColors.border,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        widget.targetText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: widget.targetText.length > 8 ? 30 : 40,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                      if (widget.subText.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          widget.subText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        width: _isRecording ? 88 : 76,
                        height: _isRecording ? 88 : 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? AppColors.red
                              : AppColors.panel2,
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, _isRecording ? 4 : 7),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) {
                            return Transform.scale(
                              scale: _isRecording
                                  ? _pulseAnim.value.clamp(1.0, 1.12)
                                  : 1.0,
                              child: Icon(
                                Icons.mic_rounded,
                                color: AppColors.border,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 180),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasResult && _wordResults.isNotEmpty) ...[
                SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BẠN NÓI',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 6,
                        children: _wordResults.map((w) {
                          return Text(
                            w.text,
                            style: TextStyle(
                              color: w.ok ? AppColors.text : Color(0xffc0392b),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasResult) ...[
                SizedBox(height: 14),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐỘ CHÍNH XÁC',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _score),
                          duration: Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => LinearProgressIndicator(
                            value: v,
                            minHeight: 12,
                            backgroundColor: AppColors.panel2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scoreColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 18),
              Row(
                children: [
                  if (_hasResult) ...[
                    Expanded(
                      child: _MicButton(
                        label: 'Làm lại',
                        color: Colors.white,
                        onTap: this._micReset,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _MicButton(
                        label: 'Bắt đầu',
                        color: AppColors.yellow,
                        onTap: this._micStartAgain,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: _MicButton(
                        label: _isRecording ? 'Dừng lại' : 'Bắt đầu',
                        color: _isRecording ? AppColors.red : AppColors.yellow,
                        onTap: this._micToggle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onError: (e) {
        setState(() {
          _isRecording = false;
          _pulseController.stop();
          _pulseController.reset();
          if (e.errorMsg.contains('permission')) {
            _statusText = 'Vui lòng cho phép truy cập Microphone.';
          } else if (e.errorMsg.contains('no-speech') ||
              e.errorMsg.contains('no_match')) {
            _statusText = 'Không phát hiện giọng nói. Thử lại nhé!';
          } else {
            _statusText = 'Lỗi: ${e.errorMsg}';
          }
        });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!_listenStarted) return;
          if (mounted && _isRecording && !_hasResult) {
            setState(() {
              _isRecording = false;
              _pulseController.stop();
              _pulseController.reset();
              _statusText = 'Không nhận được giọng nói. Thử lại nhé!';
            });
          }
        }
      },
    );

    if (!_isAvailable && mounted) {
      setState(() {
        _statusText = 'Thiết bị không hỗ trợ nhận diện giọng nói.';
      });
    }
  }


  void _micReset() {
    _speech.stop();
    try {
      _successPlayer.stop();
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _hasResult = false;
      _wordResults = [];
      _score = 0.0;
      _statusText = 'Nhấn nút để bắt đầu';
    });
    _pulseController.stop();
    _pulseController.reset();
  }


  Future<void> _micStartAgain() async {
    this._micReset();

    await Future.delayed(Duration(milliseconds: 120));

    if (!mounted) return;

    await this._micToggle();
  }

}
