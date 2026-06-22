part of flutterflashcard_main;

extension FlashCardsPageStatePart05 on _FlashCardsPageState {
  Future<void> _saveCurrentCardExamples(String generatedText) async {
    final card = currentCard;
    if (card == null) return;

    final examples = this._parseGeminiExamples(generatedText);
    if (examples.isEmpty) {
      this.showFlashMessage('Gemini chưa tạo ví dụ để lưu');
      return;
    }

    try {
      final db = await AppDatabase.instance.database;
      await db.delete('card_examples', where: 'cardId = ?', whereArgs: [card.id]);
      final now = DateTime.now().toIso8601String();

      for (final example in examples) {
        await db.insert('card_examples', {
          'cardId': card.id,
          'exampleText': example['exampleText'] ?? '',
          'pronunciation': '',
          'meaning': example['meaning'] ?? '',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      if (!mounted) return;
      this.showFlashMessage('Đã lưu ${examples.length} ví dụ Gemini');
    } catch (e) {
      this.showFlashMessage('Không lưu được ví dụ Gemini');
      debugPrint('SAVE GEMINI EXAMPLES ERROR: $e');
    }
  }


  Future<void> deleteCurrentCard() async {
    final card = currentCard;
    if (card == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Xóa thẻ"),
          content: Text("Xóa thẻ \"${card.term}\"?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text("Xóa"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        'cards',
        {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [card.id],
      );

      await this.loadCardsForCourse(selectedCourseId);
      this.showFlashMessage("Đã xóa thẻ");
    } catch (e) {
      this.showFlashMessage("Xóa thẻ thất bại");
      debugPrint("DELETE CARD ERROR: $e");
    }
  }


  Widget buildTopBar() {
    String currentTitle = widget.courseTitle;
    if (selectedCourseId != null) {
      final currentCourse = courseList.where((c) => c.id == selectedCourseId);
      if (currentCourse.isNotEmpty) {
        currentTitle = currentCourse.first.title;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: AppColors.panel,
            onTap: () => Navigator.pop(context, true),
          ),
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  courseDropdownOpen = !courseDropdownOpen;
                });
              },
              child: Container(
                height: 50,
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.panel,
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
                    Expanded(
                      child: Text(
                        currentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    AnimatedRotation(
                      turns: courseDropdownOpen ? -0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: SvgPicture.asset(
                        'assets/icon/chevron-down-solid-full.svg',
                        width: 12,
                        height: 12,
                        colorFilter: ColorFilter.mode(
                          AppColors.text,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: AppColors.panel,
            onTap: this.openSettingsSheet,
          ),
        ],
      ),
    );
  }


  Widget buildEmptyState({required String title, required String message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 8),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 54, color: AppColors.border),
              SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  StudyCardItem? getPeekCard() {
    if (visibleOrder.isEmpty || cardDragDx.abs() < 1) return null;

    // Khi bật theo dõi tiến độ: chỉ preview thẻ sau, không preview thẻ trước.
    final peekPos = progressTracking
        ? currentPos + 1
        : (cardDragDx > 0 ? currentPos - 1 : currentPos + 1);
    if (peekPos < 0 || peekPos >= visibleOrder.length) return null;

    final realIndex = visibleOrder[peekPos];
    if (realIndex < 0 || realIndex >= allCards.length) return null;

    return allCards[realIndex];
  }


  Widget buildPeekCard() {
    if (!isDraggingCard || cardDragDx.abs() < 1) {
      return SizedBox.shrink();
    }

    final peekCard = this.getPeekCard();
    if (peekCard == null) return SizedBox.shrink();

    return IgnorePointer(
      child: this.buildCardFace(
        label: "",
        mainText: peekCard.term,
        subText: peekCard.pronunciation,
        isBack: false,
        isStarred: peekCard.isFavorite,
        showLabelChip: false,
      ),
    );
  }


  Future<void> finishSwipeCard(int delta) async {
    await this.moveCard(delta, playSwipeEffect: false, resetSwipeState: true);
  }


  Widget buildFlipCardFace(StudyCardItem card) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isFlipped ? math.pi : 0),
      duration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final showBack = value > math.pi / 2;
        final face = showBack
            ? this.buildCardFace(
                label: "Mặt sau",
                mainText: card.definition,
                subText: card.pronunciation,
                isBack: true,
                isStarred: card.isFavorite,
              )
            : this.buildCardFace(
                label: "Mặt trước",
                mainText: card.term,
                subText: card.pronunciation,
                isBack: false,
                isStarred: card.isFavorite,
              );

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showBack ? value - math.pi : value),
          child: face,
        );
      },
    );
  }


  Widget buildFlashCard(StudyCardItem card) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth <= 0
            ? 1.0
            : constraints.maxWidth;
        final cardHeight = constraints.maxHeight <= 0
            ? 1.0
            : constraints.maxHeight;
        final double verticalTouchFactor =
            (((cardDragStartLocalY / cardDragHeight) - 0.5).clamp(-0.5, 0.5) *
                    2)
                .toDouble();
        final double dragPercent = (cardDragDx / cardWidth)
            .clamp(-1.0, 1.0)
            .toDouble();
        final double rotate = dragPercent * 0.35 * verticalTouchFactor;
        final double progressDragAbs = (cardDragDx.abs() / (cardWidth * 0.5))
            .clamp(0.0, 1.0)
            .toDouble();
        final showProgressDragState =
            progressTracking && isDraggingCard && cardDragDx.abs() > 14;
        final progressDragKnown = cardDragDx > 0;
        final progressDragColor = progressDragKnown
            ? AppColors.green
            : AppColors.red;
        final progressDragText = progressDragKnown ? 'Đã thuộc' : 'Chưa thuộc';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (cardDragDx.abs() < 6 && cardDragDy.abs() < 6) {
              this.toggleFlip();
            }
          },
          onPanStart: (details) {
            setState(() {
              isDraggingCard = true;
              cardDragDx = 0;
              cardDragDy = 0;
              cardDragHeight = cardHeight;
              cardDragStartLocalY = details.localPosition.dy.clamp(
                0.0,
                cardHeight,
              );
            });
          },
          onPanUpdate: (details) {
            setState(() {
              cardDragDx = (cardDragDx + details.delta.dx).clamp(
                -cardWidth * 0.86,
                cardWidth * 0.86,
              );
              cardDragDy = (cardDragDy + details.delta.dy).clamp(
                -cardHeight * 0.34,
                cardHeight * 0.34,
              );
            });
          },
          onPanEnd: (details) async {
            final velocityX = details.velocity.pixelsPerSecond.dx;
            final double swipeLimit = progressTracking
                ? cardWidth * 0.5
                : cardWidth * 0.28;
            final shouldSwipeLeft =
                cardDragDx < -swipeLimit || velocityX < -650;
            final shouldSwipeRight = cardDragDx > swipeLimit || velocityX > 650;

            if (shouldSwipeLeft) {
              await this.finishSwipeCard(progressTracking ? -1 : 1);
              return;
            }

            if (shouldSwipeRight) {
              await this.finishSwipeCard(progressTracking ? 1 : -1);
              return;
            }

            setState(() {
              isDraggingCard = false;
              cardDragDx = 0;
              cardDragDy = 0;
            });
          },
          onPanCancel: () {
            setState(() {
              isDraggingCard = false;
              cardDragDx = 0;
              cardDragDy = 0;
            });
          },
          child: Transform.translate(
            offset: Offset(cardDragDx, cardDragDy),
            child: Transform.rotate(
              angle: rotate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  this.buildFlipCardFace(card),
                  if (showProgressDragState)
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: progressDragColor.withOpacity(
                              0.65 + 0.35 * progressDragAbs,
                            ),
                            width: 2.2 + 2.4 * progressDragAbs,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: progressDragColor.withOpacity(
                                0.28 + 0.32 * progressDragAbs,
                              ),
                              blurRadius: 18 + 18 * progressDragAbs,
                              spreadRadius: 1 + 3 * progressDragAbs,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showProgressDragState)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: progressDragColor.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.78),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: progressDragColor.withOpacity(0.42),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            progressDragText,
                            style: TextStyle(
                              color: AppColors.readableOn(progressDragColor),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
