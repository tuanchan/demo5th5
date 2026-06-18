part of flutterflashcard_main;

class MiniInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  MiniInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
          filled: true,
          fillColor: AppColors.panel,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
      ),
    );
  }
}


class SmallIcon3DButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  SmallIcon3DButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<SmallIcon3DButton> createState() => _SmallIcon3DButtonState();
}


class _SmallIcon3DButtonState extends State<SmallIcon3DButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.buttonInk, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(widget.icon, color: AppColors.border, size: 24),
      ),
    );
  }
}


class BigPopupButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  BigPopupButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<BigPopupButton> createState() => _BigPopupButtonState();
}


class _BigPopupButtonState extends State<BigPopupButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, isPressed ? 5 : 0, 0),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, isPressed ? 1 : 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: AppColors.border, size: 24),
            SizedBox(width: 10),
            Text(
              widget.text,
              style: TextStyle(
                color: AppColors.border,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class Big3DButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  Big3DButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<Big3DButton> createState() => _Big3DButtonState();
}


class _Big3DButtonState extends State<Big3DButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          isPressed = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 7 : 0, 0),
        width: screenW * 0.7,
        height: screenH * 0.13,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.buttonInk.withOpacity(0.95),
              offset: Offset(0, isPressed ? 1 : 8),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0x22000000),
              offset: Offset(0, isPressed ? 5 : 18),
              blurRadius: isPressed ? 8 : 28,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.buttonInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class CompactSelectItem {
  final String value;
  final String label;

  CompactSelectItem({required this.value, required this.label});
}


class CompactSelectBox extends StatelessWidget {
  final String title;
  final String value;
  final List<CompactSelectItem> items;
  final ValueChanged<String> onChanged;
  final TextEditingController customController;
  final String customHint;
  final bool showCustomInput;
  final ValueChanged<String> onCustomChanged;

  CompactSelectBox({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.customController,
    required this.customHint,
    required this.showCustomInput,
    required this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              final selected = item.value == value;

              return GestureDetector(
                onTap: () => onChanged(item.value),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 120),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.yellow : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.4),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: AppColors.border,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (showCustomInput) ...[
            SizedBox(height: 14),
            MiniInput(
              controller: customController,
              enabled: true,
              hintText: customHint,
              onChanged: onCustomChanged,
            ),
          ],
        ],
      ),
    );
  }
}


class ParsedDefinition {
  final String definition;
  final String pronunciation;

  ParsedDefinition({required this.definition, required this.pronunciation});
}


ParsedDefinition parseDefinitionAndPronunciationText(String raw) {
  final text = raw.trim();
  final regex = RegExp(r'^(.*?)\s*\((.*)\)\s*$');
  final match = regex.firstMatch(text);

  if (match == null) {
    return ParsedDefinition(definition: text, pronunciation: '');
  }

  final definition = match.group(1)?.trim() ?? '';
  final pronunciation = match.group(2)?.trim() ?? '';

  if (definition.isEmpty || pronunciation.isEmpty) {
    return ParsedDefinition(definition: text, pronunciation: '');
  }

  return ParsedDefinition(definition: definition, pronunciation: pronunciation);
}


class BuiltInVocabularyImportResult {
  final int importedCourses;
  final int importedCards;

  BuiltInVocabularyImportResult({
    required this.importedCourses,
    required this.importedCards,
  });
}

