/// Organization contact points for [HelpSupportScreen].
///
/// Replace placeholders with your real HR / IT desk details.
abstract class HelpSupportConfig {
  /// Shown in diagnostics — keep in sync with [pubspec.yaml] `version` when you ship.
  static const String appVersionLabel = '1.0.0+1';

  /// Primary support inbox (opened with the device mail client).
  static const String supportEmail = 'hr@yourcompany.com';

  /// E.164 or local format; if empty, the "Call" shortcut is hidden.
  static const String supportPhone = '';

  /// Shown under contact actions (optional copy).
  static const String officeHours =
      'Monday–Friday, 9:00–18:00 Malaysia Time (MYT)';
}
