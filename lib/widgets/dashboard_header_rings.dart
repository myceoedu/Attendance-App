import 'package:flutter/material.dart';

/// Decorative concentric rings for dashboard brand headers (employee + admin).
///
/// Three outlined circles, low-opacity white stroke, no fill — sits top-right.
class DashboardHeaderRings extends StatelessWidget {
  const DashboardHeaderRings({
    super.key,
    this.size = 220,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _DashboardHeaderRingsPainter(),
      ),
    );
  }
}

class _DashboardHeaderRingsPainter extends CustomPainter {
  const _DashboardHeaderRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.28);
    final radii = <double>[
      size.width * 0.22,
      size.width * 0.34,
      size.width * 0.46,
    ];
    final opacities = <double>[0.08, 0.07, 0.06];

    for (var i = 0; i < radii.length; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacities[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      canvas.drawCircle(center, radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
