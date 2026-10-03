import 'package:flutter/material.dart';

import '../core/utils/haptic_feedback_helper.dart';
import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }

/// The app's one button. Gives every call site the same height, radius,
/// ripple, disabled look, loading state and screen-reader semantics.
///
/// Pass `onPressed: null` to disable it; [isLoading] also blocks taps.
class AppButton extends StatelessWidget
{
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Fill the available width (the default for full-width form actions).
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(AppRadii.xl);

    final (Color foreground, Decoration decoration) = switch (variant)
    {
      AppButtonVariant.primary => (
          c.onBrand,
          BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(colors: [c.brand, c.brand.withValues(alpha: 0.85)]),
            boxShadow: enabled
                ? [BoxShadow(color: c.brand.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4))]
                : const [],
          ),
        ),
      AppButtonVariant.danger => (
          c.onDanger,
          BoxDecoration(borderRadius: radius, color: c.danger),
        ),
      AppButtonVariant.secondary => (
          c.textPrimary,
          BoxDecoration(borderRadius: radius, color: c.surfaceMuted),
        ),
      AppButtonVariant.outline => (
          c.brand,
          BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.border, width: 1.5),
          ),
        ),
      AppButtonVariant.text => (
          c.brand,
          BoxDecoration(borderRadius: radius),
        ),
    };

    final content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if(icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: foreground),
                ),
              ),
            ],
          );

    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || isLoading ? 1 : 0.45,
      child: Container(
        constraints: BoxConstraints(minHeight: height, minWidth: kMinTapTarget),
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled
                ? () {
                    HapticFeedbackHelper.buttonTap();
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );

    if(expand) button = SizedBox(width: double.infinity, child: button);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: isLoading ? context.l10n.commonSeProceseaza(label) : null,
      child: ExcludeSemantics(excluding: isLoading, child: button),
    );
  }
}
