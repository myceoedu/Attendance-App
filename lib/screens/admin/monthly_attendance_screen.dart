import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_theme.dart';
import '../../models/monthly_attendance_summary.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/csv_download_stub.dart'
    if (dart.library.html) '../../utils/csv_download_web.dart'
    if (dart.library.io) '../../utils/csv_download_io.dart';
import '../../utils/debouncer.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _reportingFmt = DateFormat('d MMM yyyy');

  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebounce = Debouncer();
  DateTime _selectedMonth = _currentMonth();
  List<MonthlyAttendanceSummary> _summaries = [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String _reviewFilter = 'all';

  List<MonthlyAttendanceSummary> _visibleSummaries = const [];

  static DateTime _currentMonth() {
    final now = AppTime.malaysiaNow();
    return DateTime(now.year, now.month);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMonthlyAttendanceSummaries(
        _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _summaries = data;
        _loading = false;
        _error = null;
        _recomputeFiltered();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  void _recomputeFiltered() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final hasQuery = query.isNotEmpty;
    if (!hasQuery && _reviewFilter == 'all') {
      _visibleSummaries = _summaries;
      return;
    }
    _visibleSummaries = _summaries
        .where((summary) {
          if (_reviewFilter == 'mia' && !summary.hasMia) return false;
          if (_reviewFilter == 'no_attendance' && !summary.hasNoAttendance) {
            return false;
          }
          if (!hasQuery) return true;
          return summary.displayName.toLowerCase().contains(query) ||
              summary.username.toLowerCase().contains(query) ||
              summary.email.toLowerCase().contains(query) ||
              summary.department.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  bool get _canMoveForward => _selectedMonth.isBefore(_currentMonth());

  Future<void> _editNotes(MonthlyAttendanceSummary row) async {
    final controller = TextEditingController(text: row.notes);
    var saving = false;

    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text('Notes · ${row.displayName}'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Add a note for this month…',
                  border: OutlineInputBorder(),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                AppDialogActions(
                  cancelLabel: 'Cancel',
                  confirmLabel: saving ? 'Saving…' : 'Save',
                  busy: saving,
                  emphasis: AppConfirmEmphasis.confirm,
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    if (saving) return;
                    setLocal(() => saving = true);
                    final text = controller.text.trim();
                    try {
                      await SupabaseService.upsertMonthlyAttendanceNote(
                        employeeId: row.employeeId,
                        month: _selectedMonth,
                        notes: text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, text);
                    } catch (e) {
                      setLocal(() => saving = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(friendlyLeaveError(e)),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (saved == null || !mounted) return;

    setState(() {
      final i = _summaries.indexWhere((s) => s.employeeId == row.employeeId);
      if (i >= 0) {
        _summaries[i] = _summaries[i].copyWith(notes: saved);
      }
      _recomputeFiltered();
    });
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    final rows = _visibleSummaries;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to export for the current filters.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final buf = StringBuffer()
        ..writeln(MonthlyAttendanceSummary.csvHeaders.map(_csvEscape).join(','));
      for (final row in rows) {
        final cells = row.toCsvCells(
          formatDate: (d) => _reportingFmt.format(d),
        );
        buf.writeln(cells.map(_csvEscape).join(','));
      }

      final ym =
          '${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}';
      final filename = 'attendance_$ym.csv';
      final saved = await offerCsvDownload(buf.toString(), filename);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $filename'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyLeaveError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visibleSummaries;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavBackground,
        foregroundColor: AppColors.onBrand,
        iconTheme: AppChrome.onBrandIcons,
        actionsIconTheme: AppChrome.onBrandIcons,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: AppChrome.onBrand,
        title: const Text('Monthly Attendance'),
        actions: [
          IconButton(
            tooltip: 'Download CSV',
            onPressed: _loading || _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onBrand,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _load(showSpinner: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _monthHeader(),
                          const SizedBox(height: 10),
                          Text(
                            'Mon–Fri expected. Saturday is optional. '
                            'Reporting On = first clock-in this month. '
                            'Tap Notes to edit.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.95,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppFilterBar(
                            searchController: _searchCtrl,
                            onSearchChanged: (_) => _searchDebounce(() {
                              if (mounted) setState(_recomputeFiltered);
                            }),
                            searchHint:
                                'Search name, username, email, or department',
                            chipOptions: const [
                              AppFilterOption(value: 'all', label: 'All'),
                              AppFilterOption(value: 'mia', label: 'Has MIA'),
                              AppFilterOption(
                                value: 'no_attendance',
                                label: 'No Attendance',
                              ),
                            ],
                            selectedChip: _reviewFilter,
                            onChipSelected: (value) {
                              setState(() {
                                _reviewFilter = value;
                                _recomputeFiltered();
                              });
                            },
                            margin: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${filtered.length} employee'
                            '${filtered.length == 1 ? '' : 's'}'
                            '${_reviewFilter == 'all' && _searchCtrl.text.isEmpty ? '' : ' (filtered)'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.filter_alt_off,
                          title: 'No employees match the filters',
                          subtitle: 'Try another month or review filter',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      sliver: SliverToBoxAdapter(
                        child: _AttendanceMonthTable(
                          rows: filtered,
                          reportingFmt: _reportingFmt,
                          onEditNotes: _editNotes,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _monthHeader() {
    final label = _monthFmt.format(_selectedMonth);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.adminBrandHeader,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: () => _changeMonth(-1),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
            ),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Monthly attendance review',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: _canMoveForward ? () => _changeMonth(1) : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(
                alpha: _canMoveForward ? 0.18 : 0.08,
              ),
            ),
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AttendanceMonthTable extends StatelessWidget {
  const _AttendanceMonthTable({
    required this.rows,
    required this.reportingFmt,
    required this.onEditNotes,
  });

  final List<MonthlyAttendanceSummary> rows;
  final DateFormat reportingFmt;
  final ValueChanged<MonthlyAttendanceSummary> onEditNotes;

  static const _stickyWidth = 148.0;
  static const _headerHeight = 44.0;
  static const _rowHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _stickyWidth,
            child: Column(
              children: [
                _headerCell(
                  'Staffing / Name',
                  align: TextAlign.left,
                  sticky: true,
                ),
                ...rows.map((row) {
                  return Container(
                    height: _rowHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.staffingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                        Text(
                          row.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(width: 1, color: AppColors.divider),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      _ScrollHeader('Reporting On', width: 108),
                      _ScrollHeader('Attend', width: 64),
                      _ScrollHeader('Leave', width: 56),
                      _ScrollHeader('MC', width: 48),
                      _ScrollHeader('MIA', width: 56),
                      _ScrollHeader('Sat', width: 48),
                      _ScrollHeader('WD', width: 48),
                      _ScrollHeader('Notes', width: 168, align: TextAlign.left),
                    ],
                  ),
                  ...rows.map((row) {
                    final miaWarn = row.miaDays > 0;
                    final satWarn = row.saturdayOverLimit;
                    return SizedBox(
                      height: _rowHeight,
                      child: Row(
                        children: [
                          _ScrollCell(
                            row.reportingOn == null
                                ? '—'
                                : reportingFmt.format(row.reportingOn!),
                            width: 108,
                            align: TextAlign.left,
                          ),
                          _ScrollCell(row.attendDaysLabel, width: 64),
                          _ScrollCell(row.leaveDaysLabel, width: 56),
                          _ScrollCell(row.mcDaysLabel, width: 48),
                          _ScrollCell(
                            row.miaDaysLabel,
                            width: 56,
                            emphasize: miaWarn,
                            emphasizeColor: AppColors.danger,
                          ),
                          _ScrollCell(
                            '${row.saturdayAttendCount}',
                            width: 48,
                            emphasize: satWarn,
                            emphasizeColor: AppColors.warning,
                          ),
                          _ScrollCell('${row.totalWorkingDays}', width: 48),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onEditNotes(row),
                              child: _ScrollCell(
                                row.notes.isEmpty ? '' : row.notes,
                                width: 168,
                                align: TextAlign.left,
                                muted: row.notes.isEmpty,
                                placeholder: row.notes.isEmpty,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String label, {
    TextAlign align = TextAlign.center,
    bool sticky = false,
  }) {
    return Container(
      height: _headerHeight,
      width: sticky ? _stickyWidth : null,
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.warningLight,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ScrollHeader extends StatelessWidget {
  const _ScrollHeader(
    this.label, {
    required this.width,
    this.align = TextAlign.center,
  });

  final String label;
  final double width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _AttendanceMonthTable._headerHeight,
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.warningLight,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ScrollCell extends StatelessWidget {
  const _ScrollCell(
    this.text, {
    required this.width,
    this.align = TextAlign.center,
    this.emphasize = false,
    this.emphasizeColor,
    this.muted = false,
    this.placeholder = false,
  });

  final String text;
  final double width;
  final TextAlign align;
  final bool emphasize;
  final Color? emphasizeColor;
  final bool muted;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final display = placeholder ? 'Tap to add' : text;
    final color = emphasize
        ? (emphasizeColor ?? AppColors.danger)
        : placeholder
        ? AppColors.textHint
        : muted
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    return Container(
      width: width,
      height: _AttendanceMonthTable._rowHeight,
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Text(
        display,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
