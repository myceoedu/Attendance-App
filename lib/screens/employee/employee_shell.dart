import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import 'employee_attendance_tab.dart';
import 'employee_home_tab.dart';
import 'profile_tab.dart';

/// Lets descendant widgets (e.g. [EmployeeHomeTab]) switch the bottom-nav tab.
class EmployeeTabScope extends InheritedWidget {
  const EmployeeTabScope({
    super.key,
    required this.goToTab,
    required super.child,
  });

  final void Function(int index) goToTab;

  static void goToTabOf(BuildContext context, int index) {
    final element =
        context.getElementForInheritedWidgetOfExactType<EmployeeTabScope>();
    final scope = element?.widget as EmployeeTabScope?;
    scope?.goToTab(index);
  }

  @override
  bool updateShouldNotify(EmployeeTabScope oldWidget) =>
      oldWidget.goToTab != goToTab;
}

/// Employee shell: **one [Scaffold]** owns the bottom bar and is the only scaffold
/// in this route. Tab widgets must **not** nest another [Scaffold] (that layout
/// breaks badly: full-viewport blue / empty body on many devices).
///
/// Only the **active** tab is mounted (see [KeyedSubtree]) so inactive tabs do not
/// keep timers, realtime channels, or heavy subtrees alive — better CPU and memory.
///
/// Bottom navigation is always [NavigationBar] (like [AdminShell]). A custom gradient
/// bar with heavy shadows correlated with a full-viewport blue compositing glitch
/// on some Android emulators and on Chrome; [NavigationBar] avoids that.
class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key});

  /// Home = 0, Clock in / attendance = 1, Profile = 2
  static void switchTab(BuildContext context, int index) {
    EmployeeTabScope.goToTabOf(context, index);
  }

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _index = 0;

  static const _homeKey = ValueKey<String>('employee_shell_home');
  static const _attendanceKey = ValueKey<String>('employee_shell_attendance');
  static const _profileKey = ValueKey<String>('employee_shell_profile');

  late final List<Widget> _pages = [
    RepaintBoundary(child: const EmployeeHomeTab(key: _homeKey)),
    RepaintBoundary(child: const EmployeeAttendanceTab(key: _attendanceKey)),
    RepaintBoundary(child: const ProfileTab(key: _profileKey)),
  ];

  void _goToTab(int raw) {
    final next = raw < 0
        ? 0
        : (raw >= _pages.length ? _pages.length - 1 : raw);
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    return EmployeeTabScope(
      goToTab: _goToTab,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.surface,
        body: ColoredBox(
          color: AppColors.surface,
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: _pages[_index],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.navigationBarBackground,
            border: Border(
              top: BorderSide(color: AppColors.navigationBarTopLine),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, -4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: _EmployeeBottomNavBar(
            currentIndex: _index,
            onChanged: _goToTab,
          ),
        ),
      ),
    );
  }
}

/// [NavigationBar] shared by all platforms — matches [AdminShell] and avoids
/// gradient/shadow compositing issues on Android emulators and Flutter web.
class _EmployeeBottomNavBar extends StatelessWidget {
  const _EmployeeBottomNavBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.navigationBarBackground,
          indicatorColor: AppColors.brandIndicator,
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
        selectedIndex: currentIndex,
        onDestinationSelected: onChanged,
        backgroundColor: AppColors.navigationBarBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandIndicator,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: AppLayout.navBarHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const _EmployeeClockNavIcon(selected: false),
            selectedIcon: const _EmployeeClockNavIcon(selected: true),
            label: 'Clock',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Center tab on brand bar: outlined when idle; selected = white disc + primary icon.
class _EmployeeClockNavIcon extends StatelessWidget {
  const _EmployeeClockNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.onBrand : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.onBrand
              : AppColors.onBrand.withValues(alpha: 0.35),
          width: 1.35,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Icon(
        selected ? Icons.punch_clock_rounded : Icons.punch_clock_outlined,
        color: selected ? AppColors.primaryDark : AppColors.onBrand,
        size: selected ? 26 : 24,
      ),
    );
  }
}
