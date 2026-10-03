import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Inline error message; announced by screen readers when it appears.
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: c.dangerSurface,
            borderRadius: BorderRadius.circular(AppRadii.sm + 2),
            border: Border.all(color: c.dangerBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodySmall?.copyWith(
                    color: c.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
