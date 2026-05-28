import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../services/supabase_service.dart';

Future<void> openClaimAttachment(
  BuildContext context,
  String storagePath,
) async {
  try {
    final url =
        await SupabaseService.getClaimAttachmentSignedUrl(storagePath);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the file'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load file: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
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
