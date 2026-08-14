import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import 'web_popup.dart';

/// Opens a private Storage object via a short-lived signed HTTPS URL.
///
/// Web: opens a blank tab on tap (keeps the user gesture), then navigates.
/// Android/iOS: in-app browser first, then the system browser.
Future<void> openSignedStorageUrl({
  required BuildContext context,
  required Future<String> Function() fetchUrl,
  String openFailedMessage = 'Could not open the file',
  String loadFailedPrefix = 'Could not load attachment',
}) async {
  final tab = WebBlankTab.open();

  try {
    final url = await fetchUrl();

    if (tab != null) {
      if (tab.goTo(url)) return;
      tab.close();
      if (!context.mounted) return;
      _showOpenError(context, openFailedMessage);
      return;
    }

    final uri = Uri.parse(url);
    var ok = false;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      ok = await _tryLaunch(uri, LaunchMode.inAppBrowserView);
    }
    if (!ok) {
      ok = await _tryLaunch(uri, LaunchMode.externalApplication);
    }
    if (!ok) {
      ok = await _tryLaunch(uri, LaunchMode.platformDefault);
    }
    if (!ok) {
      if (!context.mounted) return;
      _showOpenError(context, openFailedMessage);
    }
  } catch (e) {
    tab?.close();
    if (!context.mounted) return;
    _showOpenError(context, '$loadFailedPrefix: $e');
  }
}

Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

void _showOpenError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.danger),
  );
}
