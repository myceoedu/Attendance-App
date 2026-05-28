import 'package:flutter/material.dart';
import '../../utils/app_route.dart';
import 'package:flutter/services.dart';

import '../../constants/app_theme.dart';
import 'admin_leave_employee_picker_screen.dart';
import 'leave_management_screen.dart';

/// Landing screen after admin taps **Leave** on the home dashboard.
/// Two paths: triage all requests, or pick one employee (balance + their history).
class AdminLeaveHubScreen extends StatelessWidget {
  const AdminLeaveHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppChrome.onBrand,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          systemOverlayStyle: AppChrome.onBrand,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.onBrand,
          title: const Text('Leave'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.adminBrandHeader,
              boxShadow: [
                BoxShadow(
                  color: AppColors.adminHeaderShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Choose how you want to work with leave',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 18),
            _HubPathCard(
              icon: Icons.people_outline_rounded,
              iconGradientColors: const [
                Color(0xFF6366F1),
                Color(0xFF818CF8),
              ],
              title: 'By employee',
              subtitle:
                  'Pick someone from the directory. See their requests and '
                  'annual leave balance in one place.',
              onTap: () {
                Navigator.of(context).push<void>(
                  AppRoute(
                    builder: (_) => const AdminLeaveEmployeePickerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _HubPathCard(
              icon: Icons.dashboard_customize_outlined,
              iconGradientColors: const [
                Color(0xFF0D9488),
                Color(0xFF2DD4BF),
              ],
              title: 'All leave requests',
              subtitle:
                  'Every employee in one inbox — filter by status, type, or '
                  'person. Ideal for approvals and triage.',
              onTap: () {
                Navigator.of(context).push<void>(
                  AppRoute(
                    builder: (_) => const LeaveManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HubPathCard extends StatelessWidget {
  const _HubPathCard({
    required this.icon,
    required this.iconGradientColors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> iconGradientColors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        side: BorderSide(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: iconGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradientColors.last.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint.withValues(alpha: 0.9),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
