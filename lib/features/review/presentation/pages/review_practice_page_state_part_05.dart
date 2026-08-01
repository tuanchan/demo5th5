part of flutterflashcard_main;

extension ReviewPracticePageStatePart05 on _ReviewPracticePageState {
  Future<void> _openSetupSheet() async {
    if (_cards.isEmpty) return;

    final initialQuestionLimit = _questionLimit
        .clamp(1, _cards.length)
        .toInt();
    final questionCountController = FixedExtentScrollController(
      initialItem: initialQuestionLimit - 1,
    );

    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (sheetContext) {
          int localLimit = initialQuestionLimit;
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
              bool? matchingPairs,
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

                if (matchingPairs == true) {
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

            final compactDialog = MediaQuery.sizeOf(context).width < 600;
            return Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(
                  left: compactDialog ? 12 : 18,
                  right: compactDialog ? 12 : 18,
                  top: compactDialog ? 12 : 18,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      (compactDialog ? 12 : 18),
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                    ),
                    padding: EdgeInsets.all(compactDialog ? 16 : 22),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Color(0xff2a334a)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x59000000),
                          offset: Offset(0, 18),
                          blurRadius: 46,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: Color(0xffa8b6d6),
                                    fontWeight: FontWeight.w400,
                                    fontSize: compactDialog ? 12 : 13,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Thiết lập bài kiểm tra',
                                  maxLines: compactDialog ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xffeaf1ff),
                                    fontSize: compactDialog ? 21 : 28,
                                    height: 1.15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.pop(sheetContext),
                            style: IconButton.styleFrom(
                              foregroundColor: Color(0xffeaf1ff),
                              backgroundColor: Color(0x0fffffff),
                              side: BorderSide(color: Color(0xff2a334a)),
                              minimumSize: Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      this._setupRow(
                        label: 'Câu hỏi (1–${_cards.length})',
                        child: this._questionCountSpinner(
                          controller: questionCountController,
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
                          height: 46,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Color(0x0fffffff),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Color(0xff2a334a)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: localAnswerByDefinition,
                              isExpanded: true,
                              dropdownColor: Color(0xff0b0c0f),
                              style: TextStyle(
                                color: Color(0xffeaf1ff),
                                fontWeight: FontWeight.w400,
                              ),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xffa8b6d6)),
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
                      Divider(color: Color(0xff2a334a)),
                      SizedBox(height: 8),
                      Text(
                        'Phương thức có cập nhật lịch SRS',
                        style: TextStyle(
                          color: Color(0xffa8b6d6),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeepLearnPage(
                                courseId: widget.courseId,
                                courseTitle: widget.courseTitle,
                                courseLanguageCode: widget.courseLanguageCode,
                              ),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 160),
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Color(0x0fffffff),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xff2a334a)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 14),
                              SvgPicture.asset(
                                'assets/icon/brain-solid-full.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  Color(0xffa8b6d6),
                                  BlendMode.srcIn,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Học Chuyên Sâu',
                                  style: TextStyle(
                                    color: Color(0xffeaf1ff),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xffa8b6d6),
                              ),
                              SizedBox(width: 10),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      this._switchTile(
                        text: 'Trắc nghiệm (4 đáp án)',
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
                        onChanged: (v) => setMode(matchingPairs: v),
                      ),
                      SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _questionLimit = localLimit;
                              _multipleChoice = localMc;
                              _essay = localEssay;
                              _listening = localListening;
                              _matchingPairs = localMatchingPairs;
                              _sentenceMode = localSentenceMode;
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
                          icon: Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            'Bắt đầu làm kiểm tra',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w400),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Color(0xff3e5cff),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            },
          );
        },
      );
    } finally {
      questionCountController.dispose();
    }
  }


  Widget _buildResultActivity() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 460),
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Color(0xff0b0c10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(0xff242832)),
          ),
          child: _isGeminiTextGrading
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      geminiColorIcon(size: 42),
                      SizedBox(height: 16),
                      Text(
                        'Gemini đang chấm tự luận...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Kết quả sẽ hiển thị ngay tại đây',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xffa8b6d6),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xff4257ff),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _geminiTextResultScript.trim().isNotEmpty
                        ? geminiColorIcon(size: 42)
                        : Icon(
                            Icons.emoji_events_outlined,
                            color: Color(0xff4257ff),
                            size: 42,
                          ),
                    SizedBox(height: 10),
                    Text(
                      _matchingPairs
                          ? 'Chúc mừng hoàn thành'
                          : 'Kết quả ôn tập',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: this._resultBox(
                            'Đúng',
                            '$_correct',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Color(0xff242832),
                        ),
                        Expanded(
                          child: this._resultBox('Sai', '$_wrong'),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: Color(0xff242832),
                        ),
                        Expanded(
                          child: this._resultBox('Tổng', '$_total'),
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
                          showIcon: false,
                          color: Color(0xff4257ff),
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
                            showIcon: false,
                            color: Color(0xff171c28),
                            onTap: () {
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
                              Navigator.pop(context, {
                                'courseId': widget.courseId,
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: this._solidButton(
                            text: 'Ôn lại',
                            icon: Icons.refresh_rounded,
                            color: Color(0xff4257ff),
                            onTap: () {
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
    );
  }


  Widget _setupRow({required String label, required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        final labelWidget = Text(
          label,
          style: TextStyle(
            color: Color(0xffa8b6d6),
            fontWeight: FontWeight.w400,
            fontSize: 14,
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


  Widget _questionCountSpinner({
    required FixedExtentScrollController controller,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    const itemHeight = 38.0;

    return Container(
      height: itemHeight * 3,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(0x0fffffff),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xff2a334a)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              height: itemHeight,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Color(0x263e5cff),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xff3e5cff)),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: itemHeight,
            diameterRatio: 1.8,
            perspective: 0.003,
            physics: ItemScrollPhysics(itemHeight: itemHeight),
            onSelectedItemChanged: (index) => onChanged(min + index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: max - min + 1,
              builder: (context, index) {
                final questionCount = min + index;
                final selected = questionCount == value;
                return Center(
                  child: Text(
                    '$questionCount',
                    style: TextStyle(
                      color: selected ? Colors.white : Color(0xff71809f),
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: selected ? 18 : 15,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            child: IgnorePointer(
              child: Text(
                '/ $max',
                style: TextStyle(
                  color: Color(0xff8e9bb8),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
