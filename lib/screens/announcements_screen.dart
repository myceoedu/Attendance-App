import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_theme.dart';
import '../models/company_announcement.dart';
import '../providers/auth_provider.dart';
import '../services/announcement_badge_service.dart';
import '../services/app_realtime.dart';
import '../services/supabase_service.dart';
import '../widgets/empty_state.dart';

/// Read-only list of **company announcements** (posted by admins).
/// Separate from personal [NotificationsScreen] (leave alerts, etc.).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<CompanyAnnouncement> _items = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;
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
    _channel = AppRealtime.subscribeCompanyAnnouncements(
      channelSuffix: 'inbox',
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
      final data = await SupabaseService.getCompanyAnnouncements();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
        _error = null;
      });
      final uid = context.read<AuthProvider>().user?.id;
      if (uid != null) {
        await AnnouncementBadgeService.markAnnouncementsSeenFromList(uid, data);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load announcements. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Announcements')),
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
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
              subtitle:
                  'Your organisation has not posted any notices. Check back later.',
            )
          : RefreshIndicator(
              onRefresh: () => _load(showSpinner: true),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final a = _items[i];
                  final author = a.authorName?.trim().isNotEmpty == true
                      ? a.authorName!
                      : 'Management';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.campaign_rounded,
                            color: AppColors.accent.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: AppColors.textPrimary,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.body,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Posted by $author · ${dateFmt.format(a.createdAt.toLocal())}',
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
                  );
                },
              ),
            ),
    );
  }
}
