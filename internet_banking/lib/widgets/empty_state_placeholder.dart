import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class EmptyStatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyStatePlaceholder({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 64, color: c.border)),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.text.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: context.text.bodySmall?.copyWith(
                  fontSize: 13,
                  color: c.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
