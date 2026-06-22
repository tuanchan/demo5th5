part of flutterflashcard_main;

extension FlashCardsPageStatePart03 on _FlashCardsPageState {
  Future<void> resetMemorizedCards() async {
    try {
      final db = await AppDatabase.instance.database;

      await db.delete(
        'review_states',
        where: '''
        cardId IN (
          SELECT id FROM cards
          WHERE courseId = ? AND deletedAt IS NULL
        )
      ''',
        whereArgs: [selectedCourseId],
      );

      if (!mounted) return;

      setState(() {
        progressKnownCount = 0;
        progressUnknownCount = 0;
        _progressHistory.clear();
        _sessionUnknownCardIds.clear();
        currentPos = 0;
        showCompletion = false;
        isFlipped = false;
        this.rebuildVisibleOrder(resetPosition: true);
      });

      await this._finishStudySession();
      await this._startStudySessionIfNeeded();

      this.showFlashMessage("Đã đặt lại thẻ ghi nhớ");
    } catch (e) {
      this.showFlashMessage("Không đặt lại được thẻ ghi nhớ");
      debugPrint("RESET MEMORY ERROR: $e");
    }
  }


  void exitFlashCards() {
    this._finishStudySession();
    Navigator.pop(context, true);
  }


  Future<void> undoLastCard() async {
    if (_progressHistory.isEmpty) return;

    final undoItem = _progressHistory.removeLast();

    try {
      final db = await AppDatabase.instance.database;

      if (undoItem.previousReviewState == null) {
        await db.delete(
          'review_states',
          where: 'cardId = ?',
          whereArgs: [undoItem.cardId],
        );
      } else {
        final restored = Map<String, Object?>.from(
          undoItem.previousReviewState!,
        );
        restored.remove('id');
        await db.update(
          'review_states',
          restored,
          where: 'cardId = ?',
          whereArgs: [undoItem.cardId],
        );
      }
    } catch (e) {
      debugPrint("UNDO ERROR: $e");
    }

    setState(() {
      if (undoItem.known && progressKnownCount > 0) {
        progressKnownCount--;
      }
      if (!undoItem.known && progressUnknownCount > 0) {
        progressUnknownCount--;
        _sessionUnknownCardIds.remove(undoItem.cardId);
      }

      currentPos = undoItem.previousPos;
      showCompletion = undoItem.previousCompletion;
      isFlipped = false;
    });

    await this._deleteFlashStudyResult(undoItem.studyResultId, undoItem.known);
  }


  void openMicOverlay() {
    final card = currentCard;
    if (card == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => PronunciationOverlay(
        targetText: card.term,
        subText: card.pronunciation.isNotEmpty
            ? card.pronunciation
            : card.definition,
        languageCode: this._getCourseLanguageCode(),
      ),
    );
  }


  String _getCourseLanguageCode() {
    return _languageCode;
  }


  void showFlashMessage(String text) {
    showAppToast(context, text);
  }


  void openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget settingRow({
              required String title,
              required bool value,
              required VoidCallback onTap,
            }) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    onTap();
                    setSheetState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.panel2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 48,
                          height: 26,
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: value ? AppColors.border : AppColors.muted,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Text(
                      "Cài đặt Flash Card",
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18),
                    settingRow(
                      title: "Chỉ học thẻ đã gắn sao",
                      value: starredOnly,
                      onTap: this.toggleStarredOnly,
                    ),
                    settingRow(
                      title: "Trộn thẻ",
                      value: shuffleEnabled,
                      onTap: this.toggleShuffle,
                    ),
                    settingRow(
                      title: "Theo dõi tiến độ",
                      value: progressTracking,
                      onTap: this.toggleProgressMode,
                    ),
                    settingRow(
                      title: "Tự động phát âm",
                      value: autoPlayAudio,
                      onTap: this.toggleAutoPlayAudio,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}
