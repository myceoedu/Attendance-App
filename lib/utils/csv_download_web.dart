// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser CSV download (no Share sheet).
Future<bool> offerCsvDownload(String csvContent, String filename) async {
  final bytes = Uint8List.fromList(utf8.encode(csvContent));
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final safeName = filename.toLowerCase().endsWith('.csv')
      ? filename
      : '$filename.csv';
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
