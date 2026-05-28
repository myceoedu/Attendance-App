import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Desktop: native Save dialog. Mobile: return false so caller can use Share.
Future<bool> offerPayslipPdf(
  Uint8List bytes,
  String filename,
  String shareSubject,
) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save payslip',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (path == null) {
      return true;
    }
    var out = path;
    if (!out.toLowerCase().endsWith('.pdf')) {
      out = '$out.pdf';
    }
    await File(out).writeAsBytes(bytes, flush: true);
    return true;
  }
  return false;
}
