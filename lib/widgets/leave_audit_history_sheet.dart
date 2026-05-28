import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../models/leave_audit_log.dart';
import '../services/supabase_service.dart';

Future<void> showLeaveAuditHistorySheet(
  BuildContext context, {
  required String leaveRequestId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _LeaveAuditHistorySheet(leaveRequestId: leaveRequestId),
  );
}

class _LeaveAuditHistorySheet extends StatefulWidget {
  final String leaveRequestId;

  const _LeaveAuditHistorySheet({required this.leaveRequestId});

  @override
  State<_LeaveAuditHistorySheet> createState() => _LeaveAuditHistorySheetState();
}

class _LeaveAuditHistorySheetState extends State<_LeaveAuditHistorySheet> {
  List<LeaveAuditLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getLeaveAuditLogs(widget.leaveRequestId);
      if (!mounted) return;
      setState(() {
        _logs = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leave History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Track who changed this request and when.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No history available yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final log = _logs[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            log.action.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          dateFmt.format(log.createdAt.toLocal()),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      log.actorName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (log.fromStatus != null ||
                                        log.toStatus != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${log.fromStatus ?? '-'} -> ${log.toStatus ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    if (log.comment != null &&
                                        log.comment!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        log.comment!,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
