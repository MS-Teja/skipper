import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// iOS-style alert: title, optional message, Cancel + a confirm action.
/// Resolves to true only when confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final c = AppColors.of(context);
      return CupertinoAlertDialog(
        title: Text(title, style: body(17, color: c.text, weight: 600)),
        content: message == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(message, style: body(13, color: c.text)),
              ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel, style: body(17, color: c.accent)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, true);
            },
            child: Text(
              confirmLabel,
              style: body(
                17,
                color: destructive ? c.danger : c.accent,
                weight: 600,
              ),
            ),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// iOS action sheet: a short list of choices plus Cancel.
Future<T?> chooseAction<T>(
  BuildContext context, {
  required String title,
  required List<(String, T)> actions,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) {
      final c = AppColors.of(context);
      return CupertinoActionSheet(
        title: Text(title, style: body(13, color: c.muted, weight: 600)),
        actions: [
          for (final (label, value) in actions)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label, style: body(19, color: c.accent)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: body(19, color: c.accent, weight: 600)),
        ),
      );
    },
  );
}
