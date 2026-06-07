// lib/features/auth/screens/login_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:convert';
import 'dart:io' show HttpClient, X509Certificate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';
import '../../../core/utils/helpers.dart';
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
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
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
      final uri = Uri.parse('https://$serverUrl/login');
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
    const trunkPrefixCountries = [
      'RO', 'DE', 'GB', 'FR', 'IT', 'ES', 'PL', 'AT', 'CH',
      'BE', 'NL', 'PT', 'GR', 'DK', 'SE', 'NO', 'FI', 'IE',
      'CZ', 'HU', 'SK', 'BG', 'HR', 'SI', 'LT', 'LV', 'EE',
      'LU', 'MT', 'CY', 'BA', 'RS', 'ME', 'MK', 'AL', 'XK',
      'IN', 'PK', 'BD', 'LK', 'MY', 'SG', 'TH', 'ID', 'PH',
      'VN', 'MM', 'KH', 'LA', 'NP', 'BT', 'MV', 'ZA', 'EG',
      'NG', 'KE', 'GH', 'UG', 'TZ', 'ET', 'MA', 'DZ', 'TN',
      'LY', 'SD', 'ZW', 'ZM', 'MW', 'PS', 'AU', 'NZ',
    ];
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

  int _getMaxLengthForCountry() {
    final hint = _getHintForCountry();
    return hint.length;
  }

  String _formatAsYouType(String input) {
    if (_selectedCountry == null) return input;
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (_countryUsesTrunkPrefix(_selectedCountry!.countryCode) &&
        digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (_selectedCountry!.countryCode == 'RO') {
      if (digits.length <= 3) return digits;
      if (digits.length <= 6) {
        return '${digits.substring(0, 3)} ${digits.substring(3)}';
      }
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    if (digits.length <= 3) return digits;
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

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(lightForestGreenColor),
              Color(lightForestGreenColor).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(lightForestGreenColor).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _login,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirmă',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    if (_countries.isEmpty) {
      return Container(
        width: 110,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CountryWithPhoneCode>(
          value: _selectedCountry,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[400],
            size: 14,
          ),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
          items: _countries.map((country) {
            return DropdownMenuItem<CountryWithPhoneCode>(
              value: country,
              child: Row(
                children: [
                  Text(
                    countryCodeToEmoji(country.countryCode),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${country.phoneCode}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (CountryWithPhoneCode? newCountry) {
            if (newCountry != null) {
              setState(() {
                _selectedCountry = newCountry;
                _phoneController.clear();
              });
            }
          },
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(darkGreyColor),
                  ),
                  Text(
                    'Conectare',
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: const Color(darkGreyColor),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
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
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(lightForestGreenColor), Color(darkForestGreenColor)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(lightForestGreenColor).withOpacity(0.3),
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
                                    border: Border.all(color: Color(lightForestGreenColor), width: 2),
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
                                            color: Color(lightForestGreenColor).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Center(
                                            child: Icon(Icons.phone, size: 16, color: Color(lightForestGreenColor)),
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
                            ),
                            const SizedBox(height: 54),
                            Text(
                              'Introdu numărul de telefon',
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: const Color(darkGreyColor),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Te rugăm să introduci numărul declarat băncii',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 48),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 6, bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Număr de telefon',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCountryDropdown(),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                                            TextInputFormatter.withFunction((oldValue, newValue) {
                                              final formatted = _formatAsYouType(newValue.text);
                                              return TextEditingValue(
                                                text: formatted,
                                                selection: TextSelection.collapsed(offset: formatted.length),
                                              );
                                            }),
                                            LengthLimitingTextInputFormatter(_getMaxLengthForCountry()),
                                          ],
                                          onChanged: (_) => setState(() => textEroare = null),
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
                                              borderSide: const BorderSide(color: Color(lightForestGreenColor), width: 2),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                            hintText: _countries.isEmpty ? 'Încărcare...' : _getHintForCountry(),
                                            hintStyle: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: Colors.grey[400],
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (textEroare != null)
                              Container(
                                margin: const EdgeInsets.only(top: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        textEroare!,
                                        style: GoogleFonts.inter(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }
}
