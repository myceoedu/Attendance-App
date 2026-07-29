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
    final element = context
        .getElementForInheritedWidgetOfExactType<EmployeeTabScope>();
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
/// Visited tabs stay mounted in an [IndexedStack] so switching back is instant
/// (no reload spinner). Tabs are created lazily on first visit.
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
  final Set<int> _visited = {0};
  final Map<int, Widget> _pages = {};

  static const _homeKey = ValueKey<String>('employee_shell_home');
  static const _attendanceKey = ValueKey<String>('employee_shell_attendance');
  static const _profileKey = ValueKey<String>('employee_shell_profile');

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const RepaintBoundary(
          child: EmployeeHomeTab(key: _homeKey),
        );
      case 1:
        return const RepaintBoundary(
          child: EmployeeAttendanceTab(key: _attendanceKey),
        );
      default:
        return const RepaintBoundary(
          child: ProfileTab(key: _profileKey),
        );
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
    return EmployeeTabScope(
      goToTab: _goToTab,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.surface,
        body: ColoredBox(
          color: AppColors.surface,
          child: IndexedStack(
            index: _index,
            sizing: StackFit.expand,
            children: List<Widget>.generate(3, (i) {
              if (!_visited.contains(i)) {
                return const SizedBox.shrink();
              }
              return _ensurePage(i);
            }),
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
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onChanged(i),
                      borderRadius: BorderRadius.circular(16),
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
                                colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0D9488,
                                  ).withValues(alpha: 0.55),
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
                  ),
                );
              }

              // Home & Profile tabs
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(12),
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
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
