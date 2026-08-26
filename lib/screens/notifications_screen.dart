import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _attachRealtime(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    AppRealtime.disposeChannel(_channel);

    super.dispose();
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _attachRealtime() {
    final uid = context.read<AuthProvider>().user?.id;

    if (uid == null) return;

    _channel = AppRealtime.subscribeMyNotifications(
      userId: uid,
      onReload: () {
        _debounce?.cancel();

        _debounce = Timer(
          const Duration(milliseconds: 350),
          () {
            if (mounted) {
              _load(showSpinner: false);
            }
          },
        );
      },
    );
  }

  // ============================================================
  // LOAD NOTIFICATIONS
  // ============================================================

  Future<void> _load({
    bool showSpinner = true,
  }) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }

    try {
      final uid = context.read<AuthProvider>().user!.id;

      final data =
          await SupabaseService.getMyNotifications(uid);

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

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> _markAllRead() async {
    final uid = context.read<AuthProvider>().user!.id;

    await SupabaseService.markAllNotificationsRead(uid);

    if (!mounted) return;

    await _load(showSpinner: false);
  }

  // ============================================================
  // CLICK NOTIFICATION
  // ============================================================

  Future<void> _openItem(
    AppNotification item,
  ) async {
    // Mark notification as read first
    if (!item.isRead) {
      await SupabaseService.markNotificationRead(
        item.id,
      );

      if (!mounted) return;

      await _load(
        showSpinner: false,
      );

      if (!mounted) return;
    }

    // Announcement -> show full announcement
    if (item.type == 'announcement') {
      await _showAnnouncementDialog(item);
    }
  }

  // ============================================================
  // FULL ANNOUNCEMENT POPUP
  // ============================================================

  Future<void> _showAnnouncementDialog(
    AppNotification item,
  ) async {
    final dateFmt =
        DateFormat('d MMM yyyy, h:mm a');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size =
            MediaQuery.of(dialogContext).size;

        final dialogWidth =
            size.width > 760
                ? 760.0
                : size.width - 32;

        final dialogHeight =
            size.height > 760
                ? 650.0
                : size.height * 0.82;

        return Dialog(
          backgroundColor: Colors.white,

          insetPadding:
              const EdgeInsets.all(16),

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),

          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                // =================================================
                // HEADER
                // =================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    24,
                    22,
                    16,
                    18,
                  ),

                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      // Announcement icon
                      Container(
                        width: 44,
                        height: 44,

                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.violetLight,

                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),

                        child: const Icon(
                          Icons.campaign_rounded,
                          color:
                              AppColors.violet,
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Announcement',

                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.violet,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            // Announcement title
                            Text(
                              item.title,

                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            // Announcement date
                            Text(
                              dateFmt.format(
                                item.createdAt
                                    .toLocal(),
                              ),

                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color:
                                    AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Close X
                      IconButton(
                        tooltip: 'Close',

                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },

                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                // =================================================
                // FULL ANNOUNCEMENT CONTENT
                // =================================================

                Expanded(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),

                    child:
                        SelectableText(
                      item.body,

                      style:
                          const TextStyle(
                        fontSize: 14,
                        color:
                            AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                // =================================================
                // CLOSE BUTTON
                // =================================================

                Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),

                  child: Align(
                    alignment:
                        Alignment.centerRight,

                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop();
                      },

                      child:
                          const Text(
                        'Close',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // NOTIFICATION ICON
  // ============================================================

  IconData _iconFor(
    AppNotification item,
  ) {
    switch (item.type) {
      // Announcement
      case 'announcement':
        return Icons.campaign_rounded;

      // Leave approved / rejected
      case 'leave_status':
        return Icons.event_available;

      // Other notification
      default:
        return Icons.notifications_active_outlined;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unread =
        _items
            .where(
              (item) => !item.isRead,
            )
            .length;

    final dateFmt =
        DateFormat(
      'd MMM yyyy, h:mm a',
    );

    return Scaffold(
      backgroundColor:
          AppColors.surface,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title:
            const Text(
          'Notifications',
        ),

        actions: [
          if (unread > 0)
            TextButton(
              onPressed:
                  _markAllRead,

              child:
                  const Text(
                'Mark all read',
              ),
            ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loading

          // Loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          // Error
          : _error != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),

                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        Text(
                          _error!,
                          textAlign:
                              TextAlign.center,
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        FilledButton(
                          onPressed:
                              _load,

                          child:
                              const Text(
                            'Retry',
                          ),
                        ),
                      ],
                    ),
                  ),
                )

              // No notification
              : _items.isEmpty
                  ? const EmptyState(
                      icon:
                          Icons.notifications_none,

                      title:
                          'No notifications yet',

                      subtitle:
                          'Leave updates and announcements will appear here',
                    )

                  // Notification list
                  : RefreshIndicator(
                      onRefresh: () =>
                          _load(
                        showSpinner: true,
                      ),

                      child:
                          ListView.separated(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),

                        itemCount:
                            _items.length,

                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 10,
                        ),

                        itemBuilder:
                            (_, i) {
                          final item =
                              _items[i];

                          final isAnnouncement =
                              item.type ==
                                  'announcement';

                          return InkWell(
                            onTap: () =>
                                _openItem(
                              item,
                            ),

                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),

                            child:
                                Container(
                              padding:
                                  const EdgeInsets
                                      .all(
                                16,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.white,

                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),

                                border:
                                    Border.all(
                                  color: item
                                          .isRead
                                      ? AppColors
                                          .divider
                                      : AppColors
                                          .primary
                                          .withValues(
                                            alpha:
                                                0.35,
                                          ),
                                ),
                              ),

                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [
                                  // =================================================
                                  // ICON
                                  // =================================================

                                  Container(
                                    width: 42,
                                    height: 42,

                                    decoration:
                                        BoxDecoration(
                                      color: item
                                              .isRead
                                          ? AppColors
                                              .surfaceAlt
                                          : AppColors
                                              .primaryLight,

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),

                                    child:
                                        Icon(
                                      _iconFor(
                                        item,
                                      ),

                                      color: item
                                              .isRead
                                          ? AppColors
                                              .textSecondary
                                          : AppColors
                                              .primary,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 12,
                                  ),

                                  // =================================================
                                  // CONTENT
                                  // =================================================

                                  Expanded(
                                    child:
                                        Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [
                                        // =================================================
                                        // TITLE
                                        // =================================================

                                        Row(
                                          children: [
                                            Expanded(
                                              child:
                                                  Text(
                                                item.title,

                                                maxLines:
                                                    2,

                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,

                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,

                                                  color:
                                                      AppColors
                                                          .textPrimary,
                                                ),
                                              ),
                                            ),

                                            // Unread dot
                                            if (!item
                                                .isRead) ...[
                                              const SizedBox(
                                                width:
                                                    8,
                                              ),

                                              Container(
                                                width:
                                                    9,
                                                height:
                                                    9,

                                                decoration:
                                                    const BoxDecoration(
                                                  color:
                                                      AppColors
                                                          .primary,

                                                  shape:
                                                      BoxShape
                                                          .circle,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        const SizedBox(
                                          height: 4,
                                        ),

                                        // =================================================
                                        // SHORT PREVIEW ONLY
                                        // =================================================

                                        Text(
                                          item.body,

                                          // Announcement only show first 2 lines
                                          maxLines:
                                              isAnnouncement
                                                  ? 2
                                                  : 3,

                                          overflow:
                                              TextOverflow
                                                  .ellipsis,

                                          style:
                                              const TextStyle(
                                            fontSize:
                                                13,

                                            color:
                                                AppColors
                                                    .textSecondary,

                                            height:
                                                1.35,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        // =================================================
                                        // DATE + VIEW ANNOUNCEMENT
                                        // =================================================

                                        Row(
                                          children: [
                                            Text(
                                              dateFmt
                                                  .format(
                                                item.createdAt
                                                    .toLocal(),
                                              ),

                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    11.5,

                                                color:
                                                    AppColors
                                                        .textHint,
                                              ),
                                            ),

                                            if (isAnnouncement) ...[
                                              const Spacer(),

                                              const Text(
                                                'View announcement',

                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      11.5,

                                                  fontWeight:
                                                      FontWeight
                                                          .w700,

                                                  color:
                                                      AppColors
                                                          .primary,
                                                ),
                                              ),

                                              const SizedBox(
                                                width:
                                                    2,
                                              ),

                                              const Icon(
                                                Icons
                                                    .chevron_right_rounded,

                                                size:
                                                    18,

                                                color:
                                                    AppColors
                                                        .primary,
                                              ),
                                            ],
                                          ],
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