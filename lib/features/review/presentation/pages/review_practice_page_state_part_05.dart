part of flutterflashcard_main;

extension ReviewPracticePageStatePart05 on _ReviewPracticePageState {
  Future<void> _openSetupSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetContext) {
        int localLimit = _questionLimit.clamp(1, _cards.length).toInt();
        bool localMc = _multipleChoice;
        bool localEssay = _essay;
        bool localListening = _listening;
        bool localMatchingPairs = _matchingPairs;
        bool localSentenceMode = _sentenceMode;
        bool localAnswerByDefinition = _answerByDefinition;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setMode({
              bool? mc,
              bool? essay,
              bool? listening,
              bool? matching,
              bool? sentence,
            }) {
              setSheetState(() {
                if (mc == true) {
                  localMc = true;
                  localEssay = false;
                  localListening = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (essay == true) {
                  localEssay = true;
                  localMc = false;
                  localListening = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (listening == true) {
                  localListening = true;
                  localMc = false;
                  localEssay = false;
                  localMatchingPairs = false;
                  localSentenceMode = false;
                  return;
                }

                if (matching == true) {
                  localMatchingPairs = true;
                  localMc = false;
                  localEssay = false;
                  localListening = false;
                  localSentenceMode = false;
                  return;
                }

                if (sentence == true) {
                  localSentenceMode = true;
                  localMc = false;
                  localEssay = false;
                  localListening = false;
                  localMatchingPairs = false;
                  return;
                }

                localMc = true;
                localEssay = false;
                localListening = false;
                localMatchingPairs = false;
                localSentenceMode = false;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 560),
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: AppColors.activeIsDark ? AppColors.panel : Color(0xfff6f1fb),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border,
                        offset: Offset(0, 7),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x26000000),
                        offset: Offset(0, 18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.courseTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Thiết lập ôn tập',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.onIconButton,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      this._setupRow(
                        label: 'Câu hỏi tối đa ${_cards.length}',
                        child: this._numberStepper(
                          value: localLimit,
                          min: 1,
                          max: _cards.length,
                          onChanged: (value) =>
                               setSheetState(() => localLimit = value),
                        ),
                      ),
                      SizedBox(height: 12),
                      this._setupRow(
                        label: 'Trả lời bằng',
                        child: Container(
                          height: 48,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.3,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: localAnswerByDefinition,
                              isExpanded: true,
                              dropdownColor: AppColors.dropdownFill,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onIconButton),
                              items: [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Tiếng Việt'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Thuật ngữ'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(
                                  () => localAnswerByDefinition = value,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Divider(color: AppColors.border.withOpacity(0.18)),
                      this._switchTile(
                        text: 'Trắc nghiệm 4 đáp án',
                        value: localMc,
                        onChanged: (v) => setMode(mc: v),
                      ),
                      this._switchTile(
                        text: 'Tự luận',
                        value: localEssay,
                        onChanged: (v) => setMode(essay: v),
                      ),
                      this._switchTile(
                        text: 'Nghe',
                        value: localListening,
                        onChanged: (v) => setMode(listening: v),
                      ),
                      this._switchTile(
                        text: 'Kiểm tra cặp thẻ',
                        value: localMatchingPairs,
                        onChanged: (v) => setMode(matching: v),
                      ),
                      this._switchTile(
                        text: 'Kiểm tra tổng hợp',
                        value: localSentenceMode,
                        onChanged: (v) => setMode(sentence: v),
                      ),
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: this._solidButton(
                          text: 'Bắt đầu ôn tập',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.green,
                          onTap: () {
                            setState(() {
                              _questionLimit = localLimit;
                              _multipleChoice = localMc;
                              _essay = !localMc && localEssay;
                              _listening =
                                  !localMc &&
                                  !localEssay &&
                                  !localMatchingPairs &&
                                  !localSentenceMode &&
                                  localListening;
                              _matchingPairs =
                                  !localMc &&
                                  !localEssay &&
                                  !localListening &&
                                  !localSentenceMode &&
                                  localMatchingPairs;
                              _sentenceMode =
                                  !localMc &&
                                  !localEssay &&
                                  !localListening &&
                                  !localMatchingPairs &&
                                  localSentenceMode;
                              if (!_multipleChoice &&
                                  !_essay &&
                                  !_listening &&
                                  !_matchingPairs &&
                                  !_sentenceMode) {
                                _multipleChoice = true;
                              }
                              _answerByDefinition = localAnswerByDefinition;
                            });
                            this._saveReviewSettings();
                            Navigator.pop(sheetContext);
                            this._startQuiz();
                          },
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
  }


  Future<void> _showResultSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 460),
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.activeIsDark ? AppColors.panel : Color(0xfff6f1fb),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _geminiTextResultScript.trim().isNotEmpty
                        ? geminiColorIcon(size: 54)
                        : Icon(
                            Icons.emoji_events_outlined,
                            color: AppColors.border,
                            size: 54,
                          ),
                    SizedBox(height: 10),
                    Text(
                      _matchingPairs
                          ? 'Chúc mừng hoàn thành'
                          : 'Kết quả ôn tập',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: this._resultBox(
                            'Đúng',
                            '$_correct',
                            AppColors.green,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._resultBox('Sai', '$_wrong', AppColors.red),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._resultBox('Tổng', '$_total', AppColors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    if (_geminiTextResultScript.trim().isNotEmpty) ...[
                      this._geminiReviewBox(_geminiTextResultScript.trim()),
                      SizedBox(height: 14),
                    ],
                    if ((_essay || _listening || _sentenceMode) &&
                        !_multipleChoice &&
                        _wrong > 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: this._solidButton(
                          text: 'Xem lại câu sai',
                          icon: Icons.fact_check_rounded,
                          color: AppColors.blue,
                          onTap: this._openWrongReviewFromResult,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (_essay && !_listening && !_sentenceMode) ...[
                        SizedBox(
                          width: double.infinity,
                          child: this._solidButton(
                            text: 'Ôn lại câu sai',
                            icon: Icons.replay_rounded,
                            color: AppColors.green,
                            onTap: () {
                              Navigator.pop(context);
                              this._startWrongEssayReview();
                            },
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: this._outlineButton(
                            text: 'Thoát',
                            icon: Icons.logout_rounded,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pop(this.context);
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._solidButton(
                            text: 'Ôn lại',
                            icon: Icons.refresh_rounded,
                            color: AppColors.yellow,
                            onTap: () {
                              Navigator.pop(context);
                              this._restart();
                            },
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
      },
    );
  }


  Widget _setupRow({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        final labelWidget = Text(
          label,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, SizedBox(height: 8), child],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            SizedBox(width: 210, child: child),
          ],
        );
      },
    );
  }


  Widget _numberStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.3),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: Icon(
              Icons.remove_rounded,
              color: value <= min ? AppColors.muted.withOpacity(0.45) : AppColors.onIconButton,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: Icon(
              Icons.add_rounded,
              color: value >= max ? AppColors.muted.withOpacity(0.45) : AppColors.onIconButton,
            ),
          ),
        ],
      ),
    );
  }

}
