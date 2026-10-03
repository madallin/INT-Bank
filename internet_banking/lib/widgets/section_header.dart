import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Small icon + label shown above a form field or group.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: AppSpacing.xs),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: c.textSecondary)),
          const SizedBox(width: 6),
          Flexible(child: Text(title, style: context.text.labelMedium)),
        ],
      ),
    );
  }
}

/// Large centred page title with a supporting line.
class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
