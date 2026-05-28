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
        bottomNavigationBar: _EmployeeBottomNavBar(
          currentIndex: _index,
          onChanged: _goToTab,
        ),
      ),
    );
  }
}

/// Custom bottom navigation bar — fully hand-drawn to avoid NavigationBar
/// compositing glitches while still matching the brand.
///
/// Layout: [Home] [Clock (elevated)] [Profile]
/// The Clock button floats above the bar with a teal gradient disc so it
/// stands out as the primary action.
class _EmployeeBottomNavBar extends StatelessWidget {
  const _EmployeeBottomNavBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = ['Home', 'Clock', 'Profile'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.punch_clock_outlined,
    Icons.person_outline_rounded,
  ];
  static const _selectedIcons = [
    Icons.dashboard_rounded,
    Icons.punch_clock_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2255),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2255).withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppLayout.navBarHeight - bottomInset,
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = currentIndex == i;
              final isClock = i == 1;

              if (isClock) {
                // Elevated teal Clock button
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2DD4BF),
                                Color(0xFF0D9488),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            selected
                                ? Icons.punch_clock_rounded
                                : Icons.punch_clock_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Clock',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? const Color(0xFF2DD4BF)
                                : Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Home & Profile tabs
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: selected ? 44 : 40,
                        height: selected ? 32 : 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          selected ? _selectedIcons[i] : _icons[i],
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          size: selected ? 23 : 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
