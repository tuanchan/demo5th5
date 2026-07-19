part of flutterflashcard_main;

class StudyCardItem {
  final int id;
  final int courseId;
  final int position;
  final String term;
  final String definition;
  final String pronunciation;
  final bool isFavorite;

  StudyCardItem({
    required this.id,
    required this.courseId,
    required this.position,
    required this.term,
    required this.definition,
    required this.pronunciation,
    required this.isFavorite,
  });

  factory StudyCardItem.fromMap(Map<String, Object?> map) {
    return StudyCardItem(
      id: map['id'] as int,
      courseId: map['courseId'] as int,
      position: _dbInt(map['position']),
      term: map['term']?.toString() ?? '',
      definition: map['definition']?.toString() ?? '',
      pronunciation: map['pronunciation']?.toString() ?? '',
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
    );
  }

  StudyCardItem copyWith({
    String? term,
    String? definition,
    String? pronunciation,
    bool? isFavorite,
  }) {
    return StudyCardItem(
      id: id,
      courseId: courseId,
      position: position,
      term: term ?? this.term,
      definition: definition ?? this.definition,
      pronunciation: pronunciation ?? this.pronunciation,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class ProgressUndoItem {
  final int cardId;
  final int previousPos;
  final bool previousCompletion;
  final bool known;
  final Map<String, Object?>? previousReviewState;
  final int? studyResultId;

  ProgressUndoItem({
    required this.cardId,
    required this.previousPos,
    required this.previousCompletion,
    required this.known,
    required this.previousReviewState,
    required this.studyResultId,
  });
}

class FlashCardsPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final bool dueOnly;
  final List<int>? cardIds;

  FlashCardsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.dueOnly = false,
    this.cardIds,
  });

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class ReviewPracticePage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String courseLanguageCode;
  final bool dueOnly;
  final String? presetMode;
  final List<int>? cardIds;

  ReviewPracticePage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseLanguageCode,
    this.dueOnly = false,
    this.presetMode,
    this.cardIds,
  });

  @override
  State<ReviewPracticePage> createState() => _ReviewPracticePageState();
}

class DeepLearnPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String courseLanguageCode;
  final List<int>? cardIds;
  final bool dueOnly;

  const DeepLearnPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseLanguageCode,
    this.cardIds,
    this.dueOnly = false,
  });

  @override
  State<DeepLearnPage> createState() => _DeepLearnPageState();
}

class _GeneratedSentenceQuestion {
  final int cardId;
  final String question;
  final String answer;

  _GeneratedSentenceQuestion({
    required this.cardId,
    required this.question,
    required this.answer,
  });
}

class _GeminiTextGradeItem {
  final int cardId;
  final bool isCorrect;
  final String feedback;

  _GeminiTextGradeItem({
    required this.cardId,
    required this.isCorrect,
    required this.feedback,
  });
}

class _SilverShimmerBlock extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const _SilverShimmerBlock({
    this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_SilverShimmerBlock> createState() => _SilverShimmerBlockState();
}

class _SilverShimmerBlockState extends State<_SilverShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 260.0;
                final bandWidth = math.max(90.0, width * 0.48);
                final left =
                    (width + bandWidth) * _controller.value - bandWidth;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xffe5eaf0)),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: bandWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Color(0xffcfd6df).withOpacity(0.65),
                              Color(0xfff8fafc),
                              Color(0xffcfd6df).withOpacity(0.65),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.24, 0.5, 0.76, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String normalizeText(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r"""[.,!?;:'"()\[\]{}，。！？；：''"「」『』（）【】、《》〈〉]"""), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double calcSimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a == b) return 1.0;

  final la = a.split('');
  final lb = b.split('');
  final m = la.length;
  final n = lb.length;

  final dp = List.generate(
    m + 1,
    (i) => List.generate(n + 1, (j) {
      if (i == 0) return j;
      if (j == 0) return i;
      return 0;
    }),
  );

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (la[i - 1] == lb[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] =
            1 +
            [
              dp[i - 1][j],
              dp[i][j - 1],
              dp[i - 1][j - 1],
            ].reduce((a, b) => a < b ? a : b);
      }
    }
  }

  final dist = dp[m][n];
  final maxLen = math.max(m, n);
  return maxLen == 0 ? 1.0 : math.max(0.0, 1.0 - dist / maxLen);
}

bool _isCJKLang(String lang) => lang.startsWith('zh') || lang.startsWith('ja');

List<_WordResult> buildWordResults(String spoken, String target, String lang) {
  final spokenNorm = normalizeText(spoken);
  final targetNorm = normalizeText(target);

  if (_isCJKLang(lang)) {
    final targetChars = targetNorm.split('');
    return spokenNorm.split('').map((ch) {
      return _WordResult(text: ch, ok: targetChars.contains(ch));
    }).toList();
  } else {
    final targetWords = targetNorm.split(' ');
    return spokenNorm.split(' ').map((w) {
      final ok = targetWords.any(
        (tw) => tw == w || tw.contains(w) || w.contains(tw),
      );
      return _WordResult(text: w, ok: ok);
    }).toList();
  }
}

class _WordResult {
  final String text;
  final bool ok;
  _WordResult({required this.text, required this.ok});
}

// ─── Pronunciation Overlay ────────────────────────────────────────────────────

class PronunciationOverlay extends StatefulWidget {
  final String targetText;
  final String subText;
  final String languageCode;

  PronunciationOverlay({
    super.key,
    required this.targetText,
    required this.subText,
    required this.languageCode,
  });

  @override
  State<PronunciationOverlay> createState() => _PronunciationOverlayState();
}

class _MicButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  _MicButton({required this.label, required this.color, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 5),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0x18000000),
              offset: Offset(0, isPressed ? 4 : 12),
              blurRadius: isPressed ? 6 : 18,
            ),
          ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: AppColors.border,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );
  }
}

class LightInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final double height;

  LightInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border, width: 1.8),
          ),
        ),
      ),
    );
  }
}
