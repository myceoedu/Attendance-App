import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/work_site.dart';
import '../../services/supabase_service.dart';
import '../../utils/geofence.dart';

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

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _isActive = false;
  WorkSite? _saved;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
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
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Could not load workplace settings. Run the work_site SQL migration if this is a new project.';
      });
    }
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
        _snack('Allow location access to set the workplace point.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      _snack('Location captured. Save to apply.');
    } on TimeoutException {
      _snack('Location timed out. Try again outdoors or with GPS on.', error: true);
    } catch (_) {
      _snack('Could not read GPS. Check browser/phone location settings.', error: true);
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
      });
      _snack(
        _isActive
            ? 'Workplace saved. Clock-in geofence is ON.'
            : 'Workplace saved. Geofence is OFF (clock-in anywhere).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        _snack('Only admins can save the workplace.', error: true);
      } else if (msg.contains('work_site') || msg.contains('pgrst205')) {
        _snack(
          'Database table missing. Run supabase_migration_work_site_geofence.sql.',
          error: true,
        );
      } else {
        _snack('Could not save. Check values and try again.', error: true);
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
      appBar: AppBar(title: const Text('Workplace location')),
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
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Workplace name',
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
                                keyboardType: const TextInputType.numberWithOptions(
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
                                  prefixIcon: Icon(Icons.my_location_outlined),
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
                                keyboardType: const TextInputType.numberWithOptions(
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: (_locating || _saving) ? null : _useMyLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.gps_fixed_rounded),
                          label: Text(
                            _locating
                                ? 'Getting location…'
                                : 'Use my current location',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _radiusCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Radius (metres)',
                            helperText:
                                'Clock-in allowed within this distance (20–5000 m).',
                            prefixIcon: Icon(Icons.radar_outlined),
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null ||
                                n < Geofence.minRadiusMeters ||
                                n > Geofence.maxRadiusMeters) {
                              return 'Use ${Geofence.minRadiusMeters}–${Geofence.maxRadiusMeters}';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Enforce on clock-in',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Employees must be inside the radius to clock in.'
                                : 'Geofence off — clock-in works from anywhere.',
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
                              : const Text('Save workplace'),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  'One workplace for clock-in',
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
            'Stand at the office and tap “Use my current location”, set the radius '
            '(e.g. 100 m), then turn on enforce and save. The pin is a fixed snapshot '
            '— it does not follow your phone home.',
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
