import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import '../l10n/l10n.dart';

/// Centred "something failed" state with a retry action, for screens whose
/// content could not be loaded.
class ErrorRetryView extends StatelessWidget
{
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: c.danger),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: context.l10n.commonReincearca,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
