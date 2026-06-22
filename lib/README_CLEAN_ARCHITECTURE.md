# Clean Architecture mapping

Dự án đã được tách lại theo `core/` và `features/`.

- `core/`: database, constants, errors, network, theme, utils dùng chung toàn app.
- `features/*/data`: nguồn dữ liệu, model mapping, repository implementation.
- `features/*/domain`: entity, repository interface, usecase.
- `features/*/presentation`: UI pages, widgets, state management.

Lưu ý: app gốc đang dùng `part of flutterflashcard_main;`, nên các file UI cũ vẫn được giữ dạng `part` để hạn chế lỗi khi build.
