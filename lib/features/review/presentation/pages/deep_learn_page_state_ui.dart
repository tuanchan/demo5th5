part of flutterflashcard_main;

extension _DeepLearnPageStateUi on _DeepLearnPageState {
  static const Color _bg = Color(0xff000000);
  static const Color _surface = Color(0xff111318);
  static const Color _surfaceDark = Color(0xff050609);
  static const Color _border = Color(0xff242832);
  static const Color _borderStrong = Color(0xff343b49);
  static const Color _primary = Color(0xff4257ff);
  static const Color _green = Color(0xff20d397);
  static const Color _greenLight = Color(0xff57f2bc);
  static const Color _orange = Color(0xffff6a00);
  static const Color _muted = Color(0xffa8b6d6);

  Widget _buildDeepLearnPage(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 680;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _primary, surface: _surface),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xff0b0c10),
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 66,
          shape: const Border(bottom: BorderSide(color: _border)),
          leadingWidth: compact ? 56 : 150,
          leading: TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: compact ? const SizedBox.shrink() : const Text('Trang chủ'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          title: Text(
            'Kiểm tra',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Tùy chọn học',
              onPressed: () => setState(() => _settingsOpen = !_settingsOpen),
              color: _settingsOpen ? const Color(0xffa8a8ff) : Colors.white,
              icon: const Icon(Icons.settings, size: 21),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _buildLearnBody(compact)),
            if (_settingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _settingsOpen = false),
                ),
              ),
            if (_settingsOpen)
              Positioned(
                top: 12,
                right: compact ? 14 : 24,
                child: GestureDetector(
                  onTap: () {},
                  child: _buildSettingsPopover(compact),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnBody(bool compact) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.menu_book_outlined, color: _muted, size: 58),
              SizedBox(height: 16),
              Text('Cần có từ và nghĩa để bắt đầu học.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 40, compact ? 24 : 44, compact ? 14 : 40, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              _buildProgress(),
              const SizedBox(height: 26),
              if (_completed) _buildCompletion(compact) else _buildQuestionCard(compact),
              if (!_completed && _feedback?.correct == false) _buildContinueBar(compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final progress = _total == 0
        ? 0.0
        : (_correct / _total).clamp(0.0, 1.0).toDouble();
    Widget badge(String value, Color color) => Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        );
    return Row(
      children: [
        badge('$_correct', const Color(0xff0ca579)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 16,
              color: const Color(0xff303744),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(colors: [Color(0xff10a57a), Color(0xff28c98f)]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        badge('$_total', const Color(0xff303744)),
      ],
    );
  }

  Widget _buildQuestionCard(bool compact) {
    final question = _current;
    if (question == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 500 : 468),
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question.promptLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          SizedBox(height: question.type == _DeepLearnQuestionType.flashcard ? 14 : 26),
          _buildPrompt(question),
          const SizedBox(height: 24),
          if (_feedback != null && question.type != _DeepLearnQuestionType.multipleChoice)
            _buildFeedback(_feedback!)
          else if (question.type == _DeepLearnQuestionType.multipleChoice)
            _buildMultipleChoice(question, compact)
          else if (question.type == _DeepLearnQuestionType.written)
            _buildWritten(question)
          else
            _buildFlashcardActions(question),
        ],
      ),
    );
  }

  Widget _buildPrompt(_DeepLearnQuestion question) {
    final isFlash = question.type == _DeepLearnQuestionType.flashcard;
    return InkWell(
      onTap: isFlash
          ? () {
              if (!question.flipped) setState(() => question.flipped = true);
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: isFlash ? Alignment.center : Alignment.centerLeft,
        constraints: BoxConstraints(minHeight: isFlash ? 220 : 118),
        child: SelectableText(
          question.flipped ? question.answer : question.prompt,
          textAlign: isFlash ? TextAlign.center : TextAlign.left,
          style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.35, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMultipleChoice(_DeepLearnQuestion question, bool compact) {
    final feedback = _feedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          feedback?.message ?? 'Chọn đáp án đúng',
          style: TextStyle(
            color: feedback == null ? Colors.white : (feedback.correct ? _greenLight : const Color(0xffff8a1f)),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final oneColumn = compact || constraints.maxWidth < 620;
            final width = oneColumn ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: question.choices.asMap().entries.map((entry) {
                return SizedBox(width: width, child: _buildChoice(question, entry.key, entry.value));
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: feedback == null ? () => _missCurrent(skipped: true) : null,
            child: const Text('Bạn không biết?', style: TextStyle(color: Color(0xffaebcff), fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _buildChoice(_DeepLearnQuestion question, int index, String value) {
    final feedback = _feedback;
    final isCorrectChoice = _isChoiceCorrect(value, question.answer);
    final isPicked = feedback != null && _normalizeAnswer(value, question.answer) == _normalizeAnswer(feedback.pickedValue, question.answer);
    Color color = _borderStrong;
    double opacity = 1;
    IconData? mark;
    if (feedback != null) {
      if (isCorrectChoice) {
        color = _greenLight;
        mark = Icons.check;
      } else if (!feedback.correct && isPicked && !feedback.skipped) {
        color = _orange;
        mark = Icons.close;
      } else {
        opacity = .42;
      }
    }
    final showPinyin = feedback != null &&
        !feedback.correct &&
        isCorrectChoice &&
        _hasChineseTerm(question.card) &&
        question.card.pronunciation.trim().isNotEmpty;
    return Opacity(
      opacity: opacity,
      child: OutlinedButton(
        onPressed: feedback == null
            ? () => _submitChoice(value)
            : (!feedback.correct && isCorrectChoice
                  ? _continueFeedback
                  : null),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(76),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          foregroundColor: Colors.white,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            if (mark != null) ...[
              Icon(mark, color: color, size: 26),
              const SizedBox(width: 12),
            ],
            Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showPinyin) ...[
                    const SizedBox(height: 5),
                    Text(
                      question.card.pronunciation.trim(),
                      style: const TextStyle(
                        color: _greenLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWritten(_DeepLearnQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Đáp án của bạn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(
          controller: _answerController,
          autofocus: true,
          onSubmitted: (_) => _submitWritten(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: 'Nhập đáp án',
            hintStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: _surfaceDark,
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _borderStrong, width: 2), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _primary, width: 2), borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => _missCurrent(skipped: true), child: const Text('Bạn không biết?', style: TextStyle(color: Color(0xffaebcff), fontWeight: FontWeight.w900))),
            const SizedBox(width: 16),
            _primaryButton('Kiểm tra', _submitWritten),
          ],
        ),
      ],
    );
  }

  Widget _buildFlashcardActions(_DeepLearnQuestion question) {
    return Column(
      children: [
        Text(
          question.flipped ? 'Bạn có biết đáp án này không?' : 'Bấm thẻ để lật',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 22,
          runSpacing: 12,
          children: question.flipped
              ? [
                  TextButton(onPressed: () => _missCurrent(skipped: true), child: const Text('Không biết', style: TextStyle(color: Color(0xffaebcff), fontWeight: FontWeight.w900))),
                  _primaryButton('Biết', () => _passCurrent()),
                ]
              : [
                  _primaryButton('Lật thẻ', () => setState(() => question.flipped = true)),
                  TextButton(onPressed: () => _missCurrent(skipped: true), child: const Text('Bạn không biết?', style: TextStyle(color: Color(0xffaebcff), fontWeight: FontWeight.w900))),
                ],
        ),
      ],
    );
  }

  Widget _buildFeedback(_DeepLearnFeedback feedback) {
    final card = _current?.card;
    final showPinyin = !feedback.correct &&
        card != null &&
        _hasChineseTerm(card) &&
        card.pronunciation.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: feedback.correct ? _green : _orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feedback.correct ? feedback.message : 'Đáp án đúng', style: TextStyle(color: feedback.correct ? _greenLight : const Color(0xffff8a1f), fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SelectableText(feedback.answer, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          if (showPinyin) ...[
            const SizedBox(height: 8),
            SelectableText(
              card.pronunciation.trim(),
              style: const TextStyle(
                color: _greenLight,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasChineseTerm(StudyCardItem card) {
    return RegExp(r'[\u3400-\u9fff\uf900-\ufaff]').hasMatch(card.term);
  }

  Widget _buildContinueBar(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 60, 28, compact ? 8 : 60, 0),
      child: Row(
        children: [
          const Expanded(child: Text('Nhấn vào câu trả lời đúng hoặc nút tiếp tục.', style: TextStyle(color: Color(0xffdce3ff), fontWeight: FontWeight.w900))),
          const SizedBox(width: 18),
          _primaryButton('Tiếp tục', _continueFeedback),
        ],
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback? onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), shape: const StadiumBorder()),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildSettingsPopover(bool compact) {
    final question = _current;
    final starred = question != null && _starred.contains(question.card.id);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: compact ? MediaQuery.sizeOf(context).width - 28 : 386,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff080719),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff343b5c)),
          boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 48, offset: Offset(0, 18))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _sideAction(Icons.shuffle, () {
                  setState(() => _queue.shuffle(_random));
                  _saveState();
                }),
                const SizedBox(width: 14),
                _sideAction(starred ? Icons.star : Icons.star_border, _toggleStar, active: starred),
                const SizedBox(width: 14),
                _sideAction(Icons.volume_up_outlined, _speak),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loại câu hỏi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  _settingToggle(Icons.checklist, 'Trắc nghiệm', _multipleChoice, () => _toggleType(_DeepLearnQuestionType.multipleChoice)),
                  _settingToggle(Icons.edit_outlined, 'Tự luận', _written, () => _toggleType(_DeepLearnQuestionType.written)),
                  _settingToggle(Icons.style_outlined, 'Thẻ ghi nhớ', _flashcard, () => _toggleType(_DeepLearnQuestionType.flashcard)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xffdce3ff), side: const BorderSide(color: _borderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Reset học lại', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideAction(IconData icon, VoidCallback onTap, {bool active = false}) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: active ? const Color(0x2e4257ff) : Colors.transparent,
          minimumSize: const Size(0, 56),
          side: const BorderSide(color: Color(0xffa8a8ff), width: 2),
          shape: const StadiumBorder(),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }

  Widget _settingToggle(IconData icon, String text, bool value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Icon(icon, color: const Color(0xffdce3ff), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
            Switch(value: value, onChanged: (_) => onTap(), activeTrackColor: _primary, activeColor: const Color(0xffdfe6ff)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletion(bool compact) {
    final wrongCards = _cards.where((card) => _wrongMap.containsKey(card.id)).toList();
    final wrongCount = _wrongMap.values.fold<int>(0, (sum, count) => sum + count);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 468),
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_outlined, color: _greenLight, size: 54),
          const SizedBox(height: 16),
          Text('Hoàn thành chế độ Học', style: TextStyle(color: Colors.white, fontSize: compact ? 27 : 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Bạn đã học xong ${_mastered.length} thuật ngữ.', style: const TextStyle(color: Color(0xffdce3ff), fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Số câu sai: $wrongCount', style: const TextStyle(color: Color(0xffdce3ff), fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: wrongCards.isEmpty
                ? const Text('Không có từ sai.', style: TextStyle(color: _muted, fontWeight: FontWeight.w800))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: wrongCards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final card = wrongCards[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _surfaceDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                        child: compact
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(card.term, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(card.definition, style: const TextStyle(color: Color(0xffdce3ff)))])
                            : Row(children: [SizedBox(width: 220, child: Text(card.term, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))), Expanded(child: Text(card.definition, style: const TextStyle(color: Color(0xffdce3ff))))]),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              OutlinedButton(onPressed: wrongCards.isEmpty ? null : () => _reset(onlyCards: wrongCards), child: const Text('Học lại từ sai')),
              OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Trang chủ')),
              _primaryButton('Làm lại từ đầu', _reset),
            ],
          ),
        ],
      ),
    );
  }
}
