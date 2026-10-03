import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

/// Back button + title bar used by secondary screens.
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: c.surface,
          boxShadow: [
            BoxShadow(
              color: c.shadow.withValues(alpha: c.shadow.a * 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              tooltip: context.l10n.commonInapoi,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              color: c.textPrimary,
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
