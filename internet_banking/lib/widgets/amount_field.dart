import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// The amount of a payment, large and centred like in Revolut or BT Pay: the number is
/// what the customer cares about, so it gets the room. Still an ordinary text field
/// (keyboard, formatter, validation message) with its [label] above it.
class AmountField extends StatelessWidget
{
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.errorText,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? errorText;

  /// Shown under the field while there is no error (e.g. the available balance).
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final hasError = errorText != null;
    final big = context.text.displaySmall!.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: hasError ? c.danger : Colors.transparent, width: 1.5),
      ),
      child: Column(
        children: [
          Text(label, style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: textInputAction,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: inputFormatters,
            textAlign: TextAlign.center,
            style: big,
            cursorColor: c.brand,
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: big.copyWith(color: c.textMuted),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              constraints: const BoxConstraints(minHeight: 56),
            ),
          ),
          if(hasError || helper != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: hasError,
              child: Text(
                errorText ?? helper!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: hasError ? c.danger : c.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
