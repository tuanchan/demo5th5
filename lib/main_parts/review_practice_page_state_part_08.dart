part of flutterflashcard_main;

extension ReviewPracticePageStatePart08 on _ReviewPracticePageState {
  Widget _buildSentenceGeneratingMode() {
    final total = _displayTotal;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 720),
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  this._statChip(text: '0/$total', color: AppColors.blue),
                  Spacer(),
                  geminiColorIcon(size: 24),
                ],
              ),
              SizedBox(height: 24),
              Text(
                _answerByDefinition ? 'Câu ngoại ngữ' : 'Câu tiếng Việt',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideLine = math.min(330.0, constraints.maxWidth * 0.86);
                  final shortLine = math.min(
                    250.0,
                    constraints.maxWidth * 0.66,
                  );
                  return Center(
                    child: Column(
                      children: [
                        this._loadingShimmer(
                          width: wideLine,
                          height: 42,
                          radius: 999,
                        ),
                        SizedBox(height: 12),
                        this._loadingShimmer(
                          width: shortLine,
                          height: 28,
                          radius: 999,
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 28),
              this._loadingShimmer(height: 52, radius: 18),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: this._loadingShimmer(height: 50, radius: 16)),
                  SizedBox(width: 10),
                  Expanded(child: this._loadingShimmer(height: 50, radius: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildGeminiTextGradingMode() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
        child: Container(
          constraints: BoxConstraints(maxWidth: 720),
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.border,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  this._statChip(text: '$_total/$_total', color: AppColors.blue),
                  Spacer(),
                  geminiColorIcon(size: 24),
                ],
              ),
              SizedBox(height: 24),
              Text(
                'Gemini đang chấm',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    this._loadingShimmer(width: 280, height: 38, radius: 999),
                    SizedBox(height: 12),
                    this._loadingShimmer(width: 210, height: 24, radius: 999),
                  ],
                ),
              ),
              SizedBox(height: 28),
              this._loadingShimmer(height: 52, radius: 18),
            ],
          ),
        ),
      ),
    );
  }

}
