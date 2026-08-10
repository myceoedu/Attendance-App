import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../constants/app_theme.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../services/app_realtime.dart';
import '../services/supabase_service.dart';
import '../widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;
  RealtimeSubscription? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRealtime());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    AppRealtime.disposeChannel(_channel);
    super.dispose();
  }

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    _channel = AppRealtime.subscribeMyNotifications(
      userId: uid,
      onReload: () {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () {
          if (mounted) _load(showSpinner: false);
        });
      },
    );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final data = await SupabaseService.getMyNotifications(uid);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load notifications. Check your connection and try again.';
      });
    }
  }

  Future<void> _markAllRead() async {
    final uid = context.read<AuthProvider>().user!.id;
    await SupabaseService.markAllNotificationsRead(uid);
    if (!mounted) return;
    _load(showSpinner: false);
  }

  Future<void> _openItem(AppNotification item) async {
    if (!item.isRead) {
      await SupabaseService.markNotificationRead(item.id);
      if (!mounted) return;
      _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !item.isRead).length;
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              subtitle: 'Updates about leave actions will appear here',
            )
          : RefreshIndicator(
              onRefresh: () => _load(showSpinner: true),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return InkWell(
                    onTap: () => _openItem(item),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isRead
                              ? AppColors.divider
                              : AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? AppColors.surfaceAlt
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.type == 'leave_status'
                                  ? Icons.event_available
                                  : Icons.notifications_active_outlined,
                              color: item.isRead
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dateFmt.format(item.createdAt.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
