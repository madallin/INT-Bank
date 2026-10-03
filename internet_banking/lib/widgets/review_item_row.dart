import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Label/value pair used on review steps.
class ReviewItemRow extends StatelessWidget {
  final String label;
  final String value;

  const ReviewItemRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: c.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ),
            Expanded(
              child: Text(value, style: context.text.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
