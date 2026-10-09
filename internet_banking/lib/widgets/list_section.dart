import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A titled card of rows (Profile settings, Payments actions).
class ListSection extends StatelessWidget
{
  const ListSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if(title != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
            child: Semantics(
              header: true,
              child: Text(title!, style: context.text.labelMedium?.copyWith(color: c.textSecondary)),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for(var i = 0; i < children.length; i++) ...[
                if(i > 0) Divider(height: 1, indent: 64, color: c.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row: icon, title, optional detail line and trailing widget (chevron by default
/// when tappable).
class ListRow extends StatelessWidget
{
  const ListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.brandSurface, borderRadius: BorderRadius.circular(AppRadii.sm)),
                  child: Icon(icon, size: 20, color: c.brand),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    if(subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              if(trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ]
              else if(onTap != null)
                ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
