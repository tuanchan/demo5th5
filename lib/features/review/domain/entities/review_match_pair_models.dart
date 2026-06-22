part of flutterflashcard_main;

class _MatchPairTile {
  final int tileId;
  final int cardId;
  final String text;
  final String subText;
  final bool isTerm;

  _MatchPairTile({
    required this.tileId,
    required this.cardId,
    required this.text,
    required this.subText,
    required this.isTerm,
  });
}
