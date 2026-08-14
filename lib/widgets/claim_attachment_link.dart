import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/open_signed_url.dart';

Future<void> openClaimAttachment(
  BuildContext context,
  String storagePath,
) async {
  await openSignedStorageUrl(
    context: context,
    fetchUrl: () => SupabaseService.getClaimAttachmentSignedUrl(storagePath),
    loadFailedPrefix: 'Could not load file',
  );
}

IconData iconForClaimFileName(String name) {
  final i = name.lastIndexOf('.');
  final ext =
      i >= 0 && i < name.length - 1 ? name.substring(i + 1).toLowerCase() : '';
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => Icons.image_outlined,
    'zip' => Icons.folder_zip_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'txt' => Icons.article_outlined,
    _ => Icons.attach_file,
  };
}
