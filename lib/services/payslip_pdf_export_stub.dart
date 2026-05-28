import 'dart:typed_data';

/// Fallback (should not be used — real implementation is conditional).
Future<bool> offerPayslipPdf(
  Uint8List bytes,
  String filename,
  String shareSubject,
) async =>
    false;
