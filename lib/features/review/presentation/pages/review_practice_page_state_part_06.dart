part of flutterflashcard_main;

extension ReviewPracticePageStatePart06 on _ReviewPracticePageState {
  Widget _buildReviewStandardHeader(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 680;
    final sideWidth = compact ? 56.0 : 150.0;
    return Container(
      width: double.infinity,
      height: 66,
      decoration: BoxDecoration(
        color: Color(0xff0b0c10),
        border: Border(bottom: BorderSide(color: Color(0xff242832))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context, {'courseId': widget.courseId}),
              icon: Icon(Icons.arrow_back, size: 17),
              label: compact ? SizedBox.shrink() : Text('Trang chủ'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12),
                textStyle: TextStyle(fontWeight: FontWeight.w400),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Kiểm tra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Tùy chọn kiểm tra',
                  onPressed: this._openSetupSheet,
                  color: Colors.white,
                  icon: Icon(Icons.settings, size: 21),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _switchTile({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: Color(0xff4257ff),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }


  Widget _solidButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _outlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Color(0xff171c28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xff343b49)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (text.trim().isNotEmpty) ...[
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _reviewAnswerBox({
    required String text,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Color(0xff111318),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xff242832)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _geminiReviewBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Color(0xff111318),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xff242832)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 21,
            color: Color(0xff4257ff),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _resultBox(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Color(0xff9aa4b8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }


  Widget _statChip({required String text}) {
    return Text(
      text,
      style: TextStyle(
        color: Color(0xff9aa4b8),
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
    );
  }


  Widget _buildQuestionCard(StudyCardItem card, int index) {
    final answered = _answeredCards.contains(card.id);
    final selected = _selectedAnswerMap[card.id];
    final correctAnswer = this._optionLabelOf(card);
    final isCorrect = _correctMap[card.id] == true;
    final choices = _choiceMap[card.id] ?? <String>[];

    return Container(
      key: _questionKeys[card.id],
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xff111318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xff242832)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa',
                style: TextStyle(
                  color: Color(0xff9aa4b8),
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
              ),
              Spacer(),
              Text(
                '${index + 1} / $_total',
                style: TextStyle(
                  color: Color(0xff9aa4b8),
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Center(
            child: Text(
              this._promptOf(card),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: this._promptOf(card).length > 28 ? 24 : 32,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
          if (this._subPromptOf(card).trim().isNotEmpty) ...[
            SizedBox(height: 6),
            Center(
              child: Text(
                this._subPromptOf(card),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff9aa4b8),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          Text(
            'Chọn đáp án đúng',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 340;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: choices.asMap().entries.map((entry) {
                  final choice = entry.value;
                  final isSelected = selected == choice;
                  final isCorrectChoice =
                      this._normalizeAnswer(choice) ==
                      this._normalizeAnswer(correctAnswer);
                  Color bg = Colors.transparent;
                  Color choiceBorder = Color(0xff343b49);
                  if (_finished && isCorrectChoice) {
                    bg = Color(0xff163c32);
                    choiceBorder = Color(0xff57f2bc);
                  }
                  if (_finished && isSelected && !isCorrectChoice) {
                    bg = Color(0xff3f262b);
                    choiceBorder = Color(0xffff6a00);
                  }
                  if (!_finished && isSelected) {
                    bg = Color(0xff1d2340);
                    choiceBorder = Color(0xff84a1ff);
                  }

                  return SizedBox(
                    width: twoCols
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth,
                    child: GestureDetector(
                      onTap: (answered || _finished)
                          ? null
                          : () => this._answerCard(card, choice),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 160),
                        constraints: BoxConstraints(minHeight: 52),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: choiceBorder,
                            width: isSelected ? 2 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_finished && isCorrectChoice)
                              Icon(
                                Icons.check_rounded,
                                color: Color(0xff57f2bc),
                                size: 25,
                              )
                            else if (_finished && isSelected)
                              Icon(
                                Icons.close_rounded,
                                color: Color(0xffff7a1a),
                                size: 25,
                              )
                            else
                              SizedBox(
                                width: 25,
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: Color(0xff9aa4b8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                choice,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: (answered || _finished) ? null : () => this._skipCard(card),
              child: Text(
                _finished && answered && !isCorrect
                    ? 'Đáp án: $correctAnswer'
                    : 'Bạn không biết?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffaebcff),
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
