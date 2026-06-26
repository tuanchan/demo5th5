part of flutterflashcard_main;

extension CreateCoursePageStatePart02 on _CreateCoursePageState {
  void openSettingPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void refresh() {
              modalSetState(() {});
              setState(() {});
            }

            return Container(
              margin: EdgeInsets.all(14),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border,
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0x22000000),
                    offset: Offset(0, 20),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: AppColors.border, size: 26),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tùy chỉnh học phần",
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: AppColors.onIconButton),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      CompactSelectBox(
                        title: "GIỮA THUẬT NGỮ VÀ ĐỊNH NGHĨA",
                        value: termSeparatorType,
                        items: [
                          CompactSelectItem(value: "tab", label: "Tab"),
                          CompactSelectItem(
                            value: "underscore",
                            label: "Gạch dưới _",
                          ),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          termSeparatorType =
                              value == "comma" ? "underscore" : value;
                          this.saveCreateCourseSettings();
                          refresh();
                        },
                        customController: customTermSepController,
                        customHint: "vd: |",
                        showCustomInput: termSeparatorType == "custom",
                        onCustomChanged: (_) {
                          this.saveCreateCourseSettings();
                          refresh();
                        },
                      ),
                      SizedBox(height: 14),
                      CompactSelectBox(
                        title: "GIỮA CÁC THẺ",
                        value: cardSeparatorType,
                        items: [
                          CompactSelectItem(value: "newline", label: "Dòng mới"),
                          CompactSelectItem(
                            value: "semicolon",
                            label: "Chấm phẩy ;",
                          ),
                          CompactSelectItem(value: "custom", label: "Tùy chỉnh"),
                        ],
                        onChanged: (value) {
                          cardSeparatorType = value;
                          this.saveCreateCourseSettings();
                          refresh();
                        },
                        customController: customCardSepController,
                        customHint: "vd: ###",
                        showCustomInput: cardSeparatorType == "custom",
                        onCustomChanged: (_) {
                          this.saveCreateCourseSettings();
                          refresh();
                        },
                      ),
                      SizedBox(height: 14),
                      this.buildTopicSetting(modalSetState),
                      SizedBox(height: 14),
                      this.buildLanguageSetting(modalSetState),
                      SizedBox(height: 18),
                      BigPopupButton(
                        text: "Xong",
                        icon: Icons.check,
                        color: AppColors.green,
                        onTap: () {
                          this.saveCreateCourseSettings();
                          Navigator.pop(context);
                        },
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
  }

  Widget buildTopicSetting(StateSetter modalSetState) {
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
          SectionTitle("CHỦ ĐỀ HỌC PHẦN"),
          SizedBox(height: 10),
          if (availableTopics.isEmpty)
            Text(
              "Chưa có chủ đề. Khi lưu sẽ tự tạo theo tên học phần.",
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            )
          else
            Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedTopicId,
                  hint: Text(
                    "Chọn chủ đề",
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  isExpanded: true,
                  dropdownColor: AppColors.dropdownFill,
                  iconEnabledColor: AppColors.onIconButton,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  items: availableTopics
                      .map(
                        (topic) => DropdownMenuItem<int>(
                          value: topic.id,
                          child: Text(topic.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    modalSetState(() {
                      selectedTopicId = value;
                    });
                    setState(() {});
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildLanguageSetting(StateSetter modalSetState) {
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
          SectionTitle("NGÔN NGỮ HỌC PHẦN"),
          SizedBox(height: 10),
          Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedLanguage,
                isExpanded: true,
                dropdownColor: AppColors.dropdownFill,
                iconEnabledColor: AppColors.onIconButton,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                items: [
                  DropdownMenuItem(
                    value: "Tiếng Trung Phồn thể (Traditional Chinese)",
                    child: Text("Tiếng Trung Phồn thể"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Trung Giản thể (Simplified Chinese)",
                    child: Text("Tiếng Trung Giản thể"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Anh (English)",
                    child: Text("Tiếng Anh"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Đức (German)",
                    child: Text("Tiếng Đức"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Nhật (Japanese)",
                    child: Text("Tiếng Nhật"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Hàn (Korean)",
                    child: Text("Tiếng Hàn"),
                  ),
                  DropdownMenuItem(
                    value: "Tiếng Việt (Vietnamese)",
                    child: Text("Tiếng Việt"),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  modalSetState(() {
                    selectedLanguage = value;
                  });
                  this.saveCreateCourseSettings();
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Row(
        children: [
          SmallIcon3DButton(
            icon: Icons.arrow_back,
            color: AppColors.red,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Expanded(
            child: LightInput(
              controller: titleController,
              hintText: "Tên học phần...",
              height: 48,
            ),
          ),
          SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.settings,
            color: AppColors.blue,
            onTap: this.openSettingPopup,
          ),
          SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.visibility,
            color: AppColors.yellow,
            onTap: this.updatePreview,
          ),
          SizedBox(width: 8),
          SmallIcon3DButton(
            icon: Icons.save,
            color: AppColors.green,
            onTap: this.saveCourse,
          ),
        ],
      ),
    );
  }

  Widget buildDataInput() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.58,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, 18),
            blurRadius: 26,
          ),
        ],
      ),
      child: TextField(
        controller: dataController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 15,
          height: 1.6,
          fontFamily: "monospace",
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: "Từ 1\tĐịnh nghĩa 1\nTừ 2\tĐịnh nghĩa 2\nTừ 3\tĐịnh nghĩa 3",
          hintStyle: TextStyle(color: AppColors.muted, fontFamily: "monospace"),
        ),
      ),
    );
  }

  Widget buildPreviewTitle() {
    return Row(
      children: [
        SectionTitle("XEM TRƯỚC"),
        SizedBox(width: 8),
        Container(
          width: 26,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  Widget buildPreviewBox() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 230),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: previewItems.isEmpty
          ? Center(
              child: Text(
                "Chưa có dữ liệu xem trước",
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Column(
              children: List.generate(previewItems.length, (index) {
                final item = previewItems[index];

                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border,
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: AppColors.border,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.term,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              item.definition,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}
