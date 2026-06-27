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
