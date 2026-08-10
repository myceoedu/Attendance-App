import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts a raw exception from a leave/attendance operation into a short,
/// user-friendly message suitable for display in a SnackBar or error widget.
///
/// Known Postgres/Supabase error messages are translated to plain English.
/// All others fall back to a generic message so internal details are never
/// shown to the user.
String friendlyLeaveError(Object e) {
  final raw = e.toString().toLowerCase();

  // Check Postgres message text (comes from RAISE EXCEPTION in SQL functions).
  if (e is PostgrestException) {
    final msg = (e.message).toLowerCase();
    if (msg.contains('pending or approved leave') ||
        msg.contains('covering these dates') ||
        msg.contains('already have a pending')) {
      return 'These dates overlap an existing leave request (pending or approved).\n'
          'Change the dates or cancel the overlapping request first.';
    }
    if (msg.contains('annual leave would exceed balance') ||
        msg.contains('exceed_balance')) {
      return 'This annual leave goes over your entitlement for one or more '
          'calendar years. Shorten the dates or wait until leave is freed up.';
    }
    if (msg.contains('approved leave already covers')) {
      return 'An approved leave already covers the selected dates.';
    }
    if (msg.contains('outside workplace geofence')) {
      return 'You are outside the office area. Move closer and try clock-in again.';
    }
    if (msg.contains('location required for workplace')) {
      return 'Location is required to clock in. Allow location access and try again.';
    }
    if (msg.contains('invalid clock-in location')) {
      return 'Could not verify your location. Try clock-in again.';
    }
    if (msg.contains('attendance already exists')) {
      return 'An attendance record already exists for the selected date.';
    }
    if (msg.contains('not allowed') || msg.contains('permission denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('not authenticated') || msg.contains('jwt')) {
      return 'Your session has expired. Please sign in again.';
    }
  }

  // Exception thrown by client-side checks.
  if (raw.contains('approved leave already covers today')) {
    return 'Approved leave already covers today. Clock-in is not allowed.';
  }
  if (raw.contains('outside workplace geofence')) {
    return 'You are outside the office area. Move closer and try clock-in again.';
  }
  if (raw.contains('location required for workplace')) {
    return 'Location is required to clock in. Allow location access and try again.';
  }
  if (raw.contains('pending or approved leave')) {
    return 'These dates overlap an existing leave request.\n'
        'Change the dates or cancel the overlapping request first.';
  }
  if (raw.contains('network') || raw.contains('socket') || raw.contains('timeout')) {
    return 'Network error. Check your connection and try again.';
  }

  // Generic fallback — never expose raw exception text.
  return 'Something went wrong. Please try again.';
}

/// Friendly message for admins approving/rejecting leave (includes balance RPC errors).
String friendlyAdminLeaveError(Object e) {
  if (e is PostgrestException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('annual leave would exceed balance') ||
        msg.contains('exceed_balance')) {
      return 'Cannot approve. This employee\'s annual leave would exceed their '
          'balance for one or more calendar years. Adjust entitlement (HR), '
          'reject overlaps, or ask them to shorten the request.';
    }
  }

  final base = friendlyLeaveError(e);
  if (base == 'Something went wrong. Please try again.') return base;
  return base;
}

String friendlyClaimError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('row-level security') || msg.contains('rls')) {
    return 'Permission denied. Make sure the database migration for claims is applied.';
  }
  if (msg.contains('bucket') && msg.contains('not found')) {
    return 'Storage is not set up yet. Create the claim-attachments bucket (see migration SQL).';
  }
  if (e is PostgrestException) {
    final m = e.message.toLowerCase();
    final code = e.code;
    // Table missing from DB or API schema cache (migration not applied).
    if (code == 'PGRST205' ||
        m.contains('could not find the table') ||
        m.contains('expense_claims') && m.contains('schema cache')) {
      return 'Expense claims are not set up on the server yet.\n\n'
          'In Supabase: open SQL Editor, run the file '
          'supabase_migration_expense_claims.sql from this project, then tap Retry. '
          'If it still fails, wait a minute or restart your project so the API refreshes.';
    }
    if (m.contains('permission denied')) {
      return 'You do not have permission to perform this action.';
    }
  }
  if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
    return 'Network error. Check your connection and try again.';
  }
  // Surface our own Exception messages from validation / submit helpers.
  if (e is Exception) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
  }
  return 'Something went wrong. Please try again.';
}

String friendlyAdminClaimError(Object e) => friendlyClaimError(e);
