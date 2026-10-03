import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'section_header.dart';

class SelectionDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String label;
  final IconData icon;

  /// Display text per item; defaults to `toString()`. Lets the value stay a
  /// stable API code while the label is translated.
  final String Function(T item)? itemLabel;

  const SelectionDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    required this.icon,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: icon, title: label, subtitle: ''),
        Semantics(
          label: label,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: c.border, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: c.surface,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: c.textMuted, size: 20),
                style: context.text.bodyLarge,
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel?.call(item) ?? item.toString()),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
