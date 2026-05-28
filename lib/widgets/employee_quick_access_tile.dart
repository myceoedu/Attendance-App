import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_theme.dart';

/// Premium grid shortcut: equal-height cells, centered label, soft icon well.
class EmployeeQuickAccessTile extends StatelessWidget {
  const EmployeeQuickAccessTile({
    super.key,
    required this.label,
    required this.semanticAction,
    required this.icon,
    required this.onTap,
    this.accentColor = AppColors.primary,
    this.badgeCount,
  });

  final String label;
  final String semanticAction;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
  /// If non-null and positive, a small red count is drawn on the icon.
  final int? badgeCount;

  static const double _radius = 18;

  Color get _iconColor => Color.lerp(accentColor, AppColors.textPrimary, 0.2)!;

  @override
  Widget build(BuildContext context) {
    final bc = badgeCount ?? 0;
    final semanticLabel = bc > 0
        ? '$label, $bc new. $semanticAction'
        : '$label. $semanticAction';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 650),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.none,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(_radius),
            splashColor: accentColor.withValues(alpha: 0.09),
            highlightColor: accentColor.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: _iconColor,
                            size: 24,
                          ),
                        ),
                        if (bc > 0)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 17),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                bc > 99 ? '99+' : '$bc',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.quickAccessTileLabel(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
