import 'auth_redirect.dart';

/// Captures auth email-link state from the URL before it is cleaned.
abstract final class AuthLinkBootstrap {
  static String? linkError;
  static bool recoveryHint = false;

  static void captureFromCurrentUrl() {
    linkError = AuthRedirect.authLinkErrorMessage();
    recoveryHint = AuthRedirect.isPasswordRecoveryUrl();
  }
}
