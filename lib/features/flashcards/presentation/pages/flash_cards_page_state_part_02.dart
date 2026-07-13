part of flutterflashcard_main;

extension FlashCardsPageStatePart02 on _FlashCardsPageState {
  Future<Map<String, Object?>?> markCurrentCard(bool known) async {
    final card = currentCard;
    if (card == null) return null;

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    final rows = await db.query(
      'review_states',
      where: 'cardId = ?',
      whereArgs: [card.id],
      limit: 1,
    );

    final previousState = rows.isEmpty
        ? null
        : Map<String, Object?>.from(rows.first);
    final nextState = ReviewScheduler.nextState(
      cardId: card.id,
      previous: previousState,
      isCorrect: known,
      now: now,
    );

    if (rows.isEmpty) {
      await db.insert('review_states', nextState);
    } else {
      await db.update(
        'review_states',
        nextState,
        where: 'cardId = ?',
        whereArgs: [card.id],
      );
    }

    return previousState;
  }


  Future<void> playCurrentCardAudio() async {
    final card = currentCard;
    final courseId = selectedCourseId ?? widget.courseId;

    if (card == null) return;

    try {
      await TtsAudioCache.instance.playText(
        text: card.term,
        languageCode: _languageCode,
        courseId: courseId,
      );
    } catch (e) {
      this.showFlashMessage("Không phát được âm thanh");
      debugPrint("PLAY TTS ERROR: $e");
    }
  }


  void _playAutoAudioIfNeeded() {
    if (!autoPlayAudio || currentCard == null || showCompletion) return;
    Future.microtask(playCurrentCardAudio);
  }


