import 'package:flutter/material.dart';

import 'app_button.dart';

enum ActionButtonVariant { primary, secondary }

/// Legacy API kept for screens not yet migrated; renders an [AppButton].
@Deprecated('Use AppButton')
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ActionButtonVariant variant;
  final bool isLoading;

  /// When true the button is wrapped in [Expanded] for use inside a [Row].
  final bool isExpanded;

  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = ActionButtonVariant.primary,
    this.isLoading = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = AppButton(
      label: label,
      onPressed: onTap,
      isLoading: isLoading,
      variant: variant == ActionButtonVariant.primary
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
    );

    if (!isExpanded) return button;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: button,
      ),
    );
  }
}
