import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../config/app_config.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/circular_icon_badge.dart';
import '../../../widgets/date_picker_field.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/form_text_field.dart';
import '../../../widgets/phone_input_field.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../widgets/review_item_row.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/selection_dropdown.dart';
import '../../../widgets/step_indicator.dart';
import '../../onboarding/screens/approval_screen.dart';
import '../../onboarding/screens/tos_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
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
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController.forward();
    _initPhoneLib();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cnpController.dispose();
    super.dispose();
  }

  Future<void> _initPhoneLib() async {
    await init();
    _countries = CountryManager().countries;
    _selectedCountry = _countries.firstWhere(
      (c) => c.countryCode == 'RO',
      orElse: () => _countries.first,
    );
    if (mounted) setState(() {});
  }

  http.Client _createHttpClient() {
    return IOClient(HttpClient());
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => textEroare = message);
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _register() async {
    if (_selectedCountry == null) return;
    setState(() => _loading = true);
    _showError('');

    final phoneRaw = _phoneController.text.trim();
    String cleanPhone = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    final fullPhone = '+${_selectedCountry!.phoneCode}$cleanPhone';

    final client = _createHttpClient();
    try {
      final dob = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : '';

      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/register'),
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userId = data['userId'];
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => TosScreen(userId: userId),
            ),
            (route) => false,
          );
        }
      } else if (response.statusCode == 409) {
        final userId = data['userId'];
        if (userId != null) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => ApprovalScreen(userId: userId),
              ),
              (route) => false,
            );
          }
        } else {
          _showError(data['error'] ?? 'Contul există deja');
        }
      } else {
        _showError(data['error'] ?? 'Eroare la înregistrare');
      }
    } catch (e) {
      _showError('Nu te poți conecta la server. Verifică conexiunea');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _countryUsesTrunkPrefix(String countryCode) {
    const trunkPrefixCountries = {
      'RO', 'DE', 'GB', 'FR', 'IT', 'ES', 'PL', 'AT', 'CH', 'BE', 'NL',
      'PT', 'GR', 'DK', 'SE', 'NO', 'FI', 'IE', 'CZ', 'HU', 'SK', 'BG',
      'HR', 'SI', 'LT', 'LV', 'EE', 'LU', 'MT', 'CY', 'BA', 'RS', 'ME',
      'MK', 'AL', 'XK', 'IN', 'PK', 'BD', 'LK', 'MY', 'SG', 'TH', 'ID',
      'PH', 'VN', 'MM', 'KH', 'LA', 'NP', 'BT', 'MV', 'ZA', 'EG', 'NG',
      'KE', 'GH', 'UG', 'TZ', 'ET', 'MA', 'DZ', 'TN', 'LY', 'SD', 'ZW',
      'ZM', 'MW', 'PS', 'AU', 'NZ',
    };
    return trunkPrefixCountries.contains(countryCode);
  }

  String _getHintForCountry() {
    if (_selectedCountry == null) return '712 345 678';
    final countryCode = _selectedCountry!.countryCode;
    final example = _selectedCountry!.exampleNumberMobileNational;
    if (_countryUsesTrunkPrefix(countryCode)) {
      String hint = example.replaceAll(RegExp(r'[^\d\s]'), '');
      if (hint.startsWith('0')) hint = hint.substring(1).trim();
      return hint.isEmpty ? '712 345 678' : hint;
    }
    return example.replaceAll(RegExp(r'[^\d\s]'), '').trim();
  }

  String _formatAsYouType(String input) {
    if (_selectedCountry == null) return input;
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (_countryUsesTrunkPrefix(_selectedCountry!.countryCode) &&
        digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (_selectedCountry!.countryCode == 'RO') {
      if (digits.length <= 3) {
        return digits;
      }
      if (digits.length <= 6) {
        return '${digits.substring(0, 3)} ${digits.substring(3)}';
      }
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    if (digits.length <= 3) {
      return digits;
    }
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    if (digits.length <= 9) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
  }

  // ───────────────────── Page builders ─────────────────────

  Widget _buildPhonePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          _buildPhoneIcon(),
          const SizedBox(height: 40),
          const PageTitle(
            title: 'Verificare număr',
            subtitle: 'Introdu numărul tău de telefon',
          ),
          const SizedBox(height: 40),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.phone_outlined,
                title: 'Număr de telefon',
                subtitle: '',
              ),
              PhoneInputField(
                controller: _phoneController,
                countries: _countries,
                selectedCountry: _selectedCountry,
                onCountryChanged: (newCountry) {
                  if (newCountry != null) {
                    setState(() => _selectedCountry = newCountry);
                  }
                },
                formatAsYouType: _formatAsYouType,
                hintText: _countries.isEmpty
                    ? 'Încărcare...'
                    : _getHintForCountry(),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPhoneIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(lightForestGreenColor),
            Color(darkForestGreenColor),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(lightForestGreenColor).withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(lightForestGreenColor),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(lightForestGreenColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.phone,
                      size: 16,
                      color: Color(lightForestGreenColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDataPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircularIconBadge(
            icon: Icons.person_outline_rounded,
            size: 100,
          ),
          const SizedBox(height: 32),
          const PageTitle(
            title: 'Date personale',
            subtitle: 'Completează datele tale',
          ),
          const SizedBox(height: 32),
          FormTextField(
            controller: _firstNameController,
            label: 'Prenume',
            icon: Icons.person_outline,
            hint: 'Introdu prenumele',
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _lastNameController,
            label: 'Nume',
            icon: Icons.person_outline,
            hint: 'Introdu numele',
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            hint: 'email@exemplu.ro',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          DatePickerField(
            selectedDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 16),
          SelectionDropdown<String>(
            value: _selectedGender,
            items: const ['Masculin', 'Feminin'],
            onChanged: (value) {
              if (value != null) setState(() => _selectedGender = value);
            },
            label: 'Gen',
            icon: Icons.wc_outlined,
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _cnpController,
            label: 'CNP',
            icon: Icons.badge_outlined,
            hint: '123 456 789 012 3',
            maxLength: 16,
          ),
          const SizedBox(height: 16),
          SelectionDropdown<String>(
            value: _selectedMaritalStatus,
            items: const ['Necăsătorit', 'Căsătorit', 'Divorțat'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMaritalStatus = value);
              }
            },
            label: 'Stare civilă',
            icon: Icons.favorite_outline_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircularIconBadge(
            icon: Icons.checklist_rounded,
            size: 100,
          ),
          const SizedBox(height: 32),
          const PageTitle(
            title: 'Confirmare date',
            subtitle: 'Verifică datele introduse',
          ),
          const SizedBox(height: 32),
          ReviewItemRow(label: 'Telefon', value: _phoneController.text),
          ReviewItemRow(label: 'Prenume', value: _firstNameController.text),
          ReviewItemRow(label: 'Nume', value: _lastNameController.text),
          ReviewItemRow(label: 'Email', value: _emailController.text),
          if (_selectedDate != null)
            ReviewItemRow(
              label: 'Data nașterii',
              value:
                  '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            ),
          ReviewItemRow(label: 'Gen', value: _selectedGender),
          ReviewItemRow(label: 'CNP', value: _cnpController.text),
          ReviewItemRow(
              label: 'Stare civilă', value: _selectedMaritalStatus),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ───────────────────── Build ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: 'Înregistrare',
              onBack: () => Navigator.pop(context),
            ),
            StepIndicator(currentStep: _currentStep),
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
            if (textEroare != null) ErrorBanner(message: textEroare!),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  if (_currentStep > 0 && _currentStep < 2)
                    ActionButton(
                      label: 'Înapoi',
                      onTap: _previousStep,
                      variant: ActionButtonVariant.secondary,
                    ),
                  if (_currentStep < 2)
                    ActionButton(
                      label: 'Continuă',
                      onTap: _nextStep,
                    ),
                  if (_currentStep == 2)
                    ActionButton(
                      label: 'Confirmă înregistrarea',
                      onTap: _loading ? null : _register,
                      isLoading: _loading,
                      variant: ActionButtonVariant.primary,
                      isExpanded: false,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}