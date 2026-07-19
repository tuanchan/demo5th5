import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// File logger used only by Windows test builds.
/// Never pass request bodies, tokens, API keys or passwords to this logger.
class ServerLogService {
  ServerLogService._();

  static const int _maxBytes = 2 * 1024 * 1024;
  static Future<void> _writeTail = Future<void>.value();

  static bool get isAvailable => !kIsWeb && Platform.isWindows;

  static Future<File?> _file() async {
    if (!isAvailable) return null;
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}log.txt');
  }

  static Future<String?> get path async => (await _file())?.path;

  static Future<void> write(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!isAvailable) return Future<void>.value();
    final operation = _writeTail.then((_) async {
      try {
        final file = await _file();
        if (file == null) return;
        if (await file.exists() && await file.length() >= _maxBytes) {
          await file.writeAsString('', flush: true);
        }
        final suffix = details.entries
            .map((entry) => '${entry.key}=${entry.value ?? '-'}')
            .join(' ');
        await file.writeAsString(
          '[${DateTime.now().toIso8601String()}] $event'
          '${suffix.isEmpty ? '' : ' | $suffix'}\r\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (error) {
        debugPrint('SERVER LOG ERROR: $error');
      }
    });
    _writeTail = operation.catchError((_) {});
    return operation;
  }

  static Future<String> read() async {
    await _writeTail;
    final file = await _file();
    if (file == null || !await file.exists()) return '';
    return file.readAsString();
  }

  static Future<void> clear() async {
    await _writeTail;
    final file = await _file();
    if (file != null) await file.writeAsString('', flush: true);
  }
}
