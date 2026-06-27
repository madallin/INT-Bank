import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../config/app_config.dart';
import '../../../core/utils/helpers.dart';
import '../../onboarding/screens/approval_screen.dart';
import '../../onboarding/screens/tos_screen.dart';

class RegisterScreen extends StatefulWidget
{
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin
{
  final PageController _pageController = PageController();
  int _currentStep = 0;

  late AnimationController _fadeController;

  CountryWithPhoneCode? _selectedCountry;
  List<CountryWithPhoneCode> _countries = [];
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cnpController = TextEditingController();

  String _selectedGender = 'Masculin';
  String _selectedMaritalStatus = 'Necăsătorit';

  DateTime? _selectedDate;

  String? textEroare;
  bool _loading = false;

  @override
  void initState()
  {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController.forward();
    _initPhoneLib();
  }

  @override
  void dispose()
  {
    _fadeController.dispose();
    _pageController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cnpController.dispose();
    super.dispose();
  }

  Future<void> _initPhoneLib() async
  {
    await init();
    _countries = CountryManager().countries;
    _selectedCountry = _countries.firstWhere(
      (c) => c.countryCode == 'RO',
      orElse: () => _countries.first,
    );
    if(mounted) setState(() {});
  }

  http.Client _createHttpClient()
  {
    return IOClient(HttpClient());
  }

  void _showError(String message)
  {
    if(!mounted) return;
    setState(() => textEroare = message);
  }

  void _nextStep()
  {
    if(_currentStep < 2)
{
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep()
  {
    if(_currentStep > 0)
{
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _register() async
  {
    if(_selectedCountry == null) return;
    setState(() => _loading = true);
    _showError('');

    final phoneRaw = _phoneController.text.trim();
    String cleanPhone = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if(cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    final fullPhone = '+${_selectedCountry!.phoneCode}$cleanPhone';

    final client = _createHttpClient();
    try
    {
      final dob = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : '';

      final response = await client.post(
        Uri.parse('https://$serverUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': fullPhone,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'cnp': _cnpController.text.replaceAll(' ', ''),
          'gender': _selectedGender,
          'maritalStatus': _selectedMaritalStatus,
          'dateOfBirth': dob,
        }),
      );

      final data = jsonDecode(response.body);

      if(response.statusCode == 200 || response.statusCode == 201)
{
        final userId = data['userId'];
        if(mounted)
{
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => TosScreen(userId: userId),
            ),
            (route) => false,
          );
        }
      }
      else if(response.statusCode == 409)
{
        final userId = data['userId'];
        if(userId != null)
{
          if(mounted)
{
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => ApprovalScreen(userId: userId),
              ),
              (route) => false,
            );
          }
        }
        else
{
          _showError(data['error'] ?? 'Contul există deja');
        }
      }
      else
{
        _showError(data['error'] ?? 'Eroare la înregistrare');
      }
    }
    catch(e)
{
      _showError('Nu te poți conecta la server. Verifică conexiunea');
    }
    finally
    {
      client.close();
      if(mounted) setState(() => _loading = false);
    }
  }

  bool _countryUsesTrunkPrefix(String countryCode)
  {
    const trunkPrefixCountries = ['RO', 'DE', 'GB', 'FR', 'IT', 'ES', 'PL', 'AT', 'CH', 'BE', 'NL', 'PT', 'GR', 'DK', 'SE', 'NO', 'FI', 'IE', 'CZ', 'HU', 'SK', 'BG', 'HR', 'SI', 'LT', 'LV', 'EE', 'LU', 'MT', 'CY', 'BA', 'RS', 'ME', 'MK', 'AL', 'XK', 'IN', 'PK', 'BD', 'LK', 'MY', 'SG', 'TH', 'ID', 'PH', 'VN', 'MM', 'KH', 'LA', 'NP', 'BT', 'MV', 'ZA', 'EG', 'NG', 'KE', 'GH', 'UG', 'TZ', 'ET', 'MA', 'DZ', 'TN', 'LY', 'SD', 'ZW', 'ZM', 'MW', 'PS', 'AU', 'NZ'];
    return trunkPrefixCountries.contains(countryCode);
  }

  String _getHintForCountry()
  {
    if(_selectedCountry == null) return '712 345 678';
    final countryCode = _selectedCountry!.countryCode;
    final example = _selectedCountry!.exampleNumberMobileNational;
    if(_countryUsesTrunkPrefix(countryCode))
{
      String hint = example.replaceAll(RegExp(r'[^\d\s]'), '');
      if(hint.startsWith('0')) hint = hint.substring(1).trim();
      return hint.isEmpty ? '712 345 678' : hint;
    }
    return example.replaceAll(RegExp(r'[^\d\s]'), '').trim();
  }

  String _formatAsYouType(String input)
  {
    if(_selectedCountry == null) return input;
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if(_countryUsesTrunkPrefix(_selectedCountry!.countryCode) && digits.startsWith('0'))
{
      digits = digits.substring(1);
    }
    if(_selectedCountry!.countryCode == 'RO')
{
      if(digits.length <= 3) return digits;
      if(digits.length <= 6) return '${digits.substring(0, 3)} ${digits.substring(3)}';
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    if(digits.length <= 3) return digits;
    if(digits.length <= 6) return '${digits.substring(0, 3)} ${digits.substring(3)}';
    if(digits.length <= 9) return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
  }

  Widget _buildStepIndicator()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: List.generate(3, (index)
        {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive ? const Color(lightForestGreenColor) : Colors.grey[300],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhonePage()
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
              ),
            ),
            child: const Icon(Icons.phone_android_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text('Verificare număr', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor))),
          const SizedBox(height: 12),
          Text('Introdu numărul tău de telefon', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 40),
          _buildPhoneField(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPersonalDataPage()
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
              ),
            ),
            child: const Icon(Icons.person_outline_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text('Date personale', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor))),
          const SizedBox(height: 8),
          Text('Completează datele tale', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildTextField(controller: _firstNameController, label: 'Prenume', icon: Icons.person_outline, hint: 'Introdu prenumele'),
          const SizedBox(height: 16),
          _buildTextField(controller: _lastNameController, label: 'Nume', icon: Icons.person_outline, hint: 'Introdu numele'),
          const SizedBox(height: 16),
          _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email_outlined, hint: 'email@exemplu.ro', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildGenderDropdown(),
          const SizedBox(height: 16),
          _buildTextField(controller: _cnpController, label: 'CNP', icon: Icons.badge_outlined, hint: '123 456 789 012 3', maxLength: 16),
          const SizedBox(height: 16),
          _buildMaritalStatusDropdown(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewPage()
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
              ),
            ),
            child: const Icon(Icons.checklist_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text('Confirmare date', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor))),
          const SizedBox(height: 8),
          Text('Verifică datele introduse', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildReviewItem('Telefon', _phoneController.text),
          _buildReviewItem('Prenume', _firstNameController.text),
          _buildReviewItem('Nume', _lastNameController.text),
          _buildReviewItem('Email', _emailController.text),
          if(_selectedDate != null) _buildReviewItem('Data nașterii',
              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
          _buildReviewItem('Gen', _selectedGender),
          _buildReviewItem('CNP', _cnpController.text),
          _buildReviewItem('Stare civilă', _selectedMaritalStatus),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)))),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  })
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280), letterSpacing: 0.3)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(lightForestGreenColor), width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField()
  {
    return Column(
      children: [
        Row(
          children: [
            _buildCountryDropdown(),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                  TextInputFormatter.withFunction((oldValue, newValue)
                  {
                    final formatted = _formatAsYouType(newValue.text);
                    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                  }),
                  LengthLimitingTextInputFormatter(15),
                ],
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
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
                    borderSide: const BorderSide(color: Color(lightForestGreenColor), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  hintText: _countries.isEmpty ? 'Încărcare...' : _getHintForCountry(),
                  hintStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountryDropdown()
  {
    if(_countries.isEmpty)
{
      return Container(
        width: 110,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
        ),
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
          value: _selectedCountry,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 14),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
          items: _countries.map((country)
          {
            return DropdownMenuItem<CountryWithPhoneCode>(
              value: country,
              child: Row(
                children: [
                  Text(countryCodeToEmoji(country.countryCode), style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+${country.phoneCode}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (CountryWithPhoneCode? newCountry)
          {
            if(newCountry != null) setState(() => _selectedCountry = newCountry);
          },
        ),
      ),
    );
  }

  Widget _buildDateField()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text('Data nașterii', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async
          {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 6570)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child)
              {
                return Theme(data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(primary: Color(lightForestGreenColor)),
                ), child: child!);
              },
            );
            if(date != null) setState(() => _selectedDate = date);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: Text(
              _selectedDate != null
                  ? '${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}'
                  : 'Selectează data',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: _selectedDate != null ? const Color(darkGreyColor) : Colors.grey[400],
                fontWeight: _selectedDate != null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.wc_outlined, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text('Gen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
              items: ['Masculin', 'Feminin'].map((g)
              {
                return DropdownMenuItem<String>(value: g, child: Text(g));
              }).toList(),
              onChanged: (value)
              {
                if(value != null) setState(() => _selectedGender = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaritalStatusDropdown()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.favorite_outline_rounded, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text('Stare civilă', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMaritalStatus,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
              items: ['Necăsătorit', 'Căsătorit', 'Divorțat', 'Văduv'].map((s)
              {
                return DropdownMenuItem<String>(value: s, child: Text(s));
              }).toList(),
              onChanged: (value)
              {
                if(value != null) setState(() => _selectedMaritalStatus = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton(bool isNext)
  {
    final label = isNext ? 'Continuă' : 'Înapoi';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 50,
          decoration: BoxDecoration(
            gradient: isNext
                ? LinearGradient(colors: [const Color(lightForestGreenColor), const Color(lightForestGreenColor).withOpacity(0.8)])
                : null,
            color: isNext ? null : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            boxShadow: isNext
                ? [BoxShadow(color: const Color(lightForestGreenColor).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isNext ? _nextStep : _previousStep,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: Text(label, style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isNext ? Colors.white : const Color(darkGreyColor),
                )),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(lightForestGreenColor), const Color(lightForestGreenColor).withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(lightForestGreenColor).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _register,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Confirmă înregistrarea', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(darkGreyColor),
                  ),
                  Text('Înregistrare', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                ],
              ),
            ),
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPhonePage(),
                  _buildPersonalDataPage(),
                  _buildReviewPage(),
                ],
              ),
            ),
            if(textEroare != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(textEroare!, style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  if(_currentStep > 0 && _currentStep < 2) _buildNavigationButton(false),
                  if(_currentStep < 2) _buildNavigationButton(true),
                  if(_currentStep == 2) _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
