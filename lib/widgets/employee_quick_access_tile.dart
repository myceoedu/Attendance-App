import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Centered-portrait shortcut card — icon on top, label below.
/// Designed for a 3-column grid so the whole workspace section fits on-screen.
class EmployeeQuickAccessTile extends StatelessWidget {
  const EmployeeQuickAccessTile({
    super.key,
    required this.label,
    required this.semanticAction,
    required this.icon,
    required this.onTap,
    this.accentColor = AppColors.primary,
    this.subLabel = '',
    this.badgeCount,
  });

  final String label;
  final String subLabel;
  final String semanticAction;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  /// If non-null and positive, a small red badge is drawn on the icon.
  final int? badgeCount;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final bc = badgeCount ?? 0;
    final semanticLabel = bc > 0
        ? '$label, $bc new. $semanticAction'
        : '$label. $semanticAction';

    final iconEnd = Color.lerp(accentColor, Colors.white, 0.25)!;
    final cardBg = Color.alphaBlend(
      accentColor.withValues(alpha: 0.07),
      Colors.white,
    );

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
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            splashColor: accentColor.withValues(alpha: 0.12),
            highlightColor: accentColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.2),
                ),
                // Border lift only — no blur shadow (smooth scroll on web).
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Gradient icon well + badge ─────────────────────
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accentColor, iconEnd],
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        if (bc > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
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
                    const SizedBox(height: 10),
                    // ── Label ─────────────────────────────────────────
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                    ),
                    if (subLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textHint,
                          height: 1.2,
                        ),
                      ),
                    ],
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
