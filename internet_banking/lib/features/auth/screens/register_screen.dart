import '../../../theme/app_tokens.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:dio/dio.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/network/dio_client.dart';
import '../../../widgets/app_button.dart';
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
import '../../../l10n/l10n.dart';

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

  // Values are what the backend stores; labels are translated for display.
  String _selectedGender = 'Masculin';
  String _selectedMaritalStatus = 'Necăsătorit';

  String _genderLabel(String value) => switch (value) {
        'Feminin' => context.l10n.registerFeminin,
        _ => context.l10n.registerMasculin,
      };

  String _maritalLabel(String value) => switch (value) {
        'Căsătorit' => context.l10n.registerCasatorit,
        'Divorțat' => context.l10n.registerDivortat,
        _ => context.l10n.registerNecasatorit,
      };

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

    try {
      final dob = _selectedDate != null
          ? formatApiDate(_selectedDate!)
          : '';

      final response = await DioClient().post(
        '/register',
        options: Options(validateStatus: (status) => status != null && (status < 300 || status == 409)),
        data: {
          'phone': fullPhone,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'cnp': _cnpController.text.replaceAll(' ', ''),
          'gender': _selectedGender,
          'maritalStatus': _selectedMaritalStatus,
          'dateOfBirth': dob,
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

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
          _showError(data['error'] ?? AppL10n.current.registerContulExistaDeja);
        }
      } else {
        _showError(data['error'] ?? AppL10n.current.registerEroareInregistrare);
      }
    } catch (e) {
      _showError(AppL10n.current.registerPotiConectaServerVerifica);
    } finally {
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
          PageTitle(
            title: context.l10n.registerVerificareNumar,
            subtitle: context.l10n.registerIntroduNumarulTauTelefon,
          ),
          const SizedBox(height: 40),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.phone_outlined,
                title: context.l10n.commonNumarTelefon,
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
                    ? context.l10n.commonIncarcare
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.heroStart,
            context.colors.heroEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brand.withOpacity(0.3),
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
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colors.brand,
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
                  color: context.colors.textMuted,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.phone,
                      size: 16,
                      color: context.colors.brand,
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
                  border: Border.all(color: context.colors.textMuted, width: 1.5),
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
          PageTitle(
            title: context.l10n.registerDatePersonale,
            subtitle: context.l10n.registerCompleteazaDateleTale,
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Column(
              children: [
                FormTextField(
                  controller: _firstNameController,
                  label: context.l10n.registerPrenume,
                  icon: Icons.person_outline,
                  hint: context.l10n.registerIntroduPrenumele,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                ),
                const SizedBox(height: 16),
                FormTextField(
                  controller: _lastNameController,
                  label: context.l10n.registerNume,
                  icon: Icons.person_outline,
                  hint: context.l10n.registerIntroduNumele,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                ),
                const SizedBox(height: 16),
                FormTextField(
                  controller: _emailController,
                  label: context.l10n.registerEmail,
                  icon: Icons.email_outlined,
                  hint: context.l10n.registerEmailExempluRo,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                ),
              ],
            ),
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
            itemLabel: _genderLabel,
            onChanged: (value) {
              if (value != null) setState(() => _selectedGender = value);
            },
            label: context.l10n.registerGen,
            icon: Icons.wc_outlined,
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _cnpController,
            label: context.l10n.registerCnp,
            icon: Icons.badge_outlined,
            hint: '123 456 789 012 3',
            maxLength: 16,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          SelectionDropdown<String>(
            value: _selectedMaritalStatus,
            items: const ['Necăsătorit', 'Căsătorit', 'Divorțat'],
            itemLabel: _maritalLabel,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMaritalStatus = value);
              }
            },
            label: context.l10n.registerStareCivila,
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
          PageTitle(
            title: context.l10n.registerConfirmareDate,
            subtitle: context.l10n.registerVerificaDateleIntroduse,
          ),
          const SizedBox(height: 32),
          ReviewItemRow(label: context.l10n.registerTelefon, value: _phoneController.text),
          ReviewItemRow(label: context.l10n.registerPrenume, value: _firstNameController.text),
          ReviewItemRow(label: context.l10n.registerNume, value: _lastNameController.text),
          ReviewItemRow(label: context.l10n.registerEmail, value: _emailController.text),
          if (_selectedDate != null)
            ReviewItemRow(
              label: context.l10n.commonDataNasterii,
              value: formatDate(_selectedDate!),
            ),
          ReviewItemRow(label: context.l10n.registerGen, value: _genderLabel(_selectedGender)),
          ReviewItemRow(label: context.l10n.registerCnp, value: _cnpController.text),
          ReviewItemRow(
              label: context.l10n.registerStareCivila, value: _maritalLabel(_selectedMaritalStatus)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ───────────────────── Build ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: context.l10n.registerInregistrare,
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
                  if (_currentStep > 0 && _currentStep < 2) ...[
                    Expanded(
                      child: AppButton(
                        label: context.l10n.commonInapoi,
                        onPressed: _previousStep,
                        variant: AppButtonVariant.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (_currentStep < 2)
                    Expanded(
                      child: AppButton(
                        label: context.l10n.registerContinua,
                        onPressed: _nextStep,
                      ),
                    ),
                  if (_currentStep == 2)
                    Expanded(
                      child: AppButton(
                        label: context.l10n.registerConfirmaInregistrarea,
                        onPressed: _register,
                        isLoading: _loading,
                      ),
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