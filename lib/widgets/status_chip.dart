import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const StatusChip(label: 'Completed', color: AppColors.completed);
      case 'in_progress':
        return const StatusChip(label: 'In Progress', color: AppColors.inProgress);
      case 'approved':
        return const StatusChip(label: 'Approved', color: AppColors.success);
      case 'pending':
        return const StatusChip(label: 'Pending', color: AppColors.pending);
      case 'rejected':
        return const StatusChip(label: 'Rejected', color: AppColors.rejected);
      default:
        final clean = status
            .replaceAll('_', ' ')
            .trim();
        return StatusChip(label: clean, color: AppColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
