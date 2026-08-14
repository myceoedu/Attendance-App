import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_theme.dart';
import '../../utils/app_route.dart';
import '../../utils/geofence.dart';
import '../../widgets/work_site_osm_map.dart';

/// Full-screen OpenStreetMap picker — tap to place the workplace pin.
class WorkSiteMapPickerScreen extends StatefulWidget {
  const WorkSiteMapPickerScreen({
    super.key,
    this.initialPin,
    this.radiusMeters = Geofence.defaultRadiusMeters,
  });

  final LatLng? initialPin;
  final int radiusMeters;

  @override
  State<WorkSiteMapPickerScreen> createState() =>
      _WorkSiteMapPickerScreenState();
}

class _WorkSiteMapPickerScreenState extends State<WorkSiteMapPickerScreen> {
  late final MapController _mapController;
  LatLng? _pin;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pin = widget.initialPin;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() => _pin = point);
  }

  Future<void> _useGps() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _toast('Allow location access to use your current location.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = point);
      _mapController.move(point, 17);
      _toast('Marker moved to your current location.');
    } on TimeoutException {
      _toast('Location timed out. Tap the map instead.', error: true);
    } catch (_) {
      _toast('Could not read location. Tap the map to set the office.', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  void _confirm() {
    final pin = _pin;
    if (pin == null) {
      _toast('Tap the map to set the office location first.', error: true);
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.radiusMeters.clamp(
      Geofence.minRadiusMeters,
      Geofence.maxRadiusMeters,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Set office location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Use location'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                _pin == null
                    ? 'Tap the map to set the office location. You can drag and zoom.'
                    : 'Location set. Tap the map to move. Radius $radius m',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
          Expanded(
            child: WorkSiteOsmMap(
              mapController: _mapController,
              pin: _pin,
              radiusMeters: radius,
              onTap: _onTap,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating ? null : _useGps,
                      icon: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed_rounded),
                      label: Text(
                        _locating ? 'Locating…' : 'Current location',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _confirm,
                      child: const Text('Confirm location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the OSM picker and returns the chosen pin (or null if cancelled).
Future<LatLng?> openWorkSiteMapPicker(
  BuildContext context, {
  LatLng? initialPin,
  int radiusMeters = Geofence.defaultRadiusMeters,
}) {
  return pushAppPage<LatLng>(
    context,
    WorkSiteMapPickerScreen(
      initialPin: initialPin,
      radiusMeters: radiusMeters,
    ),
  );
}
