import '../models/leave_request.dart';
import 'leave_catalog.dart';

enum LeaveDayPart { full, am, pm }

/// Per-day coverage for conflict checks (half-day annual vs full-day leave, etc.).
abstract final class LeaveTimeConflict {
  static LeaveDayPart? _coverageOnDay(
    String leaveType,
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime day,
  ) {
    final ds = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final de = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(ds) || d.isAfter(de)) return null;
    if (leaveType == LeaveCatalog.annualHalfAm) return LeaveDayPart.am;
    if (leaveType == LeaveCatalog.annualHalfPm) return LeaveDayPart.pm;
    return LeaveDayPart.full;
  }

  static bool _partsConflict(LeaveDayPart a, LeaveDayPart b) {
    if (a == LeaveDayPart.full || b == LeaveDayPart.full) return true;
    return a == b;
  }

  /// True if [existing] cannot coexist with a new request of [newType] over [newStart]..[newEnd].
  static bool conflictsWith(
    String newType,
    DateTime newStart,
    DateTime newEnd,
    LeaveRequest existing,
  ) {
    final pend = existing.status.toLowerCase() == 'pending' ||
        existing.status.toLowerCase() == 'approved';
    if (!pend) return false;

    final ns = DateTime(newStart.year, newStart.month, newStart.day);
    final ne = DateTime(newEnd.year, newEnd.month, newEnd.day);
    var d = ns;
    while (!d.isAfter(ne)) {
      final pNew = _coverageOnDay(newType, newStart, newEnd, d);
      final pEx = _coverageOnDay(
        existing.leaveType,
        existing.startDate,
        existing.endDate,
        d,
      );
      if (pNew != null && pEx != null && _partsConflict(pNew, pEx)) {
        return true;
      }
      d = d.add(const Duration(days: 1));
    }
    return false;
  }
}