  Future<void> openEditCardDialog() async {
    final card = currentCard;
    if (card == null) return;

    final termController = TextEditingController(text: card.term);
    final definitionController = TextEditingController(text: card.definition);
    final pronunciationController = TextEditingController(
      text: card.pronunciation,
    );

    String? errorText;

    final result = await showDialog<StudyCardItem>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.48),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget editInput({
              required TextEditingController controller,
              required String label,
              int maxLines = 1,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Color(0xffe6e6f0),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    maxLines: maxLines,
                    minLines: maxLines,
                    style: TextStyle(
                      color: Color(0xffe6e6f0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Color(0xff1a1a2e),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xff3c3c50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xff5a78ff)),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxWidth: 560),
                padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: Color(0xff141428),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Color(0x405a78ff)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x8c000000),
                      blurRadius: 44,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Chỉnh sửa thẻ",
                              style: TextStyle(
                                color: Color(0xffe6e6f0),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Color(0xffe6e6f0),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      editInput(
                        controller: termController,
                        label: "Từ vựng",
                      ),
                      SizedBox(height: 12),
                      editInput(
                        controller: definitionController,
                        label: "Nghĩa",
                        maxLines: 4,
                      ),
                      SizedBox(height: 12),
                      editInput(
                        controller: pronunciationController,
                        label: "Phiên âm",
                      ),
                      if (errorText != null) ...[
                        SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Color(0xffb3261e),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xffe6e6f0),
                              backgroundColor: Color(0x14ffffff),
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              side: BorderSide(color: Color(0x1affffff)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Hủy",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                                final term = termController.text.trim();
                                final definition = definitionController.text
                                    .trim();
                                final pronunciation = pronunciationController
                                    .text
                                    .trim();

                                if (term.isEmpty) {
                                  setDialogState(() {
                                    errorText = "Vui lòng nhập thuật ngữ";
                                  });
                                  return;
                                }

                                if (definition.isEmpty) {
                                  setDialogState(() {
                                    errorText = "Vui lòng nhập định nghĩa";
                                  });
                                  return;
                                }

                                Navigator.pop(
                                  dialogContext,
                                  card.copyWith(
                                    term: term,
                                    definition: definition,
                                    pronunciation: pronunciation,
                                  ),
                                );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff3e5cff),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 10,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Lưu",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    termController.dispose();
    definitionController.dispose();
    pronunciationController.dispose();

    if (result == null) return;

    try {
      final db = await AppDatabase.instance.database;

      final rawText = result.pronunciation.trim().isEmpty
          ? '${result.term}\t${result.definition}'
          : '${result.term}\t${result.definition} (${result.pronunciation})';

      await db.update(
        'cards',
        {
          'term': result.term,
          'definition': result.definition,
          'pronunciation': result.pronunciation,
          'rawText': rawText,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [result.id],
      );

      if (!mounted) return;

      setState(() {
        final index = allCards.indexWhere((e) => e.id == result.id);
        if (index >= 0) {
          allCards[index] = result;
        }
      });

      await TtsAudioCache.instance.ensureAudioForText(
        text: result.term,
        languageCode: _languageCode,
        courseId: result.courseId,
      );

      this.showFlashMessage("Đã sửa thẻ");
    } catch (e) {
      this.showFlashMessage("Sửa thẻ thất bại");
      debugPrint("EDIT CARD ERROR: $e");
    }
  }


  void toggleShuffle() {
    setState(() {
      shuffleEnabled = !shuffleEnabled;
      this.rebuildVisibleOrder(resetPosition: true);
      this.resetFlip();
    });
    this.saveFlashSettings();
  }


  void toggleStarredOnly() {
    setState(() {
      starredOnly = !starredOnly;
      this.rebuildVisibleOrder(resetPosition: true);
      this.resetFlip();
    });
    this.saveFlashSettings();
  }


  Future<void> toggleProgressMode() async {
    if (widget.dueOnly) {
      this.showFlashMessage("Ôn thẻ đến hạn luôn bật theo dõi SRS");
      return;
    }

    final nextValue = !progressTracking;

    await this._finishStudySession();

    setState(() {
      progressTracking = nextValue;
      currentPos = 0;
      showCompletion = false;
      progressKnownCount = 0;
      progressUnknownCount = 0;
      _progressHistory.clear();
      _sessionUnknownCardIds.clear();
      this.rebuildVisibleOrder(resetPosition: true);
      this.resetFlip();
    });

    await this.saveFlashSettings();

    if (progressTracking) {
      await this._startStudySessionIfNeeded();
    }
  }


  void toggleAutoPlayAudio() {
    setState(() {
      autoPlayAudio = !autoPlayAudio;
    });
    this.saveFlashSettings();
    this._playAutoAudioIfNeeded();
  }


  Future<void> restartStudy() async {
    await this._finishStudySession();
    setState(() {
      currentPos = 0;
      showCompletion = false;
      progressKnownCount = 0;
      progressUnknownCount = 0;
      _progressHistory.clear();
      _sessionUnknownCardIds.clear();
      this.rebuildVisibleOrder(resetPosition: true);
      this.resetFlip();
    });
    await this._startStudySessionIfNeeded();
  }


  Future<void> restartUnknownCards() async {
    if (_sessionUnknownCardIds.isEmpty) {
      this.showFlashMessage("Không có thẻ chưa thuộc để học lại");
      return;
    }

    final unknownIndices = <int>[];

    for (int i = 0; i < allCards.length; i++) {
      if (_sessionUnknownCardIds.contains(allCards[i].id)) {
        unknownIndices.add(i);
      }
    }

    if (unknownIndices.isEmpty) {
      this.showFlashMessage("Không tìm thấy thẻ chưa thuộc");
      return;
    }

    await this._finishStudySession();

    setState(() {
      visibleOrder = unknownIndices;
      currentPos = 0;
      showCompletion = false;
      progressKnownCount = 0;
      progressUnknownCount = 0;
      _progressHistory.clear();
      _sessionUnknownCardIds.clear();
      isFlipped = false;
    });
    await this._startStudySessionIfNeeded();
  }

}
