part of flutterflashcard_main;

extension SettingsPageStatePart02 on _SettingsPageState {
  Widget _pathBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }


  Widget _colorRow(String key, String label) {
    final current = AppColors.getByKey(key);
    return Container(
      margin: EdgeInsets.only(bottom: 13),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '#${current.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((color) {
              return InkWell(
                onTap: () async {
                  await AppColors.saveColor(key, color);
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.value == current.value
                          ? AppColors.text
                          : AppColors.border.withOpacity(0.35),
                      width: color.value == current.value ? 2.4 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
