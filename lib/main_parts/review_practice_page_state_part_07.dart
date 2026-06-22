part of flutterflashcard_main;

extension ReviewPracticePageStatePart07 on _ReviewPracticePageState {
  Widget _buildEssayMode() {
    final card = _quizCards[_currentEssayIndex];
    final displayIndex = _currentEssayIndex + 1;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 720),
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  this._statChip(
                    text: '$displayIndex/$_total',
                    color: AppColors.blue,
                  ),
                  Spacer(),
                  if (_sentenceMode) geminiColorIcon(size: 24),
                ],
              ),
              SizedBox(height: 24),
              Text(
                _sentenceMode
                    ? (_answerByDefinition ? 'Câu ngoại ngữ' : 'Câu tiếng Việt')
                    : (_answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  this._promptOf(card),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: this._promptOf(card).length > 18 ? 34 : 46,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
              if (this._subPromptOf(card).trim().isNotEmpty) ...[
                SizedBox(height: 8),
                Center(
                  child: Text(
                    this._subPromptOf(card),
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              TextField(
                controller: _essayController,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
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
                  fillColor: Color(0xfff7f9fc),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.border, width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.border, width: 1.8),
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
                      color: AppColors.green,
                      onTap: () => this._submitEssay(allowEmptyAsSkip: true),
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


  Widget _listeningChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border, width: 1.25),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, selected ? 5 : 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
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
              .where((e) => e.trim().isNotEmpty)
              .toList();

    return ListView(
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
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 16),
                    blurRadius: 26,
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
                        color: AppColors.blue,
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
                              ? AppColors.yellow
                              : AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 7),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlayingListeningAudio
                              ? Icons.graphic_eq_rounded
                              : Icons.volume_up_rounded,
                          color: AppColors.border,
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
                      color: Color(0xfff7f9fc),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.35),
                        width: 1.25,
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
                    color: AppColors.green,
                    onTap: this._submitListeningAnswer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMultipleChoiceMode() {
    return ListView.builder(
      controller: _mcScrollController,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: _quizCards.length,
      itemBuilder: (context, index) =>
          this._buildQuestionCard(_quizCards[index], index),
    );
  }


  Widget _buildSingleCardMultipleChoiceMode() {
    final card = _quizCards[_currentEssayIndex];
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 720),
          child: this._buildQuestionCard(card, _currentEssayIndex),
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
