import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;
  final ValueChanged<CountryWithPhoneCode?> onCountryChanged;
  final String Function(String) formatAsYouType;
  final String hintText;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.countries,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.formatAsYouType,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CountryDropdown(
          countries: countries,
          selectedCountry: selectedCountry,
          onChanged: onCountryChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final formatted = formatAsYouType(newValue.text);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
              LengthLimitingTextInputFormatter(15),
            ],
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(darkGreyColor),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Color(lightForestGreenColor), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;
  final ValueChanged<CountryWithPhoneCode?> onChanged;

  const _CountryDropdown({
    required this.countries,
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (countries.isEmpty) {
      return Container(
        width: 110,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Container(
      width: 110,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CountryWithPhoneCode>(
          value: selectedCountry,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[400], size: 14),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
          items: countries.map((country) {
            return DropdownMenuItem<CountryWithPhoneCode>(
              value: country,
              child: Row(
                children: [
                  Text(_countryCodeToEmoji(country.countryCode),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+${country.phoneCode}',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  static String _countryCodeToEmoji(String countryCode) {
    final codePoint1 = 0x1F1E6 + countryCode.codeUnitAt(0) - 65;
    final codePoint2 = 0x1F1E6 + countryCode.codeUnitAt(1) - 65;
    return String.fromCharCodes([codePoint1, codePoint2]);
  }
}