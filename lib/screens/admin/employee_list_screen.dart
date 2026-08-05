import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import '../../utils/app_route.dart';
import '../../models/app_user.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../utils/debouncer.dart';
import 'admin_employee_edit_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<AppUser> _employees = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final data = await SupabaseService.getAllEmployees(
        forceRefresh: forceRefresh,
      );
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

  List<AppUser> get _filteredEmployees {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _employees;
    return _employees.where((employee) {
      return employee.name.toLowerCase().contains(query) ||
          employee.username.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openEditor(AppUser e) async {
    final ok = await pushAppPage<bool>(
      context,
      AdminEmployeeEditScreen(employee: e),
    );
    if (ok == true && mounted) {
      setState(() => _loading = true);
      await _load(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _filteredEmployees;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_employees.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            )
          : _employees.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No employees found',
            )
          : Column(
              children: [
                AppFilterBar(
                  searchController: _searchCtrl,
                  onSearchChanged: (_) => _searchDebounce(() {
                    if (mounted) setState(() {});
                  }),
                  searchHint: 'Search by name, username, or email',
                ),
                Expanded(
                  child: filteredEmployees.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No employees match your search',
                          subtitle: 'Try another name, username, or email',
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            setState(() => _loading = true);
                            await _load(forceRefresh: true);
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            addAutomaticKeepAlives: false,
                            cacheExtent: 400,
                            itemCount: filteredEmployees.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final e = filteredEmployees[i];
                              final name = e.name.isNotEmpty
                                  ? e.name
                                  : (e.username.isNotEmpty
                                        ? e.username
                                        : 'Unnamed');
                              final initial = name[0].toUpperCase();
                              return KeyedSubtree(
                                key: ValueKey<String>(e.id),
                                child: InkWell(
                                  onTap: () => _openEditor(e),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.divider,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor:
                                              AppColors.primaryLight,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                e.email,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textHint.withValues(
                                            alpha: 0.85,
                                          ),
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
