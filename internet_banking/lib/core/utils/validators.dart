// lib/core/utils/validators.dart
// Form validation utilities

/// Validates Romanian CNP (13 digits, checksum).
bool validateCNP(String cnp) {
  if (cnp.length != 13) return false;
  if (!RegExp(r'^\d{13}').hasMatch(cnp)) return false;

  final digits = cnp.split('').map(int.parse).toList();

  final s = digits[0];
  if (s < 1 || s > 8) return false;

  final aa = int.parse(cnp.substring(1, 3));
  final ll = int.parse(cnp.substring(3, 5));
  final zz = int.parse(cnp.substring(5, 7));

  int year;
  if (s == 1 || s == 2) {
    year = 1900 + aa;
  } else if (s == 3 || s == 4) {
    year = 1800 + aa;
  } else if (s == 5 || s == 6) {
    year = 2000 + aa;
  } else {
    // s == 7 || s == 8
    year = 1900 + aa;
  }

  if (ll < 1 || ll > 12) return false;
  try {
    final date = DateTime(year, ll, zz);
    if (date.year != year || date.month != ll || date.day != zz) return false;
  } catch (_) {
    return false;
  }

  final jj = cnp.substring(7, 9);
  final validJudetCodes = <String>{
    '01', '02', '03', '04', '05', '06', '07', '08', '09', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
    '31', '32', '33', '34', '35', '36', '37', '38', '39', '40',
    '41', '42', '43', '44', '45', '46', '47', '48', '51', '52', '70',
  };
  if (!validJudetCodes.contains(jj)) return false;

  final nnn = int.parse(cnp.substring(9, 12));
  if (nnn < 1 || nnn > 999) return false;

  final weights = '279146358279'.split('').map(int.parse).toList();
  int sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += digits[i] * weights[i];
  }
  final remainder = sum % 11;
  final control = remainder < 10 ? remainder : 1;
  if (control != digits[12]) return false;

  return true;
}

/// Validates an email address format.
bool validateEmail(String email) {
  final cleaned = email.trim().replaceAll(
    RegExp(r'[\u200B-\u200D\uFEFF]'),
    '',
  );
  final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}");
  return emailRegex.hasMatch(cleaned);
}

/// Validates a phone number length (digits only, after country code).
bool validatePhoneLength(String cleanDigits) {
  return cleanDigits.length >= 8 && cleanDigits.length <= 15;
}

/// Checks if the person is at least 18 years old based on birth date.
bool isAtLeast18(DateTime birthDate) {
  final now = DateTime.now();
  final cutoff = DateTime(now.year - 18, now.month, now.day);
  return !birthDate.isAfter(cutoff);
}

/// Extracts the gender from the first digit of CNP.
String? genderFromCNP(String cnp) {
  if (cnp.isEmpty) return null;
  final s = int.parse(cnp[0]);
  if (s == 1 || s == 3 || s == 5 || s == 7) return 'M';
  if (s == 2 || s == 4 || s == 6 || s == 8) return 'F';
  return null;
}

/// Extracts birth date from CNP and returns it as DateTime.
DateTime? birthDateFromCNP(String cnp) {
  if (cnp.length != 13) return null;
  final s = int.parse(cnp[0]);
  final aa = int.parse(cnp.substring(1, 3));
  final ll = int.parse(cnp.substring(3, 5));
  final zz = int.parse(cnp.substring(5, 7));

  int year;
  if (s == 1 || s == 2) {
    year = 1900 + aa;
  } else if (s == 3 || s == 4) {
    year = 1800 + aa;
  } else if (s == 5 || s == 6) {
    year = 2000 + aa;
  } else {
    year = 1900 + aa;
  }

  try {
    return DateTime(year, ll, zz);
  } catch (_) {
    return null;
  }
}
