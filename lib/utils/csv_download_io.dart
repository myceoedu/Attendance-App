import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';

/// Opens a native Save / Downloads dialog and writes the CSV (no Share sheet).
///
/// Returns `false` if the user cancels.
Future<bool> offerCsvDownload(String csvContent, String filename) async {
  final safeName = filename.toLowerCase().endsWith('.csv')
      ? filename
      : '$filename.csv';
  final bytes = utf8.encode(csvContent);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Download CSV',
    fileName: safeName,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: bytes,
  );

  // User cancelled.
  if (path == null || path.isEmpty) return false;

  // Mobile pickers already persist [bytes]; writing a content URI can fail.
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }

  var out = path;
  if (!out.toLowerCase().endsWith('.csv')) {
    out = '$out.csv';
  }
  await File(out).writeAsBytes(bytes, flush: true);
  return true;
}
