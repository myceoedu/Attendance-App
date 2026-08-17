import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import 'employee_attendance_tab.dart';
import 'employee_home_tab.dart';
import 'profile_tab.dart';

/// Lets descendant widgets (e.g. [EmployeeHomeTab]) switch the bottom-nav tab
/// and know whether their tab is currently visible (pause timers / realtime).
class EmployeeTabScope extends InheritedWidget {
  const EmployeeTabScope({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  /// Home = 0, Clock = 1, Profile = 2
  final int currentIndex;
  final void Function(int index) goToTab;

  static EmployeeTabScope? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<EmployeeTabScope>();
    return element?.widget as EmployeeTabScope?;
  }

  static void goToTabOf(BuildContext context, int index) {
    maybeOf(context)?.goToTab(index);
  }

  /// True when this shell tab is the one on screen.
  static bool isActive(BuildContext context, int tabIndex) =>
      maybeOf(context)?.currentIndex == tabIndex;

  @override
  bool updateShouldNotify(EmployeeTabScope oldWidget) =>
      oldWidget.currentIndex != currentIndex || oldWidget.goToTab != goToTab;
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
      currentIndex: _index,
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
              return TickerMode(
                enabled: i == _index,
                child: _ensurePage(i),
              );
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

/// Clean navy bar: muted Home / Profile, white fingerprint Clock as the focus.
class _EmployeeBottomNavBar extends StatelessWidget {
  const _EmployeeBottomNavBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const Color _navy = Color(0xFF14213D);
  static const Color _muted = Color(0xFF8B93A3);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barH = AppLayout.navBarHeight - bottomInset;

    return ColoredBox(
      color: _navy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _sideTab(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(1),
                    borderRadius: BorderRadius.circular(16),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              color: _navy,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Clock',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _sideTab(
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  selected: currentIndex == 2,
                  onTap: () => onChanged(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _muted, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
