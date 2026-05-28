import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import 'admin_home_tab.dart';
import 'employee_list_screen.dart';
import 'attendance_overview_screen.dart';

/// Lets [AdminHomeTab] jump to Attendance or Employees tabs.
class AdminTabScope extends InheritedWidget {
  const AdminTabScope({
    super.key,
    required this.goToTab,
    required super.child,
  });

  final void Function(int index) goToTab;

  static void goToTabOf(BuildContext context, int index) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AdminTabScope>();
    final scope = element?.widget as AdminTabScope?;
    scope?.goToTab(index);
  }

  @override
  bool updateShouldNotify(AdminTabScope oldWidget) =>
      oldWidget.goToTab != goToTab;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  /// Home = 0, Attendance = 1, Employees = 2
  static void switchTab(BuildContext context, int index) {
    AdminTabScope.goToTabOf(context, index);
  }

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    RepaintBoundary(child: const AdminHomeTab()),
    RepaintBoundary(child: const AttendanceOverviewScreen()),
    RepaintBoundary(child: const EmployeeListScreen()),
  ];

  void _goToTab(int raw) {
    final next = raw < 0
        ? 0
        : (raw >= _pages.length ? _pages.length - 1 : raw);
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return AdminTabScope(
      goToTab: _goToTab,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.adminNavBackground,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.adminNavBackground.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, -4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Theme(
            data: base.copyWith(
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: AppColors.adminNavBackground,
                indicatorColor: AppColors.adminNavIndicator,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: AppLayout.navBarHeight,
                shadowColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.onBrand : AppColors.onBrandMuted,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? AppColors.onBrand : AppColors.onBrandFaint,
                    size: 24,
                  );
                }),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goToTab,
              backgroundColor: AppColors.adminNavBackground,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.adminNavIndicator,
              shadowColor: Colors.transparent,
              elevation: 0,
              height: AppLayout.navBarHeight,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.access_time_outlined),
                  selectedIcon: Icon(Icons.access_time_filled),
                  label: 'Attendance',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Employees',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
