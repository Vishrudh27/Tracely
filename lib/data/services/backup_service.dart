import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

/// Settings → Your Data: writes a backup to a temp file and hands it to the
/// OS share sheet (Android hides the app's own documents directory, so
/// there's no plain "save" without either that or a SAF file picker), and
/// reads one back for import.
class BackupService {
  BackupService._();

  static Future<void> exportJson(AppDatabase db) async {
    final data = await db.exportData();
    await _share('tracely_backup.json', jsonEncode(data));
  }

  static Future<void> exportCsv(AppDatabase db) async {
    final csv = await db.exportCompletionsCsv();
    await _share('tracely_completions.csv', csv);
  }

  static Future<void> _share(String fileName, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/$fileName').writeAsString(contents);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: fileName),
    );
  }

  /// Opens a file picker for a `.json` backup and returns its parsed,
  /// validated contents, ready for [AppDatabase.importData] — or null if
  /// the user cancelled.
  ///
  /// Throws [FormatException] if the file isn't valid JSON or isn't a
  /// Tracely backup, so the caller can show a specific error instead of
  /// silently doing nothing.
  static Future<Map<String, dynamic>?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return null;

    final raw = utf8.decode(await picked.readAsBytes());
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != AppDatabase.backupAppMarker ||
        decoded['tables'] is! Map) {
      throw const FormatException('Not a Tracely backup file.');
    }
    return decoded;
  }
}
