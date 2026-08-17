import 'package:intl/intl.dart';

class AppTime {
  static const Duration malaysiaOffset = Duration(hours: 8);

  /// Current Malaysia wall-clock time (UTC+8), independent of device timezone.
  ///
  /// Returns a timezone-agnostic [DateTime] (`isUtc == false`) whose fields are
  /// already Malaysia local. Do **not** pass this through [toMalaysia] again.
  static DateTime malaysiaNow() {
    final m = DateTime.now().toUtc().add(malaysiaOffset);
    return DateTime(
      m.year,
      m.month,
      m.day,
      m.hour,
      m.minute,
      m.second,
      m.millisecond,
      m.microsecond,
    );
  }

  /// Converts a stored absolute timestamp (usually UTC from the DB) into
  /// Malaysia wall-clock fields for display.
  static DateTime toMalaysia(DateTime value) {
    final m = value.toUtc().add(malaysiaOffset);
    return DateTime(
      m.year,
      m.month,
      m.day,
      m.hour,
      m.minute,
      m.second,
      m.millisecond,
      m.microsecond,
    );
  }

  static String malaysiaDateString() => dateOnly(malaysiaNow());

  static String dateOnly(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String formatMalaysia(DateTime value, String pattern) {
    return DateFormat(pattern).format(toMalaysia(value));
  }

  /// Calendar day in Malaysia (year-month-day only).
  static DateTime malaysiaDateOnly([DateTime? from]) {
    final d = toMalaysia(from ?? DateTime.now().toUtc());
    return DateTime(d.year, d.month, d.day);
  }

  /// Monday–Sunday week containing [day] (date-only).
  static (DateTime start, DateTime end) weekBoundsContaining(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final fromMonday = (d.weekday - DateTime.monday) % 7;
    final start = d.subtract(Duration(days: fromMonday));
    final end = start.add(const Duration(days: 6));
    return (start, end);
  }

  /// First and last calendar day of the month containing [day].
  static (DateTime start, DateTime end) monthBoundsContaining(DateTime day) {
    final start = DateTime(day.year, day.month, 1);
    final end = DateTime(day.year, day.month + 1, 0);
    return (start, end);
  }
}
