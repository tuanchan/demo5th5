part of flutterflashcard_main;

extension PronunciationOverlayStatePart02 on _PronunciationOverlayState {
  Future<void> _micToggle() async {
    if (_isRecording) {
      await _speech.stop();
      setState(() {
        _isRecording = false;
        _pulseController.stop();
        _pulseController.reset();
        _statusText = 'Đã dừng. Nhấn lại để thử.';
      });
      return;
    }

    // Windows desktop thường không nhận ổn với speech_to_text
    if (Platform.isWindows) {
      setState(() {
        _statusText =
            'Windows không hỗ trợ nhận diện giọng ổn định. Hãy test trên Android/iOS hoặc Web.';
      });
      return;
    }

    bool available = false;

    try {
      available = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isRecording = false;
            _pulseController.stop();
            _pulseController.reset();
            _statusText = 'Lỗi nhận diện: ${e.errorMsg}';
          });
        },
        onStatus: (status) {
          debugPrint('SPEECH STATUS: $status');
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _pulseController.stop();
        _pulseController.reset();
        _statusText =
            'Thiết bị này không có dịch vụ nhận diện giọng nói. Hãy test bằng Chrome hoặc điện thoại thật.';
      });

      debugPrint('SPEECH INIT ERROR: $e');
      return;
    }

    if (!available) {
      setState(() {
        _statusText =
            'Thiết bị không hỗ trợ nhận diện giọng nói. BlueStacks thường thiếu Google Speech Service.';
      });
      return;
    }

    if (!available) {
      setState(() {
        _statusText = 'Thiết bị không hỗ trợ nhận diện giọng nói.';
      });
      return;
    }

    String lastWords = '';

    setState(() {
      _hasResult = false;
      _wordResults = [];
      _score = 0;
      _isRecording = true;
      _statusText = 'Đang nghe...';
    });

    _pulseController.repeat(reverse: true);

    await _speech.listen(
      localeId: widget.languageCode.isNotEmpty ? widget.languageCode : 'zh-TW',
      listenFor: Duration(seconds: 20),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        lastWords = result.recognizedWords.trim();
        debugPrint('SPEECH WORDS: $lastWords');

        if (lastWords.isNotEmpty) {
          this._micStop();
          this._micShowResult(lastWords);
        }
      },
    );

    Future.delayed(Duration(seconds: 8), () {
      if (!mounted) return;
      if (_isRecording && lastWords.isEmpty) {
        this._micStop();
        setState(() {
          _statusText = 'Không nhận được giọng nói. Thử lại nhé!';
        });
      }
    });
  }


  void _micStop() {
    _speech.stop();
    setState(() => _isRecording = false);
    _pulseController.stop();
    _pulseController.reset();
  }


  void _micShowResult(String spoken) {
    if (spoken.isEmpty) {
      setState(() => _statusText = 'Không nhận được giọng nói. Thử lại nhé!');
      return;
    }

    final spokenNorm = normalizeText(spoken);
    final targetNorm = normalizeText(widget.targetText);
    final score = calcSimilarity(spokenNorm, targetNorm);
    final wordResults = buildWordResults(
      spoken,
      widget.targetText,
      widget.languageCode,
    );

    setState(() {
      _statusText = '';
      _wordResults = wordResults;
      _score = score;
      _hasResult = true;
    });
  }

}
