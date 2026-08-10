import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_theme.dart';
import '../../models/work_site.dart';
import '../../services/supabase_service.dart';
import '../../utils/geofence.dart';
import '../../widgets/work_site_osm_map.dart';
import 'work_site_map_picker_screen.dart';

/// Admin configures the single workplace used for clock-in geofencing.
class AdminWorkSiteScreen extends StatefulWidget {
  const AdminWorkSiteScreen({super.key});

  @override
  State<AdminWorkSiteScreen> createState() => _AdminWorkSiteScreenState();
}

class _AdminWorkSiteScreenState extends State<AdminWorkSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Workplace');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(
    text: '${Geofence.defaultRadiusMeters}',
  );

  final _previewMapController = MapController();
  Timer? _coordDebounce;
  Timer? _radiusDebounce;

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _isActive = false;
  WorkSite? _saved;
  String? _loadError;

  /// Map pin / circle — updated deliberately (not on every keystroke).
  LatLng? _pin;
  int _previewRadius = Geofence.defaultRadiusMeters;

  @override
  void initState() {
    super.initState();
    _latCtrl.addListener(_onCoordFieldsChanged);
    _lngCtrl.addListener(_onCoordFieldsChanged);
    _radiusCtrl.addListener(_onRadiusFieldChanged);
    _load();
  }

  @override
  void dispose() {
    _coordDebounce?.cancel();
    _radiusDebounce?.cancel();
    _latCtrl.removeListener(_onCoordFieldsChanged);
    _lngCtrl.removeListener(_onCoordFieldsChanged);
    _radiusCtrl.removeListener(_onRadiusFieldChanged);
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _previewMapController.dispose();
    super.dispose();
  }

  void _onCoordFieldsChanged() {
    _coordDebounce?.cancel();
    _coordDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      if (lat == null || lng == null) return;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
      final next = LatLng(lat, lng);
      if (_pin != null &&
          (_pin!.latitude - next.latitude).abs() < 1e-7 &&
          (_pin!.longitude - next.longitude).abs() < 1e-7) {
        return;
      }
      setState(() => _pin = next);
      _movePreview(next);
    });
  }

  void _onRadiusFieldChanged() {
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final n = int.tryParse(_radiusCtrl.text.trim());
      if (n == null) return;
      final clamped = n.clamp(
        Geofence.minRadiusMeters,
        Geofence.maxRadiusMeters,
      );
      if (clamped == _previewRadius) return;
      setState(() => _previewRadius = clamped);
    });
  }

  void _applyPin(LatLng point, {bool moveCamera = true}) {
    setState(() {
      _pin = point;
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
    });
    if (moveCamera) _movePreview(point);
  }

  void _movePreview(LatLng point) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _previewMapController.move(point, 16);
      } catch (_) {
        // Map may not be ready yet on first frame.
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final site = await SupabaseService.getWorkSite(forceRefresh: true);
      if (!mounted) return;
      if (site != null) {
        _saved = site;
        _nameCtrl.text = site.name;
        _latCtrl.text = site.latitude.toStringAsFixed(6);
        _lngCtrl.text = site.longitude.toStringAsFixed(6);
        _radiusCtrl.text = '${site.radiusMeters}';
        _isActive = site.isActive;
        _pin = LatLng(site.latitude, site.longitude);
        _previewRadius = site.radiusMeters.clamp(
          Geofence.minRadiusMeters,
          Geofence.maxRadiusMeters,
        );
      }
      setState(() => _loading = false);
      if (_pin != null) _movePreview(_pin!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Could not load workplace settings. Run the work_site SQL migration if this is a new project.';
      });
    }
  }

  Future<void> _openMapPicker() async {
    if (_saving) return;
    final radius = int.tryParse(_radiusCtrl.text.trim()) ?? _previewRadius;
    final picked = await openWorkSiteMapPicker(
      context,
      initialPin: _pin,
      radiusMeters: radius,
    );
    if (!mounted || picked == null) return;
    _applyPin(picked);
    _snack('Location updated from the map. Tap Save to apply.');
  }

  Future<void> _useMyLocation() async {
    if (_locating || _saving) return;
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Allow location access to set the office location.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      _applyPin(LatLng(pos.latitude, pos.longitude));
      _snack('Current location captured. Tap Save to apply.');
    } on TimeoutException {
      _snack('Location timed out. Try Open on map instead.', error: true);
    } catch (_) {
      _snack('Could not read location. Use Open on map instead.', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final radius = int.tryParse(_radiusCtrl.text.trim());
    if (lat == null || lng == null || radius == null) return;

    setState(() => _saving = true);
    try {
      final site = await SupabaseService.saveWorkSite(
        name: _nameCtrl.text,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        isActive: _isActive,
      );
      if (!mounted) return;
      setState(() {
        _saved = site;
        _saving = false;
        _pin = LatLng(site.latitude, site.longitude);
        _previewRadius = site.radiusMeters;
      });
      _snack(
        _isActive
            ? 'Office location saved. Location check for clock-in is enabled.'
            : 'Office location saved. Location check is disabled.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        _snack('Only administrators can save the office location.', error: true);
      } else if (msg.contains('work_site') || msg.contains('pgrst205')) {
        _snack(
          'Location settings are not available yet. Ask your developer to run the work site migration.',
          error: true,
        );
      } else {
        _snack('Could not save. Check the details and try again.', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Office location')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorBody(message: _loadError!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoCard(saved: _saved, isActive: _isActive),
                        const SizedBox(height: 16),
                        _MapPreviewCard(
                          pin: _pin,
                          radiusMeters: _previewRadius,
                          mapController: _previewMapController,
                          onOpenPicker: _saving ? null : _openMapPicker,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _saving ? null : _openMapPicker,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Open on map'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed:
                              (_locating || _saving) ? null : _useMyLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.gps_fixed_rounded),
                          label: Text(
                            _locating
                                ? 'Getting location…'
                                : 'Use current location',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Office name',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return 'Enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.\-]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  prefixIcon:
                                      Icon(Icons.my_location_outlined),
                                ),
                                validator: (v) {
                                  final n = double.tryParse((v ?? '').trim());
                                  if (n == null || n < -90 || n > 90) {
                                    return 'Invalid lat';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lngCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.\-]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                ),
                                validator: (v) {
                                  final n = double.tryParse((v ?? '').trim());
                                  if (n == null || n < -180 || n > 180) {
                                    return 'Invalid lng';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _radiusCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Allowed radius (metres)',
                            helperText:
                                'Employees may clock in within this distance (20–5000 m).',
                            prefixIcon: Icon(Icons.radar_outlined),
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null ||
                                n < Geofence.minRadiusMeters ||
                                n > Geofence.maxRadiusMeters) {
                              return 'Enter ${Geofence.minRadiusMeters}–${Geofence.maxRadiusMeters}';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Require location for clock-in',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Employees must be inside the radius to clock in.'
                                : 'Location check is off. Clock-in is allowed from anywhere.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: _isActive,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save location'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({
    required this.pin,
    required this.radiusMeters,
    required this.mapController,
    required this.onOpenPicker,
  });

  final LatLng? pin;
  final int radiusMeters;
  final MapController mapController;
  final VoidCallback? onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Location preview',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Non-interactive — avoids scroll/gesture fights & lag on web.
                WorkSiteOsmMap(
                  mapController: mapController,
                  pin: pin,
                  radiusMeters: radiusMeters,
                  interactive: false,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpenPicker,
                      child: pin == null
                          ? ColoredBox(
                              color: Colors.black.withValues(alpha: 0.18),
                              child: const Center(
                                child: Text(
                                  'Tap to open on map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pin == null
              ? 'No location set yet. Open the map or use current location.'
              : 'Allowed clock-in area ($radiusMeters m). Tap to edit on map.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.saved, required this.isActive});

  final WorkSite? saved;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final updated = saved?.updatedAt;
    final updatedLabel = updated == null
        ? 'Not saved yet'
        : 'Last saved ${DateFormat('d MMM yyyy, HH:mm').format(updated.toLocal())}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: isActive ? AppColors.teal : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Office location for clock-in',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Set one office location for employee clock-in. Choose the location '
            'on the map or use your current location, set the allowed radius '
            '(for example 100 m), enable location check, then save. '
            'The saved location stays fixed until you update it.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            updatedLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
