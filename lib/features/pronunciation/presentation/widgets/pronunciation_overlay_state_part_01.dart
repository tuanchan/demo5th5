part of flutterflashcard_main;

extension PronunciationOverlayStatePart01 on _PronunciationOverlayState {
  Widget _buildPronunciationOverlayPage(BuildContext context) {
    final pct = (_score * 100).round();
    final isHigh = pct >= 70;
    final isLow = pct < 40;
    final scoreColor = isHigh
        ? Color(0xff10b981)
        : isLow
        ? Color(0xffff5577)
        : Color(0xff3e5cff);
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget micActionButton({
      required String label,
      required VoidCallback onPressed,
      required Color color,
      IconData? icon,
      bool outlined = false,
    }) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: outlined ? Color(0x0fffffff) : color,
          foregroundColor: outlined ? Color(0xffc0c0d8) : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: outlined ? Color(0x1affffff) : color,
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 28,
            compact ? 18 : 28,
            compact ? 18 : 28,
            compact ? 18 : 24,
          ),
          decoration: BoxDecoration(
            color: Color(0xff141428),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Color(0x475a78ff)),
            boxShadow: [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 56,
                offset: Offset(0, 12),
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
                    Icon(
                      Icons.mic_none_rounded,
                      color: Color(0xff3e5cff),
                      size: 21,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Luyện Phát Âm',
                        style: TextStyle(
                          color: Color(0xffe6e6f0),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Color(0xffe6e6f0),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  widget.targetText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xffe6e6f0),
                    fontSize: widget.targetText.length > 12
                        ? (compact ? 30 : 36)
                        : (compact ? 36 : 42),
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Segoe UI',
                  ),
                ),
                if (widget.subText.trim().isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    widget.subText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff8888aa),
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                ],
                SizedBox(height: 18),
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      final pulseScale = _isRecording
                          ? _pulseAnim.value.clamp(1.0, 1.28)
                          : 1.0;
                      return SizedBox(
                        width: 90,
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isRecording)
                              Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: Color(0x2e3e5cff),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? Color(0xff2a1040)
                                    : Color(0xff1e1e3a),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isRecording
                                      ? Color(0xffff4488)
                                      : Color(0x663e5cff),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.mic_rounded,
                                color: _isRecording
                                    ? Color(0xffff6699)
                                    : Color(0xff8899ff),
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 180),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff8888aa),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_hasResult && _wordResults.isNotEmpty) ...[
                  SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xff0e0e20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xff2a2a44)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BẠN NÓI:',
                          style: TextStyle(
                            color: Color(0xff777796),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 6,
                          children: _wordResults.map((word) {
                            return Text(
                              word.text,
                              style: TextStyle(
                                color: word.ok
                                    ? Color(0xffe6e6f0)
                                    : Color(0xffff5577),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
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
                  Text(
                    'ĐỘ CHÍNH XÁC',
                    style: TextStyle(
                      color: Color(0xff777796),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _score),
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 10,
                          backgroundColor: Color(0xff1a1a2e),
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$pct%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffe6e6f0),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_hasResult) ...[
                      Flexible(
                        child: micActionButton(
                          label: 'Làm lại',
                          color: Color(0xff191a24),
                          outlined: true,
                          onPressed: this._micReset,
                        ),
                      ),
                      SizedBox(width: 10),
                    ],
                    Flexible(
                      child: micActionButton(
                        label: _isRecording ? 'Dừng lại' : 'Bắt đầu',
                        icon: Icons.mic_rounded,
                        color: _isRecording
                            ? Color(0xffff3366)
                            : Color(0xff3e5cff),
                        onPressed: _hasResult
                            ? this._micStartAgain
                            : this._micToggle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
