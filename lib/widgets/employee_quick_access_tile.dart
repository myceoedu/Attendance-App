import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Centered-portrait shortcut card — pastel icon tile on top, label below.
class EmployeeQuickAccessTile extends StatelessWidget {
  const EmployeeQuickAccessTile({
    super.key,
    required this.label,
    required this.semanticAction,
    required this.icon,
    required this.onTap,
    required this.iconBackground,
    required this.iconColor,
    this.subLabel = '',
    this.badgeCount,
  });

  final String label;
  final String subLabel;
  final String semanticAction;
  final IconData icon;
  final VoidCallback onTap;

  /// Soft pastel fill for the 30×30 icon well.
  final Color iconBackground;

  /// Icon glyph color on the pastel well.
  final Color iconColor;

  /// If non-null and positive, a small red badge is drawn on the icon.
  final int? badgeCount;

  static const double _cardRadius = 16;
  static const double _iconTileSize = 30;
  static const double _iconTileRadius = 8;

  @override
  Widget build(BuildContext context) {
    final bc = badgeCount ?? 0;
    final semanticLabel = bc > 0
        ? '$label, $bc new. $semanticAction'
        : '$label. $semanticAction';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_cardRadius),
          splashColor: iconColor.withValues(alpha: 0.10),
          highlightColor: iconColor.withValues(alpha: 0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(color: const Color(0xFFE4E6EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _iconTileSize,
                        height: _iconTileSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius:
                              BorderRadius.circular(_iconTileRadius),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 16,
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
                              color: AppColors.danger,
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
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
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
                      style: const TextStyle(
                        fontSize: 9,
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
    );
  }
}
