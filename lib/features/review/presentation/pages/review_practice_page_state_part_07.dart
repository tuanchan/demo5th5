part of flutterflashcard_main;

extension ReviewPracticePageStatePart07 on _ReviewPracticePageState {
  Widget _buildEssayMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 1040,
            minHeight: math.max(
              430.0,
              MediaQuery.sizeOf(context).height - 190,
            ),
          ),
          padding: EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Color(0xff111318),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xff242832)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  this._statChip(
                    text: '$displayIndex/$_total',
                  ),
                  Spacer(),
                  if (_sentenceMode)
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 21,
                      color: Color(0xff4257ff),
                    ),
                ],
              ),
              SizedBox(height: 18),
              Text(
                _sentenceMode
                    ? (_answerByDefinition ? 'Câu ngoại ngữ' : 'Câu tiếng Việt')
                    : (_answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa'),
                style: TextStyle(
                  color: Color(0xff9aa4b8),
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    this._promptOf(card),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: this._promptOf(card).length > 28 ? 30 : 40,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              if (this._subPromptOf(card).trim().isNotEmpty) ...[
                SizedBox(height: 8),
                Center(
                  child: Text(
                    this._subPromptOf(card),
                    style: TextStyle(
                      color: Color(0xff9aa4b8),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 18),
              Text(
                'Đáp án của bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _essayController,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: _sentenceMode
                      ? (_answerByDefinition
                            ? 'Nhập bản dịch tiếng Việt'
                            : 'Nhập câu ngoại ngữ tương ứng')
                      : (_answerByDefinition
                            ? 'Nhập Tiếng Việt'
                            : 'Nhập thuật ngữ'),
                  filled: true,
                  fillColor: Color(0xff171c28),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Color(0xff343b49)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Color(0xff4257ff), width: 2),
                  ),
                ),
                onSubmitted: (_) => this._submitEssay(),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: this._outlineButton(
                      text: 'Trước',
                      icon: Icons.arrow_back_rounded,
                      onTap: _currentEssayIndex <= 0
                          ? () {}
                          : this._moveEssayPrevious,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: this._solidButton(
                      text: 'Sau',
                      icon: Icons.arrow_forward_rounded,
                      color: Color(0xff4257ff),
                      onTap: () => this._submitEssay(allowEmptyAsSkip: true),
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


  Widget _listeningChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Color(0xff4257ff) : Color(0xff2f3545),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Color(0xff84a1ff) : Color(0xff3a4154),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }


  Widget _buildListeningMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;
    final choices = _choiceMap[card.id] ?? this._buildListeningChoices(card);
    final selected = (_selectedListeningAnswer ?? '').trim();
    final selectedParts = selected.isEmpty
        ? <String>[]
        : selected
              .split(RegExp(r'\s+'))
              .where((part) => part.trim().isNotEmpty)
              .toList();

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 96),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 900),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: math.max(430.0, constraints.maxHeight - 124),
                    ),
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xff111318),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xff242832)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'NGHE',
                              style: TextStyle(
                                color: Color(0xff9aa4b8),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '$displayIndex / $_total',
                              style: TextStyle(
                                color: Color(0xff9aa4b8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Nghe và sắp xếp đáp án đúng',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 20),
                        Material(
                          color: Color(0xff171c28),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: this._playListeningAudio,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 76,
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _isPlayingListeningAudio
                                      ? Color(0xff84a1ff)
                                      : Color(0xff343b49),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isPlayingListeningAudio
                                        ? Icons.graphic_eq_rounded
                                        : Icons.volume_up_rounded,
                                    color: Color(0xffaebcff),
                                    size: 34,
                                  ),
                                  SizedBox(width: 14),
                                  Text(
                                    _isPlayingListeningAudio
                                        ? 'Đang phát âm thanh'
                                        : 'Nhấn để nghe',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 26),
                        Text(
                          'Đáp án của bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(minHeight: 72),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xff343b49)),
                          ),
                          child: selectedParts.isEmpty
                              ? Center(
                                  child: Text(
                                    'Chọn các từ bên dưới để tạo đáp án',
                                    style: TextStyle(
                                      color: Color(0xff737d91),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedParts.map((part) {
                                    return this._listeningChip(
                                      text: part,
                                      selected: true,
                                      onTap: () {
                                        final next = List<String>.from(
                                          selectedParts,
                                        )..remove(part);
                                        setState(() {
                                          _selectedListeningAnswer = next.isEmpty
                                              ? null
                                              : next.join(' ');
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                        ),
                        SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: choices.map((choice) {
                            final used = selectedParts.contains(choice);
                            return AnimatedOpacity(
                              opacity: used ? 0.22 : 1,
                              duration: Duration(milliseconds: 140),
                              child: IgnorePointer(
                                ignoring: used,
                                child: this._listeningChip(
                                  text: choice,
                                  selected: false,
                                  onTap: () {
                                    setState(() {
                                      _selectedListeningAnswer = [
                                        ...selectedParts,
                                        choice,
                                      ].join(' ');
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: selectedParts.isEmpty
                                  ? null
                                  : () => setState(
                                      () => _selectedListeningAnswer = null,
                                    ),
                              child: Text('Xóa đáp án'),
                            ),
                            SizedBox(width: 12),
                            SizedBox(
                              width: 150,
                              child: this._solidButton(
                                text: displayIndex >= _total
                                    ? 'Hoàn thành'
                                    : 'Kiểm tra',
                                icon: Icons.check_rounded,
                                color: Color(0xff4257ff),
                                onTap: this._submitListeningAnswer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildLegacyListeningMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;
    final choices = _choiceMap[card.id] ?? this._buildListeningChoices(card);
    final selected = (_selectedListeningAnswer ?? '').trim();
    final selectedParts = selected.isEmpty
        ? <String>[]
        : selected
              .split(RegExp(r'\s+'))
              .where((e) => e.trim().isNotEmpty)
              .toList();

    return ColoredBox(
      color: Colors.black,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: Offset(0, 0.18),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Center(
            key: ValueKey('listening-card-${card.id}'),
            child: Container(
              constraints: BoxConstraints(maxWidth: 560),
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Color(0xff0b0c0f),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xff2f3545)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 16),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      this._statChip(
                        text: '$displayIndex/$_total',
                      ),
                      Spacer(),
                      Text(
                        'Nghe và chọn nghĩa đúng',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  Center(
                    child: GestureDetector(
                      onTap: this._playListeningAudio,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 180),
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          color: _isPlayingListeningAudio
                              ? Color(0xff3346e8)
                              : Color(0xff4257ff),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xff84a1ff),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x594257ff),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlayingListeningAudio
                              ? Icons.graphic_eq_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Ấn loa để nghe lại',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 20),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: 62),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xff171c28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Color(0xff343b49),
                      ),
                    ),
                    child: selectedParts.isEmpty
                        ? Center(
                            child: Text(
                              'Chọn nhiều chip để ghép đáp án',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: selectedParts.map((part) {
                                return this._listeningChip(
                                  text: part,
                                  selected: true,
                                  onTap: () {
                                    final next = List<String>.from(
                                      selectedParts,
                                    )..remove(part);
                                    setState(() {
                                      _selectedListeningAnswer = next.isEmpty
                                          ? null
                                          : next.join(' ');
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: choices.map((choice) {
                      final isSelected = selectedParts.contains(choice);
                      return AnimatedOpacity(
                        duration: Duration(milliseconds: 180),
                        opacity: isSelected ? 0.28 : 1,
                        child: IgnorePointer(
                          ignoring: isSelected,
                          child: this._listeningChip(
                            text: choice,
                            selected: false,
                            onTap: () {
                              final next = [...selectedParts, choice];
                              setState(() {
                                _selectedListeningAnswer = next.join(' ');
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 22),
                  this._solidButton(
                    text: displayIndex >= _total ? 'Hoàn thành' : 'Kiểm tra',
                    icon: Icons.check_rounded,
                    color: Color(0xff4257ff),
                    onTap: this._submitListeningAnswer,
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }


  Widget _buildMultipleChoiceMode() {
    return ColoredBox(
      color: Colors.black,
      child: ListView.builder(
        controller: _mcScrollController,
        padding: EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: _quizCards.length + 1,
        itemBuilder: (context, index) {
          if (index < _quizCards.length) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 760),
                child: this._buildQuestionCard(_quizCards[index], index),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(0, 6, 0, 18),
            child: Align(
              alignment: Alignment.centerRight,
              child: this._solidButton(
                text: _finished ? 'Xem kết quả' : 'Nộp bài',
                icon: Icons.flag_rounded,
                color: Color(0xff4257ff),
                onTap: _finished
                    ? _showResultSheet
                    : this._submitMultipleChoice,
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildSingleCardMultipleChoiceMode() {
    final card = _quizCards[_currentEssayIndex];
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
          child: Container(
            constraints: BoxConstraints(maxWidth: 720),
            child: this._buildQuestionCard(card, _currentEssayIndex),
          ),
        ),
      ),
    );
  }


  Widget _loadingShimmer({
    double? width,
    required double height,
    double radius = 14,
  }) {
    return _SilverShimmerBlock(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }

}
