import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/phone_input_field.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../onboarding/screens/tos_screen.dart';
import '../../onboarding/screens/approval_screen.dart';
import 'two_factor_screen.dart';

final FlutterSecureStorage storage = const FlutterSecureStorage();

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

  http.Client _createHttpClient() {
    return IOClient(HttpClient());
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
        setState(() => textEroare = 'Lungimea numărului nu este validă');
      }
      return null;
    }
    return fullNumber;
  }

  Future<void> _attemptLogin(String fullPhoneNumber) async {
    final client = _createHttpClient();
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/login');
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': fullPhoneNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['exists'] == true) {
          final userId = data['userId'];
          final isApproved = data['approved'] == true;
          final hasTOS = data['acceptedterms'] == true;

          if (!hasTOS) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => TosScreen(userId: userId)),
                (route) => false,
              );
            }
          } else if (isApproved) {
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => ApprovalScreen(userId: userId),
                ),
                (route) => false,
              );
            }
          }
        } else {
          if (mounted) {
            setState(
              () => textEroare = 'Numărul de telefon nu aparține unui client',
            );
          }
        }
      } else {
        if (mounted) {
          setState(
            () => textEroare =
                'Eroare la comunicarea cu serverul (cod: ${response.statusCode})',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => textEroare =
              'Nu te poți conecta la server. Verifică conexiunea la internet',
        );
      }
      debugPrint('Eroare _attemptLogin: $e');
    } finally {
      client.close();
    }
  }

  Future<void> _login() async {
    if (_selectedCountry == null) return;
    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw.isEmpty) {
      setState(() => textEroare = 'Introdu numărul de telefon');
      return;
    }

    final fullPhoneNumber = _formatPhoneForServer(phoneRaw);
    if (fullPhoneNumber == null) {
      setState(() => textEroare = 'Numărul de telefon nu este valid');
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(lightForestGreenColor),
            Color(darkForestGreenColor),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: 'Conectare',
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
                            const PageTitle(
                              title: 'Introdu numărul de telefon',
                              subtitle:
                                  'Te rugăm să introduci numărul declarat băncii',
                            ),
                            const SizedBox(height: 48),
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
                                      setState(() {
                                        _selectedCountry = newCountry;
                                        _phoneController.clear();
                                      });
                                    }
                                  },
                                  formatAsYouType: _formatAsYouType,
                                  hintText: _countries.isEmpty
                                      ? 'Încărcare...'
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
              child: ActionButton(
                label: 'Confirmă',
                onTap: _loading ? null : _login,
                isLoading: _loading,
                isExpanded: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}