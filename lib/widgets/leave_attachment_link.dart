import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../services/supabase_service.dart';

/// Opens a leave supporting document (MC) via a short-lived signed URL.
Future<void> openLeaveAttachment(BuildContext context, String? storagePath) async {
  if (storagePath == null || storagePath.isEmpty) return;
  try {
    final url = await SupabaseService.getLeaveAttachmentSignedUrl(storagePath);
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
          content: Text('Could not load attachment: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

/// Compact row: "View MC / attachment" chip.
class LeaveAttachmentRow extends StatelessWidget {
  final String? attachmentPath;

  const LeaveAttachmentRow({super.key, required this.attachmentPath});

  @override
  Widget build(BuildContext context) {
    if (attachmentPath == null || attachmentPath!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => openLeaveAttachment(context, attachmentPath),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'View supporting document (MC / attachment)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
