/// Organization contact points for [HelpSupportScreen].
///
/// Replace placeholders with your real HR / IT desk details.
abstract class HelpSupportConfig {
  /// Shown in diagnostics — keep in sync with [pubspec.yaml] `version` when you ship.
  static const String appVersionLabel = '1.0.0+1';

  /// Primary support inbox (opened with the device mail client).
  /// Empty hides the email contact shortcut.
  static const String supportEmail = '';

  /// E.164 or local format; if empty, the "Call" shortcut is hidden.
  static const String supportPhone = '+60 11-7078 7014';

  /// Shown under contact actions (optional copy).
  static const String officeHours =
      'Monday–Friday, 9:00–18:00 Malaysia Time (MYT)';
}
