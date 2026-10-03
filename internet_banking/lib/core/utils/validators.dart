class Validators
{
  static String? validateIBAN(String? value)
  {
    if(value == null || value.isEmpty) return 'IBAN is required';
    final cleaned = value.replaceAll(' ', '');
    if(cleaned.length < 16 || cleaned.length > 34)
{
      return 'IBAN must be between 16 and 34 characters';
    }
    if(!RegExp(r'^[A-Z]{2}[0-9A-Z]+$').hasMatch(cleaned.toUpperCase())) {
      return 'Invalid IBAN format';
    }
    return null;
  }

  static String? validateEmail(String? value)
  {
    if(value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if(!emailRegex.hasMatch(value)) return 'Invalid email address';
    return null;
  }

  static String? validatePhone(String? value)
  {
    if(value == null || value.isEmpty) return 'Phone number is required';
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if(cleaned.length < 8 || cleaned.length > 15)
{
      return 'Phone number must be between 8 and 15 digits';
    }
    return null;
  }

  static String? validatePin(String? value)
  {
    if(value == null || value.isEmpty) return 'PIN is required';
    if(value.length != 6) return 'PIN must be 6 digits';
    if(!RegExp(r'^\d{6}$').hasMatch(value)) return 'PIN must contain only digits';
    return null;
  }

  static String? validateRequired(String? value, [String fieldName = 'This field'])
  {
    if(value == null || value.trim().isEmpty)
{
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateAmount(String? value)
  {
    if(value == null || value.isEmpty) return 'Amount is required';
    final cleaned = value.replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(cleaned);
    if(amount == null || amount <= 0) return 'Amount must be greater than 0';
    return null;
  }

  static String? validateName(String? value)
  {
    if(value == null || value.isEmpty) return 'Name is required';
    final cleaned = value.trim().split(RegExp(r'\s+'));
    if(cleaned.length < 2) return 'Please enter both first and last name';
    if(value.length < 7 || value.length > 128)
{
      return 'Name must be between 7 and 128 characters';
    }
    return null;
  }

  /// Validates Romanian IBAN using ISO 7064 MOD 97-10 checksum algorithm.
  /// Romanian IBAN format: ROkk BBBB CCCC CCCC CCCC CCCC (24 chars)
  static bool isValidRomanianIban(String iban)
  {
    final cleaned = iban.replaceAll(' ', '').toUpperCase();
    if (cleaned.length != 24 || !cleaned.startsWith('RO'))
    {
      return false;
    }
    if (!RegExp(r'^RO\d{2}[A-Z]{4}[0-9A-Z]{16}$').hasMatch(cleaned))
    {
      return false;
    }

    // Move first 4 characters to end: BBBB CCCC CCCC CCCC CCCC ROkk
    final rearranged = cleaned.substring(4) + cleaned.substring(0, 4);

    // Replace letters with numbers: A=10, B=11, ..., Z=35
    final buffer = StringBuffer();
    for (int i = 0; i < rearranged.length; i++)
    {
      final code = rearranged.codeUnitAt(i);
      if (code >= 48 && code <= 57)
      {
        buffer.writeCharCode(code);
      }
      else if (code >= 65 && code <= 90)
      {
        buffer.write((code - 55).toString());
      }
      else
      {
        return false;
      }
    }

    final digits = buffer.toString();
    int remainder = 0;
    for (int i = 0; i < digits.length; i++)
    {
      final d = digits.codeUnitAt(i) - 48;
      remainder = (remainder * 10 + d) % 97;
    }

    return remainder == 1;
  }

  static String? validateRomanianIBAN(String? value)
  {
    if (value == null || value.trim().isEmpty) return 'IBAN-ul este obligatoriu';
    final cleaned = value.replaceAll(' ', '').toUpperCase();
    if (cleaned.length != 24)
    {
      return 'IBAN-ul românesc trebuie să aibă exact 24 caractere';
    }
    if (!cleaned.startsWith('RO'))
    {
      return 'IBAN-ul românesc trebuie să înceapă cu RO';
    }
    if (!isValidRomanianIban(cleaned))
    {
      return 'Cifrele de control IBAN sunt invalide (checksum incorect)';
    }
    return null;
  }

  static bool isValidCNP(String cnp)
  {
    final cleaned = cnp.replaceAll(' ', '');
    if (cleaned.length != 13 || !RegExp(r'^\d{13}$').hasMatch(cleaned)) return false;
    const weights = [2, 7, 9, 1, 4, 6, 3, 5, 8, 2, 7, 9];
    int sum = 0;
    for (int i = 0; i < 12; i++)
    {
      sum += (cleaned.codeUnitAt(i) - 48) * weights[i];
    }
    int check = sum % 11;
    if (check == 10) check = 1;
    return (cleaned.codeUnitAt(12) - 48) == check;
  }

  static String? validateCNP(String? value)
  {
    if(value == null || value.isEmpty) return 'CNP is required';
    final cleaned = value.replaceAll(' ', '');
    if(cleaned.length != 13) return 'CNP must be exactly 13 digits';
    if(!RegExp(r'^\d{13}$').hasMatch(cleaned)) return 'CNP must contain only digits';
    return null;
  }

  static String? validatePassword(String? value)
  {
    if(value == null || value.isEmpty) return 'Password is required';
    if(value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateCardNumber(String? value)
  {
    if(value == null || value.isEmpty) return 'Card number is required';
    final cleaned = value.replaceAll(' ', '');
    if(cleaned.length != 16) return 'Card number must be 16 digits';
    if(!RegExp(r'^\d{16}$').hasMatch(cleaned)) {
      return 'Card number must contain only digits';
    }
    return null;
  }
}
