part of flutterflashcard_main;

extension ReviewPracticePageStatePart06 on _ReviewPracticePageState {
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
                color: AppColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.border,
            activeTrackColor: AppColors.green,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.onSolidButton, size: 20),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSolidButton,
                  fontWeight: FontWeight.w900,
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
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.onIconButton, size: 20),
            if (text.trim().isNotEmpty) ...[
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onIconButton,
                    fontWeight: FontWeight.w900,
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
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.border, size: 23),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
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
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          geminiColorIcon(size: 23),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _resultBox(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.3),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.border,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: AppColors.border,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _statChip({required String text, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.border,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 14),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border, width: 1.1),
                ),
                child: Text(
                  '${index + 1}/$_total',
                  style: TextStyle(
                    color: AppColors.onIconButton,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 14),
          Text(
            _answerByDefinition ? 'Thuật ngữ' : 'Định nghĩa',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              this._promptOf(card),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: this._promptOf(card).length > 20 ? 27 : 36,
                fontWeight: FontWeight.w900,
                height: 1.15,
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
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          SizedBox(height: 16),
          Text(
            'Chọn đáp án đúng',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 520;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: choices.map((choice) {
                  final isSelected = selected == choice;
                  final isCorrectChoice =
                      this._normalizeAnswer(choice) ==
                      this._normalizeAnswer(correctAnswer);
                  Color bg = AppColors.activeIsDark ? AppColors.panel2 : Color(0xfff7f9fc);
                  if (_finished && isCorrectChoice) bg = AppColors.green;
                  if (_finished && isSelected && !isCorrectChoice)
                    bg = AppColors.red;
                  if (!_finished && isSelected)
                    bg = AppColors.blue.withOpacity(0.35);

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
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.25,
                          ),
                          boxShadow: (answered || _finished)
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.border,
                                    offset: Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                        ),
                        child: Text(
                          choice,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
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
                  color: AppColors.border,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
