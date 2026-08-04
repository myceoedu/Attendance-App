import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_theme.dart';

/// Default map centre when no workplace pin exists yet (Kuala Lumpur).
const LatLng kDefaultMapCenter = LatLng(3.1390, 101.6869);

/// Shared OpenStreetMap tile + pin + optional radius circle.
///
/// Keep this widget focused: parent owns [pin]/[radiusMeters] and should avoid
/// rebuilding the map on unrelated form field keystrokes.
class WorkSiteOsmMap extends StatelessWidget {
  const WorkSiteOsmMap({
    super.key,
    required this.pin,
    required this.radiusMeters,
    this.mapController,
    this.initialZoom = 16,
    this.interactive = true,
    this.onTap,
  });

  final LatLng? pin;
  final int radiusMeters;
  final MapController? mapController;
  final double initialZoom;
  final bool interactive;
  final TapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final center = pin ?? kDefaultMapCenter;
    final zoom = pin == null ? 12.0 : initialZoom;
    final radius = radiusMeters.clamp(20, 5000).toDouble();

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 19,
        onTap: onTap,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.attendance_app',
          maxZoom: 19,
          // Keep memory bounded on web / low-end phones.
          keepBuffer: 2,
          panBuffer: 1,
        ),
        if (pin != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: pin!,
                radius: radius,
                useRadiusInMeter: true,
                color: AppColors.teal.withValues(alpha: 0.18),
                borderStrokeWidth: 2,
                borderColor: AppColors.teal.withValues(alpha: 0.85),
              ),
            ],
          ),
        if (pin != null)
          MarkerLayer(
            markers: [
              Marker(
                point: pin!,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFE11D48),
                  size: 40,
                ),
              ),
            ],
          ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap'),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }
}
