part of flutterflashcard_main;

extension ReviewPracticeMatchingPairs on _ReviewPracticePageState {
  Future<void> _handleMatchPairTap(_MatchPairTile tile) async {
    if (_finished || _matchedPairCardIds.contains(tile.cardId)) return;
    if (_wrongMatchPairTileIds.contains(tile.tileId)) return;

    final selectedId = _selectedMatchPairTileId;
    if (selectedId == null) {
      setState(() {
        _selectedMatchPairTileId = tile.tileId;
      });
      return;
    }

    if (selectedId == tile.tileId) {
      setState(() {
        _selectedMatchPairTileId = null;
      });
      return;
    }

    final first = _matchPairTiles.firstWhere((e) => e.tileId == selectedId);
    final isMatch = first.cardId == tile.cardId && first.isTerm != tile.isTerm;

    if (!isMatch) {
      setState(() {
        _selectedMatchPairTileId = null;
        _wrongMatchPairTileIds
          ..clear()
          ..add(first.tileId)
          ..add(tile.tileId);
      });
      Future.delayed(Duration(milliseconds: 420), () {
        if (!mounted) return;
        setState(() {
          _wrongMatchPairTileIds.clear();
        });
      });
      return;
    }

    final card = _quizCards.firstWhere((e) => e.id == tile.cardId);
    setState(() {
      _selectedMatchPairTileId = null;
      _matchedPairCardIds.add(tile.cardId);
      _answeredCards.add(tile.cardId);
      _correctMap[tile.cardId] = true;
      _selectedAnswerMap[tile.cardId] = '${first.text} = ${tile.text}';
      _correctMatchPairTileIds
        ..add(first.tileId)
        ..add(tile.tileId);
      if (_matchedPairCardIds.length >= _quizCards.length) {
        _finished = true;
      }
    });

    await this._recordStudyResult(
      card: card,
      answerText: '${first.text} = ${tile.text}',
      isCorrect: true,
    );

    final nextPageIndex = _matchedPairCardIds.length ~/ 5;
    final isPageComplete = _matchedPairCardIds.length % 5 == 0;

    Future.delayed(Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(() {
        _correctMatchPairTileIds
          ..remove(first.tileId)
          ..remove(tile.tileId);
        if (_finished) {
          // Do nothing, session completes below
        } else if (isPageComplete) {
          this._setupMatchingTilesForPage(nextPageIndex);
        }
      });
    });

    if (_finished) {
      await this._finishStudySession();
    }
  }

  Widget _buildMatchingPairsMode() {
    final terms = _matchPairTiles.where((tile) => tile.isTerm).toList();
    final answers = _matchPairTiles.where((tile) => !tile.isTerm).toList();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, _finished ? 110 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _finished
                      ? 'Chúc mừng hoàn thành'
                      : 'Nhấn vào các cặp tương ứng',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = 12.0;
                    final tileWidth = (constraints.maxWidth - gap) / 2;
                    final rowCount = math.max(terms.length, answers.length);

                    return Column(
                      children: [
                        for (var i = 0; i < rowCount; i++) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: tileWidth,
                                child: i < terms.length
                                    ? _MatchPairTileWidget(
                                        tile: terms[i],
                                        selected: _selectedMatchPairTileId == terms[i].tileId,
                                        matched: _matchedPairCardIds.contains(terms[i].cardId),
                                        wrong: _wrongMatchPairTileIds.contains(terms[i].tileId),
                                        correctPulse: _correctMatchPairTileIds.contains(terms[i].tileId),
                                        onTap: _matchedPairCardIds.contains(terms[i].cardId)
                                            ? null
                                            : () => this._handleMatchPairTap(terms[i]),
                                      )
                                    : SizedBox.shrink(),
                              ),
                              SizedBox(width: gap),
                              SizedBox(
                                width: tileWidth,
                                child: i < answers.length
                                    ? _MatchPairTileWidget(
                                        tile: answers[i],
                                        selected: _selectedMatchPairTileId == answers[i].tileId,
                                        matched: _matchedPairCardIds.contains(answers[i].cardId),
                                        wrong: _wrongMatchPairTileIds.contains(answers[i].tileId),
                                        correctPulse: _correctMatchPairTileIds.contains(answers[i].tileId),
                                        onTap: _matchedPairCardIds.contains(answers[i].cardId)
                                            ? null
                                            : () => this._handleMatchPairTap(answers[i]),
                                      )
                                    : SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (i < rowCount - 1) SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchPairTileWidget extends StatefulWidget {
  final _MatchPairTile tile;
  final bool selected;
  final bool matched;
  final bool wrong;
  final bool correctPulse;
  final VoidCallback? onTap;

  const _MatchPairTileWidget({
    Key? key,
    required this.tile,
    required this.selected,
    required this.matched,
    required this.wrong,
    required this.correctPulse,
    this.onTap,
  }) : super(key: key);

  @override
  State<_MatchPairTileWidget> createState() => _MatchPairTileWidgetState();
}

class _MatchPairTileWidgetState extends State<_MatchPairTileWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.92), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.98), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _MatchPairTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wrong && !oldWidget.wrong) {
      _shakeController.forward(from: 0.0);
    }
    if (widget.correctPulse && !oldWidget.correctPulse) {
      _bounceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final selected = widget.selected;
    final matched = widget.matched;
    final wrong = widget.wrong;
    final correctPulse = widget.correctPulse;

    final borderColor = wrong
        ? AppColors.red
        : (correctPulse
              ? AppColors.green
              : (selected
                    ? AppColors.blue
                    : (matched
                          ? AppColors.border.withOpacity(0.35)
                          : AppColors.border)));

    final bg = correctPulse
        ? AppColors.green.withOpacity(0.18)
        : (matched
              ? AppColors.panel2.withOpacity(0.4)
              : (selected
                    ? AppColors.blue.withOpacity(0.18)
                    : AppColors.panel));

    final textColor = matched && !correctPulse
        ? AppColors.muted.withOpacity(0.5)
        : (wrong
              ? AppColors.red
              : (correctPulse
                    ? AppColors.green
                    : AppColors.text));

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeAnimation, _bounceAnimation]),
        builder: (context, child) {
          final double dx = _shakeController.isAnimating || wrong
              ? _shakeAnimation.value
              : 0.0;
          final double scale = _bounceController.isAnimating || correctPulse
              ? _bounceAnimation.value
              : 1.0;

          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: wrong ? 70 : 180),
          curve: wrong ? Curves.easeInOut : Curves.easeOutBack,
          constraints: BoxConstraints(minHeight: 78),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withOpacity(matched ? 0.05 : 0.3),
                offset: Offset(0, correctPulse ? 6 : 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tile.subText.trim().isNotEmpty) ...[
                  Text(
                    tile.subText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withOpacity(0.55),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 3),
                ],
                Text(
                  tile.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: tile.text.length > 16 ? 18 : 22,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
