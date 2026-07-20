library flutterflashcard_main;

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:archive/archive_io.dart' hide Duration;
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as dt_picker;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/database/app_database.dart';
import 'core/network/supabase_config.dart';
import 'core/network/supabase_sync_service.dart';
import 'core/network/server_log_service.dart';
import 'core/notifications/vocabulary_reminder_service.dart';

part 'core/theme/app_theme_and_settings_part.dart';
part 'core/utils/app_helpers_part_01.dart';
part 'features/app/presentation/pages/app_shell_part.dart';
part 'features/courses/data/datasources/builtin_vocabulary_importer_part.dart';
part 'features/courses/presentation/pages/create_course_page_state_core.dart';
part 'features/courses/presentation/pages/create_course_page_state_part_01.dart';
part 'features/courses/presentation/pages/create_course_page_state_part_02.dart';
part 'features/courses/presentation/pages/create_course_import_part.dart';
part 'features/flashcards/domain/entities/flashcard_entities_part.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_core.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_01.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_01_split_02.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_02.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_03.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_04.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_05.dart';
part 'features/flashcards/presentation/pages/flash_cards_page_state_part_06.dart';
part 'features/home/presentation/pages/home_page_state_core.dart';
part 'features/home/presentation/pages/home_page_state_part_01.dart';
part 'features/home/presentation/pages/home_page_state_part_02.dart';
part 'features/home/presentation/pages/home_page_state_part_02_split_02.dart';
part 'features/home/presentation/pages/home_page_state_part_03.dart';
part 'features/home/presentation/pages/vocabulary_reminder_dialog.dart';
part 'features/home/presentation/widgets/home_page_state_drawer.dart';
part 'features/pronunciation/presentation/widgets/pronunciation_overlay_state_core.dart';
part 'features/pronunciation/presentation/widgets/pronunciation_overlay_state_part_01.dart';
part 'features/pronunciation/presentation/widgets/pronunciation_overlay_state_part_02.dart';
part 'features/review/domain/entities/review_match_pair_models.dart';
part 'features/review/presentation/pages/deep_learn_page_state_core.dart';
part 'features/review/presentation/pages/deep_learn_page_state_ui.dart';
part 'features/review/presentation/pages/review_practice_page_state_core.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_01.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_01_split_02.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_02.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_03.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_04.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_05.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_06.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_07.dart';
part 'features/review/presentation/pages/review_practice_page_state_part_08.dart';
part 'features/review/presentation/widgets/review_matching_pairs.dart';
part 'features/settings/presentation/pages/settings_page_state_core.dart';
part 'features/settings/presentation/pages/settings_page_state_part_01.dart';
part 'features/settings/presentation/pages/settings_page_state_part_02.dart';
part 'features/settings/presentation/pages/settings_page_state_part_03_auth.dart';
part 'features/shared/presentation/widgets/shared_widgets_part.dart';
part 'features/statistics/domain/entities/statistics_entities_part.dart';
part 'features/statistics/presentation/pages/statistics_page_state_core.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_01.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_02.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_03.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_04.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_05.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_06.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_06_split_02.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_06_split_03.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_06_split_04.dart';
part 'features/statistics/presentation/pages/statistics_page_state_part_07.dart';
part 'features/statistics/presentation/widgets/statistics_due_review_part_01.dart';
part 'features/statistics/presentation/widgets/statistics_due_review_part_02.dart';
part 'features/writing/presentation/pages/writing_practice_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase
  await SupabaseConfig.initialize();
  await VocabularyReminderService.instance.initialize();
  await VocabularyReminderService.instance.refreshEnabledSchedule();

  runApp(MyApp());
}

Duration getDuration({
  int days = 0,
  int hours = 0,
  int minutes = 0,
  int seconds = 0,
  int milliseconds = 0,
  int microseconds = 0,
}) {
  return Duration(
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
    microseconds: microseconds,
  );
}
