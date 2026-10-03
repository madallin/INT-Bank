import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import '../l10n/l10n.dart';

/// Asks the user to confirm an action. Resolves to true only on confirm;
/// dismissing the dialog counts as "no".
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
})
async
{
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      actions: [
        // Stacked full-width so longer labels never wrap mid-word.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: confirmLabel,
              variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: cancelLabel ?? ctx.l10n.commonRenunta,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
