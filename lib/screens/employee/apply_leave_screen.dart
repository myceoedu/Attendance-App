import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../models/annual_leave_summary.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/error_messages.dart';
import '../../utils/leave_catalog.dart';
import '../../utils/leave_time_conflict.dart';

enum _AnnualLeaveKind { full, halfAm, halfPm }

/// Apply for leave — stepped flow:
/// 1) Type → 2) Dates → 3) Reason → 4) Attachment (required for sick leave / MC).
///
/// [annualOnly]: annual leave only (type locked; validates against annual balance).
/// [otherLeaveOnly]: non-annual types (sick, unpaid, statutory, etc.) — **Other** tab.
class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({
    super.key,
    this.annualOnly = false,
    this.otherLeaveOnly = false,
  }) : assert(
         !(annualOnly && otherLeaveOnly),
         'Cannot set both annualOnly and otherLeaveOnly',
       );

  final bool annualOnly;
  final bool otherLeaveOnly;

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  String _leaveType = LeaveCatalog.annual;
  _AnnualLeaveKind _annualKind = _AnnualLeaveKind.full;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  /// Summary by calendar year (Malaysia overlap) for validation.
  final Map<int, AnnualLeaveSummary> _summaryByYear = {};

  /// Conflicting leave found after date selection; null while loading or if none.
  List<LeaveRequest>? _conflicts;
  bool _checkingConflicts = false;

  /// Picked file (uploaded on submit). Cleared if user removes it.
  PlatformFile? _attachment;

  final _dateFmt = DateFormat('d MMM yyyy');

  /// Must match [SupabaseService] upload rules. We use [FileType.any] instead of
  /// [FileType.custom] so Android does not call the buggy `custom` channel method
  /// (MissingPluginException on some builds / emulators).
  static const _allowedAttachmentExt = {
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  bool get _annualOnly => widget.annualOnly;

  bool get _otherLeaveOnly => widget.otherLeaveOnly;

  bool get _requiresMc =>
      !_annualOnly && LeaveCatalog.requiresMcAttachment(_leaveType);

  String? _extensionLower(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i).toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    if (_annualOnly) {
      _leaveType = LeaveCatalog.annual;
      _annualKind = _AnnualLeaveKind.full;
    } else if (_otherLeaveOnly) {
      _leaveType = LeaveCatalog.sick;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _setAnnualKind(_AnnualLeaveKind k) {
    setState(() {
      _annualKind = k;
      switch (k) {
        case _AnnualLeaveKind.full:
          _leaveType = LeaveCatalog.annual;
          break;
        case _AnnualLeaveKind.halfAm:
          _leaveType = LeaveCatalog.annualHalfAm;
          break;
        case _AnnualLeaveKind.halfPm:
          _leaveType = LeaveCatalog.annualHalfPm;
          break;
      }
      if (LeaveCatalog.isHalfDayAnnual(_leaveType) && _startDate != null) {
        _endDate = _startDate;
      }
      _conflicts = null;
      _summaryByYear.clear();
    });
  }

  void _onGeneralLeaveTypeSelected(String v) {
    setState(() {
      _leaveType = v;
      if (LeaveCatalog.isHalfDayAnnual(_leaveType) && _startDate != null) {
        _endDate = _startDate;
      }
      _conflicts = null;
      _summaryByYear.clear();
    });
  }

  List<DropdownMenuItem<String>> get _otherLeaveMenuItems => LeaveCatalog
      .orderedOtherTypes
      .map(
        (t) => DropdownMenuItem<String>(
          value: t,
          child: Text(LeaveCatalog.displayName(t)),
        ),
      )
      .toList();

  List<DropdownMenuItem<String>> get _allLeaveMenuItems => LeaveCatalog
      .orderedAllTypes
      .map(
        (t) => DropdownMenuItem<String>(
          value: t,
          child: Text(LeaveCatalog.displayName(t)),
        ),
      )
      .toList();

  Future<void> _pickDate({required bool isStart}) async {
    final now = AppTime.malaysiaNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: isStart ? now : (_startDate ?? now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        if (LeaveCatalog.isHalfDayAnnual(_leaveType)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (LeaveCatalog.isHalfDayAnnual(_leaveType)) {
          _startDate = picked;
        }
      }
      _conflicts = null;
      _summaryByYear.clear();
    });
    // Run conflict check as soon as both dates are chosen.
    if (_startDate != null && _endDate != null) {
      _checkConflicts();
      _refreshAnnualSummariesForRange();
    }
  }

  Future<void> _refreshAnnualSummariesForRange() async {
    if (!_annualOnly) return;
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null || !mounted) return;
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final fromY = math.min(start.year, end.year);
      final toY = math.max(start.year, end.year);
      final next = <int, AnnualLeaveSummary>{};
      for (var y = fromY; y <= toY; y++) {
        final s = await SupabaseService.getAnnualLeaveSummary(uid, year: y);
        if (s != null) next[y] = s;
      }
      if (!mounted) return;
      setState(() {
        _summaryByYear
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  String? _annualBalanceError() {
    if (!_annualOnly) return null;
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) return null;

    final fromY = math.min(start.year, end.year);
    final toY = math.max(start.year, end.year);

    for (var y = fromY; y <= toY; y++) {
      final need = LeaveCatalog.annualCreditInYear(_leaveType, start, end, y);
      if (need <= 0) continue;
      final s = _summaryByYear[y];
      if (s == null) {
        return 'Could not load annual leave balance for year $y.';
      }
      if (need > s.remaining + 1e-6) {
        final rem = s.remaining;
        final remLabel = rem == rem.roundToDouble()
            ? '${rem.round()}'
            : rem.toStringAsFixed(1);
        final needLabel = need == need.roundToDouble()
            ? '${need.round()}'
            : need.toStringAsFixed(1);
        return 'For calendar year $y, this request needs $needLabel day(s), but only '
            '$remLabel day(s) remain.';
      }
    }
    return null;
  }

  Future<void> _checkConflicts() async {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) return;
    if (!mounted) return;
    setState(() => _checkingConflicts = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      final result = await SupabaseService.getOverlappingLeaves(
        userId: uid,
        startDate: start,
        endDate: end,
      );
      final filtered = result
          .where(
            (c) => LeaveTimeConflict.conflictsWith(_leaveType, start, end, c),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _conflicts = filtered;
        _checkingConflicts = false;
      });
    } catch (_) {
      // Silently ignore. Conflict check is advisory. Server enforces on submit.
      if (!mounted) return;
      setState(() => _checkingConflicts = false);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      // FileType.any avoids the native "custom" picker path that throws
      // MissingPluginException on some devices after hot reload or older builds.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        // Bytes only needed on web. Native uploads from the file path.
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final ext = _extensionLower(file.name);
      if (ext == null || !_allowedAttachmentExt.contains(ext)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose PDF, JPG, PNG, or WebP only.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      setState(() => _attachment = file);
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File picker not linked. Stop the app completely, then run '
            '`flutter clean` and `flutter run` (not hot restart).',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick file: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _clearAttachment() => setState(() => _attachment = null);

  String? _validateReason(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Describe your reason';
    if (t.length < 8) {
      return 'Please add a bit more detail (at least 8 characters)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select start and end dates')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }
    final sd = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final ed = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    if (LeaveCatalog.isHalfDayAnnual(_leaveType) && sd != ed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Half-day annual leave must use a single date'),
        ),
      );
      return;
    }
    if (_annualOnly) {
      await _refreshAnnualSummariesForRange();
      if (!mounted) return;
      final balErr = _annualBalanceError();
      if (balErr != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(balErr), backgroundColor: AppColors.danger),
        );
        return;
      }
    }
    if (_requiresMc && _attachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sick leave needs a medical certificate (MC) or doctor\'s note. Attach a PDF or image.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      String? storagePath;

      if (_attachment != null) {
        storagePath = await SupabaseService.uploadLeaveAttachment(
          userId: uid,
          file: _attachment!,
        );
      }

      await SupabaseService.applyLeave(
        userId: uid,
        leaveType: _leaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonCtrl.text.trim(),
        attachmentPath: storagePath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyLeaveError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          _annualOnly
              ? 'Apply for annual leave'
              : _otherLeaveOnly
              ? 'Apply for other leave'
              : 'Apply for leave',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _submissionOverviewCard(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.24),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Approved full-day leave blocks clock-in for those dates. '
                        'Half-day annual does not. You can still record attendance.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_annualOnly) ...[
                _stepCard(
                  step: 1,
                  title: _otherLeaveOnly ? 'Type of leave' : 'Leave type',
                  subtitle: _otherLeaveOnly
                      ? 'Sick leave needs an MC. Other types need a clear reason.'
                      : 'Annual, unpaid, and statutory leave types.',
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _leaveType,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                    ),
                    items: _otherLeaveOnly
                        ? _otherLeaveMenuItems
                        : _allLeaveMenuItems,
                    onChanged: (v) {
                      if (v == null) return;
                      _onGeneralLeaveTypeSelected(v);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _typeHintBanner(),
                const SizedBox(height: 14),
              ],
              if (_annualOnly) ...[
                _stepCard(
                  step: 1,
                  title: 'Annual leave type',
                  subtitle:
                      'Full day uses more balance. Half-day counts as 0.5. AM and PM use the same date.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<_AnnualLeaveKind>(
                        segments: const [
                          ButtonSegment(
                            value: _AnnualLeaveKind.full,
                            label: Text('Full day'),
                            icon: Icon(
                              Icons.event_available_outlined,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: _AnnualLeaveKind.halfAm,
                            label: Text('Half AM'),
                            icon: Icon(Icons.wb_sunny_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: _AnnualLeaveKind.halfPm,
                            label: Text('Half PM'),
                            icon: Icon(Icons.nights_stay_outlined, size: 18),
                          ),
                        ],
                        selected: {_annualKind},
                        onSelectionChanged: (s) {
                          if (s.isEmpty) return;
                          _setAnnualKind(s.first);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _stepCard(
                step: 2,
                title: 'Dates',
                subtitle: () {
                  if (_annualOnly && LeaveCatalog.isHalfDayAnnual(_leaveType)) {
                    return 'Pick one date. Start and end stay the same.';
                  }
                  if (_annualOnly) {
                    return 'Start from today or later. Multi-day counts use calendar days in each year.';
                  }
                  return 'Start from today or later.';
                }(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _miniLabel(
                            LeaveCatalog.isHalfDayAnnual(_leaveType)
                                ? 'Date'
                                : 'Start',
                          ),
                          const SizedBox(height: 6),
                          _dateField(
                            _startDate,
                            () => _pickDate(isStart: true),
                          ),
                        ],
                      ),
                    ),
                    if (!LeaveCatalog.isHalfDayAnnual(_leaveType)) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _miniLabel('End'),
                            const SizedBox(height: 6),
                            _dateField(
                              _endDate,
                              () => _pickDate(isStart: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_startDate != null && _endDate != null) ...[
                const SizedBox(height: 10),
                Text(
                  LeaveCatalog.isHalfDayAnnual(_leaveType)
                      ? 'Half day selected (0.5 annual days)'
                      : '${_endDate!.difference(_startDate!).inDays + 1} day(s) selected',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_checkingConflicts) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Checking for date conflicts…',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ] else if (_conflicts != null && _conflicts!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _conflictBanner(_conflicts!),
              ],
              if (_annualOnly &&
                  _startDate != null &&
                  _endDate != null &&
                  _summaryByYear.isNotEmpty) ...[
                const SizedBox(height: 10),
                _annualBalancePanel(),
              ],
              const SizedBox(height: 14),
              _stepCard(
                step: 3,
                title: 'Reason & details',
                subtitle: _requiresMc
                    ? 'Describe symptoms and clinic visit. Attach your MC in the next step.'
                    : 'Explain clearly what this leave is for.',
                child: TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: _requiresMc
                        ? 'e.g. Fever and flu, visited clinic today'
                        : 'e.g. Family trip or urgent personal matter',
                    alignLabelWithHint: true,
                  ),
                  validator: _validateReason,
                ),
              ),
              const SizedBox(height: 14),
              _stepCard(
                step: 4,
                title: 'Supporting document',
                subtitle: _requiresMc
                    ? 'Required: MC or doctor\'s letter (PDF or photo).'
                    : 'Optional: attach any supporting document.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickAttachment,
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      label: Text(
                        _attachment == null
                            ? 'Choose file (PDF, JPG, PNG)'
                            : 'Change file',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    if (_attachment != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successLight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              color: AppColors.success,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _attachment!.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _submitting ? null : _clearAttachment,
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_requiresMc)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.danger.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _attachment == null
                                    ? 'You must attach your MC before submitting sick leave.'
                                    : 'MC attached. You can submit when ready.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: _attachment == null
                                      ? AppColors.danger
                                      : AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.onBrand,
                  minimumSize: const Size.fromHeight(44),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit request'),
              ),
              const SizedBox(height: 12),
              Text(
                'Submission order: dates validated → file uploaded (if any) → request saved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submissionOverviewCard() {
    final lines = _annualOnly
        ? (
            'Annual leave. Choose full day or half AM/PM. Balance updates when approved.',
            <(IconData, String)>[
              (
                Icons.event_available_outlined,
                'Annual type (full / half AM / half PM)',
              ),
              (
                Icons.date_range_rounded,
                'Dates (one date only for half-day)',
              ),
              (Icons.notes_rounded, 'Reason'),
              (Icons.attach_file_rounded, 'Optional supporting file'),
            ],
          )
        : (
            _otherLeaveOnly
                ? 'Other leave (paid, unpaid, or statutory). MC is required for sick leave only.'
                : 'Pick a type first. Rules and attachments change per type.',
            <(IconData, String)>[
              (Icons.category_outlined, 'Leave type'),
              (Icons.date_range_rounded, 'Start & end dates'),
              (Icons.notes_rounded, 'Reason / details'),
              (Icons.attach_file_rounded, 'MC or proof when required'),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppElevation.cardOnSurface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  gradient: AppGradients.brandPanel,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "What you're submitting",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lines.$1,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...lines.$2.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(e.$1, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.$2,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _annualBalancePanel() {
    final start = _startDate!;
    final end = _endDate!;
    final years = _summaryByYear.keys.toList()..sort();

    String fmt(double n) =>
        n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.skyLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.balance, size: 18, color: AppColors.sky),
              SizedBox(width: 8),
              Text(
                'Balance vs request (Malaysia calendar year)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...years.map((y) {
            final s = _summaryByYear[y];
            if (s == null) return const SizedBox.shrink();
            final need = LeaveCatalog.annualCreditInYear(
              _leaveType,
              start,
              end,
              y,
            );
            if (need <= 0) return const SizedBox.shrink();
            final ok = need <= s.remaining + 1e-6;
            final needLabel = fmt(need);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '$y · need $needLabel day(s) · ${fmt(s.remaining)} remaining '
                '(${fmt(s.used)} used, ${fmt(s.pending)} pending) ${ok ? '✓' : '✗'}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: ok ? AppColors.textPrimary : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _typeHintBanner() {
    final st = LeaveCatalog.uiStyle(_leaveType);
    late final String msg;
    late final Color bg;
    switch (_leaveType) {
      case LeaveCatalog.annual:
        msg = 'Full-day annual leave. Documents are optional.';
        bg = AppColors.skyLight;
        break;
      case LeaveCatalog.annualHalfAm:
        msg = 'Half-day morning. Start and end use the same date. Clock-in is still allowed.';
        bg = AppColors.skyLight;
        break;
      case LeaveCatalog.annualHalfPm:
        msg = 'Half-day afternoon. Start and end use the same date. Clock-in is still allowed.';
        bg = AppColors.skyLight;
        break;
      case LeaveCatalog.sick:
        msg = 'Describe your symptoms. An MC or doctor\'s note is required.';
        bg = AppColors.pinkLight;
        break;
      case LeaveCatalog.emergency:
        msg = 'Explain the urgent matter. Attach proof if you can.';
        bg = AppColors.orangeLight;
        break;
      case LeaveCatalog.unpaid:
        msg = 'Approved unpaid working days are unpaid in payroll.';
        bg = AppColors.surface;
        break;
      case LeaveCatalog.maternity:
        msg = 'Add expected dates and key details.';
        bg = AppColors.pinkLight;
        break;
      case LeaveCatalog.paternity:
        msg = 'Add expected dates and key details.';
        bg = AppColors.pinkLight;
        break;
      case LeaveCatalog.marriage:
        msg = 'Add wedding or ceremony details.';
        bg = AppColors.pinkLight;
        break;
      case LeaveCatalog.publicHoliday:
        msg = 'Note which public holiday this replaces.';
        bg = AppColors.successLight;
        break;
      default:
        msg = 'Add clear dates and a reason.';
        bg = AppColors.surface;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: st.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(st.icon, color: st.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required int step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppElevation.cardOnSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _dateField(DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          date != null ? _dateFmt.format(date) : 'Select',
          style: TextStyle(
            fontSize: 14,
            color: date != null ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _conflictBanner(List<LeaveRequest> conflicts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppLayout.cardRadiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Date conflict detected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You already have the following leave request(s) covering these dates:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          ...conflicts.map((c) {
            final range =
                '${_dateFmt.format(c.startDate)} – ${_dateFmt.format(c.endDate)}';
            final statusLabel =
                c.status[0].toUpperCase() + c.status.substring(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${c.leaveTypeDisplay} · $range ($statusLabel)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          const Text(
            'Change your dates or cancel the overlapping request first.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
