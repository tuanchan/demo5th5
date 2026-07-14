part of flutterflashcard_main;

extension FlashCardsPageStatePart05 on _FlashCardsPageState {
  Future<bool> _saveCurrentCardExamples(
    String generatedText, {
    bool showMessage = true,
  }) async {
    final card = currentCard;
    if (card == null) return false;

    final examples = this._parseGeminiExamples(generatedText);
    if (examples.isEmpty) {
      if (showMessage) {
        this.showFlashMessage('Gemini chưa tạo ví dụ để lưu');
      }
      return false;
    }

    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.delete(
          'card_examples',
          where: 'cardId = ?',
          whereArgs: [card.id],
        );
        for (final example in examples) {
          await txn.insert('card_examples', {
            'cardId': card.id,
            'exampleText': example['exampleText'] ?? '',
            'pronunciation': example['note'] ?? '',
            'meaning': example['meaning'] ?? '',
            'createdAt': now,
            'updatedAt': now,
          });
        }
      });

      if (!mounted) return true;
      if (showMessage) {
        this.showFlashMessage('Đã lưu ${examples.length} ví dụ Gemini');
      }
      return true;
    } catch (e) {
      if (showMessage) {
        this.showFlashMessage('Không lưu được ví dụ Gemini');
      }
      debugPrint('SAVE GEMINI EXAMPLES ERROR: $e');
      return false;
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

      if (SupabaseConfig.isLoggedIn) {
        await db.update(
          'cards',
          {'deletedAt': now, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [card.id],
        );
      } else {
        await db.delete('cards', where: 'id = ?', whereArgs: [card.id]);
      }

      await this.loadCardsForCourse(selectedCourseId);
      this.showFlashMessage("Đã xóa thẻ");
      if (SupabaseConfig.isLoggedIn) {
        unawaited(
          SupabaseSyncService.instance.syncPendingChanges().then((syncResult) {
            if (syncResult.hasError) {
              debugPrint('DELETE CARD SYNC ERROR: ${syncResult.error}');
            }
          }),
        );
      }
    } catch (e) {
      this.showFlashMessage("Xóa thẻ thất bại");
      debugPrint("DELETE CARD ERROR: $e");
    }
  }


  Widget buildTopBar() {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Color(0xff0b0c0f),
        border: Border(
          bottom: BorderSide(color: Color(0xff1f2026), width: 1),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, {'courseId': selectedCourseId}),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xfff8fafc),
              padding: EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size(0, 32),
              textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text('← Trang chủ'),
          ),
          Spacer(),
          TextButton(
            onPressed: () {
              setState(() => flashcardTableVisible = false);
            },
            style: TextButton.styleFrom(
              foregroundColor: flashcardTableVisible
                  ? Color(0xff8f96aa)
                  : Color(0xffffffff),
              padding: EdgeInsets.symmetric(horizontal: 8),
              textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            child: Text('Học thẻ'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                flashcardTableVisible = true;
                selectedVocabRow = currentPos;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: flashcardTableVisible
                  ? Color(0xffffffff)
                  : Color(0xff8f96aa),
              padding: EdgeInsets.symmetric(horizontal: 8),
              textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text('Bảng'),
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
                        child: Text(
                          progressDragText,
                          style: TextStyle(
                            color: progressDragKnown
                                ? Color(0xff86efac)
                                : Color(0xffff7a95),
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            shadows: [
                              Shadow(
                                color: progressDragColor.withOpacity(0.95),
                                blurRadius: 7,
                              ),
                              Shadow(
                                color: progressDragColor.withOpacity(0.68),
                                blurRadius: 18,
                              ),
                              Shadow(
                                color: progressDragColor.withOpacity(0.42),
                                blurRadius: 34,
                              ),
                            ],
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
