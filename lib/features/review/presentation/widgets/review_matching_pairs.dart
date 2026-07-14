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
      if (_matchedPairCardIds.length >= _quizCards.length) {
        _finished = true;
        _matchTimer?.cancel();
        _matchTimer = null;
        _matchStopwatch.stop();
      }
    });

    await this._recordStudyResult(
      card: card,
      answerText: '${first.text} = ${tile.text}',
      isCorrect: true,
    );

    const pairsPerPage = 6;
    final nextPageIndex = _matchedPairCardIds.length ~/ pairsPerPage;
    final isPageComplete = _matchedPairCardIds.length % pairsPerPage == 0;

    Future.delayed(Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(() {
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
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, _finished ? 100 : 10),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1040),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 700 ? 3 : 4;
                  final gap = constraints.maxWidth < 700 ? 6.0 : 12.0;
                  final rows = math.max(
                    1,
                    (_matchPairTiles.length / columns).ceil(),
                  );
                  final tileWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final fittingHeight =
                      (constraints.maxHeight - gap * (rows - 1)) / rows;
                  final tileHeight = math.max(94.0, fittingHeight);

                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                      childAspectRatio: tileWidth / tileHeight,
                    ),
                    itemCount: _matchPairTiles.length,
                    itemBuilder: (context, index) {
                      final tile = _matchPairTiles[index];
                      final matched = _matchedPairCardIds.contains(tile.cardId);
                      return _MatchPairTileWidget(
                        key: ValueKey('${tile.cardId}:${tile.isTerm}'),
                        tile: tile,
                        selected: _selectedMatchPairTileId == tile.tileId,
                        matched: matched,
                        wrong: _wrongMatchPairTileIds.contains(tile.tileId),
                        onTap: matched
                            ? null
                            : () => this._handleMatchPairTap(tile),
                      );
                    },
                  );
                },
              ),
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
  final VoidCallback? onTap;

  const _MatchPairTileWidget({
    Key? key,
    required this.tile,
    required this.selected,
    required this.matched,
    required this.wrong,
    this.onTap,
  }) : super(key: key);

  @override
  State<_MatchPairTileWidget> createState() => _MatchPairTileWidgetState();
}

class _MatchPairTileWidgetState extends State<_MatchPairTileWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _hovered = false;

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
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _MatchPairTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wrong && !oldWidget.wrong) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final active = widget.selected || widget.wrong;
    final fontSize = tile.isTerm
        ? (tile.text.length > 14
              ? 17.0
              : (tile.text.length > 7 ? 22.0 : 28.0))
        : (tile.text.length > 32
              ? 12.0
              : (tile.text.length > 18 ? 15.0 : 20.0));

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) {
        if (widget.onTap != null) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final dx = _shakeController.isAnimating
                ? _shakeAnimation.value
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, _hovered && !widget.matched ? -2 : 0),
              child: child,
            );
          },
          child: AnimatedOpacity(
            opacity: widget.matched ? 0 : 1,
            duration: Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: widget.matched ? 0.88 : 1,
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 120),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? Color(0xff4257ff)
                      : (_hovered ? Color(0xff3a4154) : Color(0xff2f3545)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Color(0x5984a1ff),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
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
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                            fontSize: 10,
                          ),
                        ),
                        SizedBox(height: 3),
                      ],
                      Text(
                        tile.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          fontSize: fontSize,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
