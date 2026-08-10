import 'dart:async';
import '../utils/app_route.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/notifications_screen.dart';
import '../services/app_realtime.dart';
import '../services/supabase_service.dart';

class NotificationBellButton extends StatefulWidget {
  final Color iconColor;

  const NotificationBellButton({
    super.key,
    required this.iconColor,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _count = 0;
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
          if (mounted) _load();
        });
      },
    );
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    final count = await SupabaseService.getUnreadNotificationCount(uid);
    if (!mounted || count == _count) return;
    setState(() => _count = count);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            await pushAppPage(context, const NotificationsScreen());
            if (mounted) _load();
          },
          icon: Icon(Icons.notifications_none, color: widget.iconColor),
          tooltip: 'Notifications',
        ),
        if (_count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
