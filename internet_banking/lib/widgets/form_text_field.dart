import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'section_header.dart';

/// Labelled text input used by the app's forms. Borders, fill and hint style
/// come from the theme's `InputDecorationTheme`.
class FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Inline validation message shown under the field.
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const FormTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Merged so screen readers announce the visible label with the field.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: icon, title: label, subtitle: ''),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            textCapitalization: textCapitalization,
            style: context.text.bodyLarge,
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              errorText: errorText,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
