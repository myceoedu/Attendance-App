import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Which action should look like the easy default.
enum AppConfirmEmphasis {
  /// Keep / Cancel is filled. Use for delete, sign out, and other irreversible
  /// actions so a hurried tap does not confirm.
  safe,

  /// Confirm is filled. Use when the user opened the dialog to proceed
  /// (clock out, mark paid, reject with a note).
  confirm,
}

/// Side-by-side, equal-height actions. Never stacks into a tiny text link
/// above a full-width destructive button.
class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.emphasis = AppConfirmEmphasis.confirm,
    this.confirmColor,
    this.busy = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final AppConfirmEmphasis emphasis;
  final Color? confirmColor;
  final bool busy;

  static const double height = 48;
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final destructive =
        confirmColor ??
        (emphasis == AppConfirmEmphasis.safe
            ? AppColors.danger
            : AppColors.primaryDark);
    final radius = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    final Widget cancelButton;
    final Widget confirmButton;

    if (emphasis == AppConfirmEmphasis.safe) {
      cancelButton = FilledButton(
        onPressed: busy ? null : onCancel,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.onBrand,
          minimumSize: const Size(0, height),
          shape: radius,
          elevation: 0,
        ),
        child: Text(cancelLabel),
      );
      confirmButton = OutlinedButton(
        onPressed: busy ? null : onConfirm,
        style: OutlinedButton.styleFrom(
          foregroundColor: destructive,
          side: BorderSide(color: destructive),
          minimumSize: const Size(0, height),
          shape: radius,
        ),
        child: Text(confirmLabel),
      );
    } else {
      cancelButton = OutlinedButton(
        onPressed: busy ? null : onCancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          minimumSize: const Size(0, height),
          shape: radius,
        ),
        child: Text(cancelLabel),
      );
      confirmButton = FilledButton(
        onPressed: busy ? null : onConfirm,
        style: FilledButton.styleFrom(
          backgroundColor: destructive,
          foregroundColor: AppColors.onBrand,
          minimumSize: const Size(0, height),
          shape: radius,
          elevation: 0,
        ),
        child: Text(confirmLabel),
      );
    }

    return Row(
      children: [
        Expanded(child: cancelButton),
        const SizedBox(width: gap),
        Expanded(child: confirmButton),
      ],
    );
  }
}

/// Dialog chrome: title, copy, optional body, then [AppDialogActions].
class AppConfirmPanel extends StatelessWidget {
  const AppConfirmPanel({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.message,
    this.body,
    this.emphasis = AppConfirmEmphasis.confirm,
    this.confirmColor,
    this.busy = false,
  });

  final String title;
  final String? message;
  final Widget? body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final AppConfirmEmphasis emphasis;
  final Color? confirmColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (body != null) ...[const SizedBox(height: 16), body!],
          const SizedBox(height: 22),
          AppDialogActions(
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            onCancel: onCancel,
            onConfirm: onConfirm,
            emphasis: emphasis,
            confirmColor: confirmColor,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

/// Returns true only if the user taps confirm. Tap outside / back = false.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? body,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  AppConfirmEmphasis emphasis = AppConfirmEmphasis.confirm,
  Color? confirmColor,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: AppConfirmPanel(
              title: title,
              message: message,
              body: body,
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              emphasis: emphasis,
              confirmColor: confirmColor,
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
