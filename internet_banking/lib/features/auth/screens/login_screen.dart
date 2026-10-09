import '../../../theme/app_tokens.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';

import '../../../core/network/dio_client.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/phone_input_field.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';
import 'two_factor_screen.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/app_log.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  CountryWithPhoneCode? _selectedCountry;
  List<CountryWithPhoneCode> _countries = [];
  String? textEroare;
  bool _loading = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    );
    _fadeController!.forward();
    _initPhoneLib();
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

  String? _formatPhoneForServer(String phone) {
    if (_selectedCountry == null) return null;
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (_countryUsesTrunkPrefix(_selectedCountry!.countryCode) &&
        cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    final fullNumber = '+${_selectedCountry!.phoneCode}$cleanPhone';
    if (cleanPhone.length < 8 || cleanPhone.length > 15) {
      if (mounted) {
        setState(() => textEroare = context.l10n.loginLungimeaNumaruluiEsteValida);
      }
      return null;
    }
    return fullNumber;
  }

  Future<void> _attemptLogin(String fullPhoneNumber) async {
    try {
      final response = await DioClient().post(
        '/login',
        data: {'phone': fullPhoneNumber},
      );

      if (response.statusCode == 200) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;

        if (data['exists'] == true) {
          final userId = data['userId'];
          // Prove the phone first: terms, approval and PIN steps come after the SMS code,
          // with the token that verification returns.
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TwoFactorScreen(
                  phoneNumber: fullPhoneNumber,
                  userId: userId,
                ),
              ),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            setState(
              () => textEroare = context.l10n.loginNumarulTelefonApartineUnui,
            );
          }
        }
      } else {
        if (mounted) {
          setState(
            () => textEroare =
                context.l10n.loginEroareComunicareaServerulCod(response.statusCode ?? 0),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => textEroare =
              context.l10n.loginPotiConectaServerVerifica,
        );
      }
      AppLog.debug('Eroare _attemptLogin', e);
    }
  }

  Future<void> _login() async {
    if (_selectedCountry == null) return;
    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw.isEmpty) {
      setState(() => textEroare = context.l10n.loginIntroduNumarulTelefon);
      return;
    }

    final fullPhoneNumber = _formatPhoneForServer(phoneRaw);
    if (fullPhoneNumber == null) {
      setState(() => textEroare = context.l10n.loginNumarulTelefonEsteValid);
      return;
    }

    setState(() {
      textEroare = null;
      _loading = true;
    });

    await _attemptLogin(fullPhoneNumber);
    if (mounted) setState(() => _loading = false);
  }

  bool _countryUsesTrunkPrefix(String countryCode) {
    const trunkPrefixCountries = {
      'RO', 'DE', 'GB', 'FR', 'IT', 'ES', 'PL', 'AT', 'CH',
      'BE', 'NL', 'PT', 'GR', 'DK', 'SE', 'NO', 'FI', 'IE',
      'CZ', 'HU', 'SK', 'BG', 'HR', 'SI', 'LT', 'LV', 'EE',
      'LU', 'MT', 'CY', 'BA', 'RS', 'ME', 'MK', 'AL', 'XK',
      'IN', 'PK', 'BD', 'LK', 'MY', 'SG', 'TH', 'ID', 'PH',
      'VN', 'MM', 'KH', 'LA', 'NP', 'BT', 'MV', 'ZA', 'EG',
      'NG', 'KE', 'GH', 'UG', 'TZ', 'ET', 'MA', 'DZ', 'TN',
      'LY', 'SD', 'ZW', 'ZM', 'MW', 'PS', 'AU', 'NZ',
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

  @override
  void dispose() {
    _fadeController?.dispose();
    _phoneController.dispose();
    super.dispose();
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
            color: Color(0x4D00695C),
            blurRadius: 25,
            offset: Offset(0, 10),
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
                    color: context.colors.brand.withValues(alpha: 0.1),
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
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: context.l10n.loginConectare,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _fadeAnimation != null
                    ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Column(
                          children: [
                            const SizedBox(height: 90),
                            _buildPhoneIcon(),
                            const SizedBox(height: 54),
                            PageTitle(
                              title: context.l10n.loginIntroduNumarulTelefon,
                              subtitle:
                                  context.l10n.loginRugamSaIntroduciNumarul,
                            ),
                            const SizedBox(height: 48),
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
                                      setState(() {
                                        _selectedCountry = newCountry;
                                        _phoneController.clear();
                                      });
                                    }
                                  },
                                  formatAsYouType: _formatAsYouType,
                                  onSubmitted: (_) {
                                    if (!_loading) _login();
                                  },
                                  hintText: _countries.isEmpty
                                      ? context.l10n.commonIncarcare
                                      : _getHintForCountry(),
                                ),
                              ],
                            ),
                            if (textEroare != null) ...[
                              const SizedBox(height: 20),
                              ErrorBanner(message: textEroare!),
                            ],
                            const SizedBox(height: 48),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: AppButton(
                label: context.l10n.commonConfirma,
                onPressed: _login,
                isLoading: _loading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}