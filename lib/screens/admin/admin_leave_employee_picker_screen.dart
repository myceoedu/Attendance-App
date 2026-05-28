import 'package:flutter/material.dart';
import '../../utils/app_route.dart';

import '../../constants/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../utils/debouncer.dart';
import 'leave_management_screen.dart';

/// Searchable employee list; opens [LeaveManagementScreen] scoped to selection.
/// Uses [Navigator.pushReplacement] so Back from leave management returns to the hub.
class AdminLeaveEmployeePickerScreen extends StatefulWidget {
  const AdminLeaveEmployeePickerScreen({super.key});

  @override
  State<AdminLeaveEmployeePickerScreen> createState() =>
      _AdminLeaveEmployeePickerScreenState();
}

class _AdminLeaveEmployeePickerScreenState
    extends State<AdminLeaveEmployeePickerScreen> {
  List<AppUser> _employees = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.getAllEmployees();
      if (!mounted) return;
      setState(() {
        _employees = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  List<AppUser> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q);
    }).toList();
  }

  void _onSelect(AppUser employee) {
    Navigator.of(context).pushReplacement(
      AppRoute(
        builder: (_) =>
            LeaveManagementScreen(initialEmployeeId: employee.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Select employee'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    AppFilterBar(
                      searchController: _searchCtrl,
                      onSearchChanged: (_) => _searchDebounce(() {
                        if (mounted) setState(() {});
                      }),
                      searchHint: 'Search name, username, or email',
                      chipOptions: const [],
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? EmptyState(
                              icon: Icons.person_search_rounded,
                              title: _employees.isEmpty
                                  ? 'No employees'
                                  : 'No matches',
                              subtitle: _employees.isEmpty
                                  ? 'No employee accounts were returned.'
                                  : 'Try a different search term.',
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final e = list[i];
                                  final sub = e.email.isNotEmpty
                                      ? e.email
                                      : e.username;
                                  return Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () => _onSelect(e),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor:
                                                  AppColors.indigoLight,
                                              child: Text(
                                                e.name.isNotEmpty
                                                    ? e.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.indigo,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    e.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15,
                                                      color: AppColors
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    sub,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.textHint,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
