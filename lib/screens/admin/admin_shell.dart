import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import 'admin_home_tab.dart';
import 'employee_list_screen.dart';
import 'attendance_overview_screen.dart';

/// Lets [AdminHomeTab] jump to Attendance or Employees tabs and pause work
/// when a tab is not visible.
class AdminTabScope extends InheritedWidget {
  const AdminTabScope({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  /// Home = 0, Attendance = 1, Employees = 2
  final int currentIndex;
  final void Function(int index) goToTab;

  static AdminTabScope? maybeOf(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AdminTabScope>();
    return element?.widget as AdminTabScope?;
  }

  static void goToTabOf(BuildContext context, int index) {
    maybeOf(context)?.goToTab(index);
  }

  static bool isActive(BuildContext context, int tabIndex) =>
      maybeOf(context)?.currentIndex == tabIndex;

  @override
  bool updateShouldNotify(AdminTabScope oldWidget) =>
      oldWidget.currentIndex != currentIndex || oldWidget.goToTab != goToTab;
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
  final Set<int> _visited = {0};
  final Map<int, Widget> _pages = {};

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const RepaintBoundary(child: AdminHomeTab());
      case 1:
        return const RepaintBoundary(child: AttendanceOverviewScreen());
      default:
        return const RepaintBoundary(child: EmployeeListScreen());
    }
  }

  Widget _ensurePage(int i) => _pages.putIfAbsent(i, () => _pageFor(i));

  void _goToTab(int raw) {
    final next = raw < 0 ? 0 : (raw > 2 ? 2 : raw);
    if (next == _index) return;
    setState(() {
      _visited.add(next);
      _index = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return AdminTabScope(
      currentIndex: _index,
      goToTab: _goToTab,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: IndexedStack(
          index: _index,
          sizing: StackFit.expand,
          children: List<Widget>.generate(3, (i) {
            if (!_visited.contains(i)) {
              return const SizedBox.shrink();
            }
            return TickerMode(
              enabled: i == _index,
              child: _ensurePage(i),
            );
          }),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.adminNavBackground,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.adminNavBackground.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
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
                    color: selected
                        ? AppColors.onBrand
                        : AppColors.onBrandMuted,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected
                        ? AppColors.onBrand
                        : AppColors.onBrandFaint,
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
