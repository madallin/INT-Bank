import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../theme/app_tokens.dart';
import 'section_header.dart';
import '../l10n/l10n.dart';

class DatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  /// Defaults to "date of birth".
  final String? label;
  final IconData icon;

  const DatePickerField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.label,
    this.icon = Icons.calendar_today_outlined,
  });

  Future<void> _selectDate(BuildContext context) async {
    // The picker inherits colours from the app theme.
    final date = await showDatePicker(
      context: context,
      initialDate:
          selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDate = selectedDate != null;
    final radius = BorderRadius.circular(AppRadii.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: icon, title: label ?? context.l10n.commonDataNasterii, subtitle: ''),
        Semantics(
          button: true,
          label: '${label ?? context.l10n.commonDataNasterii}: ${hasDate ? formatDate(selectedDate!) : context.l10n.commonNeselectata}',
          excludeSemantics: true,
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: c.border, width: 1.5),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: () => _selectDate(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Text(
                  hasDate ? formatDate(selectedDate!) : context.l10n.commonSelecteazaData,
                  style: context.text.bodyLarge?.copyWith(
                    color: hasDate ? c.textPrimary : c.textMuted,
                    fontWeight: hasDate ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
