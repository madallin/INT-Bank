import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../core/utils/helpers.dart';

class CountryDropdown extends StatelessWidget {
  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;
  final ValueChanged<CountryWithPhoneCode?> onChanged;

  const CountryDropdown({
    super.key,
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
                  Text(countryCodeToEmoji(country.countryCode),
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
}