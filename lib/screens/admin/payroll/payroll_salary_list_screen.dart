import 'package:flutter/material.dart';
import '../../../utils/app_route.dart';

import '../../../constants/app_theme.dart';
import '../../../models/app_user.dart';
import '../../../models/payroll_salary_setting.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/employment_status.dart';
import 'payroll_salary_edit_screen.dart';

class PayrollSalaryListScreen extends StatefulWidget {
  const PayrollSalaryListScreen({super.key});

  @override
  State<PayrollSalaryListScreen> createState() => _PayrollSalaryListScreenState();
}

class _PayrollSalaryListScreenState extends State<PayrollSalaryListScreen> {
  bool _loading = true;
  List<AppUser> _staff = [];
  Map<String, PayrollSalarySetting> _byUser = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await Future.wait<dynamic>([
        SupabaseService.getAllEmployees(),
        SupabaseService.getPayrollSalarySettings(),
      ]);
      final emps = result[0] as List<AppUser>;
      final salaries = result[1] as List<PayrollSalarySetting>;
      if (!mounted) return;
      setState(() {
        _staff = emps.where((e) => e.role == 'employee').toList()
          ..sort(
            (a, b) => (a.name.isNotEmpty ? a.name : a.username)
                .toLowerCase()
                .compareTo(
                  (b.name.isNotEmpty ? b.name : b.username).toLowerCase(),
                ),
          );
        _byUser = {for (final s in salaries) s.userId: s};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Employee salaries'),
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                cacheExtent: 700,
                itemCount: _staff.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = _staff[i];
                  final s = _byUser[u.id];
                  final extra = s?.totalMonthlyAddOns ?? 0.0;
                  final extraBit = s != null && extra > 0
                      ? ' + add-ons ${extra.toStringAsFixed(0)}'
                      : '';
                  final displayName =
                      u.name.isNotEmpty ? u.name : u.username;
                  final subtitle = s != null
                      ? '${EmploymentStatus.label(s.employmentStatus)} · RM ${s.basicSalary.toStringAsFixed(0)}$extraBit · ${s.payrollStatus}'
                      : 'Not configured. Tap to set up';
                  final initials = displayName.trim().isEmpty
                      ? '?'
                      : displayName.trim().substring(0, 1).toUpperCase();
                  return RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: s == null
                              ? AppColors.surface
                              : AppColors.primaryLight,
                          foregroundColor: s == null
                              ? AppColors.textSecondary
                              : AppColors.primaryDark,
                          child: Text(
                            initials,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await pushAppPage(
                            context,
                            PayrollSalaryEditScreen(
                              user: u,
                              existing: s,
                            ),
                          );
                          if (mounted) _load();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
