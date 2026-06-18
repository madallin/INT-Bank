// lib/features/auth/screens/register_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, X509Certificate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';


import '../../../config/app_config.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/location_data.dart';
import '../../onboarding/screens/tos_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  int _currentStep = 0;

  // ---- Step 1 ----
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  String? _selectedGender;
  final TextEditingController _cnpController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _birthDate;

  // ---- Step 2 ----
  CountryWithPhoneCode? _selectedCountry;
  List<CountryWithPhoneCode> _countries = [];
  final TextEditingController _phoneController = TextEditingController();

  // ---- Step 3 ----
  final TextEditingController _emailController = TextEditingController();
  String? _selectedCounty;
  String? _selectedCity;

  // --- Step 4: Address Autocomplete (Geoapify) ---
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _blocController = TextEditingController();
  final TextEditingController _scaraController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _codPostalController = TextEditingController();

  String? _selectedPlaceId;
  // Sugestiile vin ca lista de obiecte {place_id, description}
  List<Map<String, String>> _suggestions = [];
  Timer? _debounce;
  bool _isLoadingAutocomplete = false;
  bool _addressValidated = false;
  bool _isGettingLocation = false;
  bool _showAddressDetails = false;
  String _confirmedStreet = '';

  // --- Common ---

  String? textEroare;
  bool _loading = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;

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
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeInOut,
    ));
    _slideController!.forward();
    _initPhoneLib();
    if (judete.isEmpty) loadJudete();
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

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _cnpController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _blocController.dispose();
    _scaraController.dispose();
    _apartmentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---- Step Validation ----
  bool _validateStep1() {
    if (_lastNameController.text.trim().isEmpty) {
      setState(() => textEroare = 'Introdu numele de familie');
      return false;
    }
    if (_firstNameController.text.trim().isEmpty) {
      setState(() => textEroare = 'Introdu prenumele');
      return false;
    }
    if (_selectedGender == null) {
      setState(() => textEroare = 'Selectează genul');
      return false;
    }
    final cnp = _cnpController.text.trim();
    if (cnp.isEmpty || !validateCNP(cnp)) {
      setState(() => textEroare = 'CNP-ul nu este valid');
      return false;
    }
    if (_birthDate == null) {
      setState(() => textEroare = 'Selectează data nașterii');
      return false;
    }
    if (!isAtLeast18(_birthDate!)) {
      setState(() => textEroare = 'Trebuie să ai minim 18 ani pentru a te înregistra');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => textEroare = 'Introdu numărul de telefon');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (!validateEmail(_emailController.text)) {
      setState(() => textEroare = 'Adresa de email nu este validă');
      return false;
    }
    if (_selectedCounty == null) {
      setState(() => textEroare = 'Selectează județul');
      return false;
    }
    if (_selectedCity == null) {
      setState(() => textEroare = 'Selectează localitatea');
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_streetController.text.trim().isEmpty) {
      setState(() => textEroare = 'Introdu strada');
      return false;
    }
    if (!_addressValidated) {
      setState(() => textEroare = 'Selectează o adresă validă din sugestii');
      return false;
    }
    return true;
  }

  // ---- Address Autocomplete (Google Places) ----
  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isLoadingAutocomplete = true);
    final client = _createHttpClient();
    try {
      final response = await client.get(
        Uri.parse(
          'https://$serverUrl/places/autocomplete?text=${Uri.encodeComponent(query)}&locality=${Uri.encodeComponent(_selectedCity ?? '')}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'] as List?;
        if (predictions != null) {
          setState(() {
            _suggestions = predictions.map<Map<String, String>>((p) => {
              'place_id': (p['place_id'] as String? ?? ''),
              'description': (p['description'] as String? ?? ''),
              'strada': (p['strada'] as String? ?? ''),
              'numar': (p['numar'] as String? ?? ''),
              'localitate': (p['localitate'] as String? ?? ''),
              'judet': (p['judet'] as String? ?? ''),
              'codPostal': (p['codPostal'] as String? ?? ''),
              'tara': (p['tara'] as String? ?? ''),
            }).where((m) => m['description']!.isNotEmpty).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    } finally {
      client.close();
      setState(() => _isLoadingAutocomplete = false);
    }
  }

  /// După selectarea unei sugestii, folosește detaliile adresei deja incluse în predicție.
  Future<void> _onAddressSelected(Map<String, String> suggestion) async {
    final placeId = suggestion['place_id'] ?? '';
    if (placeId.isEmpty) return;

    setState(() {
      _selectedPlaceId = placeId;
      _confirmedStreet = suggestion['description'] ?? '';
      _streetController.text = (suggestion['strada'] ?? '').trim();
      _numberController.text = (suggestion['numar'] ?? '').trim();
      _codPostalController.text = (suggestion['codPostal'] ?? '').trim();
      final judet = (suggestion['judet'] ?? '').trim();
      final localitate = (suggestion['localitate'] ?? '').trim();
      if (judet.isNotEmpty) _selectedCounty = judet;
      if (localitate.isNotEmpty) _selectedCity = localitate;
      _addressValidated = true;
      _suggestions = [];
      _showAddressDetails = true;
    });
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(value);
    });
  }

  // ---- Reverse Geocoding (GPS) ----
  Future<void> _getCurrentAddress() async {
    if (_isGettingLocation) return;

    setState(() {
      _isGettingLocation = true;
      textEroare = null;
    });

    try {
      // Verifică dacă serviciile de localizare sunt activate
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          textEroare = 'Activează serviciile de localizare în setări';
          _isGettingLocation = false;
        });
        return;
      }

      // Solicită permisiunea de localizare
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            textEroare = 'Permisiunea de localizare a fost refuzată';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          textEroare = 'Permisiunea de localizare este dezactivată permanent. Activeaz-o din setări.';
          _isGettingLocation = false;
        });
        return;
      }

      // Obține poziția curentă
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      // Trimite cerere de reverse geocoding către server
      final client = _createHttpClient();
      try {
        final response = await client.get(
          Uri.parse(
            'https://$serverUrl/places/reverse?lat=${position.latitude}&lon=${position.longitude}',
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            final strada = (address['strada'] as String? ?? '').trim();
            final numar = (address['numar'] as String? ?? '').trim();
            final localitate = (address['localitate'] as String? ?? '').trim();
            final judet = (address['judet'] as String? ?? '').trim();
            final codPostal = (address['codPostal'] as String? ?? '').trim();
            final placeId = (address['place_id'] as String? ?? '').trim();

            setState(() {
              _selectedPlaceId = placeId;
              _confirmedStreet = strada.isNotEmpty ? strada : 'Adresă selectată';
              _streetController.text = strada;
              _numberController.text = numar;
              _codPostalController.text = codPostal;
              _addressValidated = true;
              _showAddressDetails = true;

              // Dacă suntem pe Step 3 (county/city necompletate) sau orice alt pas,
              // setăm automat județul și localitatea din locația GPS
              if (_selectedCounty == null || _selectedCity == null) {
                _selectedCounty = judet.isNotEmpty ? judet : null;
                _selectedCity = localitate.isNotEmpty ? localitate : null;
              }
            });
          }
        } else {
          setState(() {
            textEroare = 'Nu s-a putut găsi o adresă pentru locația ta';
          });
        }
      } catch (e) {
        debugPrint('Reverse geocode error: $e');
        setState(() {
          textEroare = 'Eroare la obținerea adresei de la server';
        });
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        textEroare = 'Eroare la obținerea locației';
      });
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  // ---- Phone Formatting ----

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

  String _getHintForCountry() {
    if (_selectedCountry == null) return '712 345 678';
    final example = _selectedCountry!.exampleNumberMobileNational;
    if (_countryUsesTrunkPrefix(_selectedCountry!.countryCode)) {
      String hint = example.replaceAll(RegExp(r'[^\d\s]'), '');
      if (hint.startsWith('0')) hint = hint.substring(1).trim();
      return hint.isEmpty ? '712 345 678' : hint;
    }
    return example.replaceAll(RegExp(r'[^\d\s]'), '').trim();
  }

  int _getMaxLengthForCountry() {
    final hint = _getHintForCountry();
    // A little generous for different phone lengths
    return hint.length + 3;
  }

  // ---- CNP Auto-fill ----
  void _autoFillFromCNP() {
    final cnp = _cnpController.text.trim();
    final extractedGender = genderFromCNP(cnp);
    final extractedBirthDate = birthDateFromCNP(cnp);
    if (extractedGender != null) _selectedGender = extractedGender;
    if (extractedBirthDate != null) {
      _birthDate = extractedBirthDate;
      _birthDateController.text =
          '${extractedBirthDate.day.toString().padLeft(2, '0')}.${extractedBirthDate.month.toString().padLeft(2, '0')}.${extractedBirthDate.year}';
    }
    setState(() {});
  }

  Future<void> _selectDate() async {
    final initialDate = _birthDate ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text =
            '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      });
    }
  }

  // ---- Registration ----
  String? _formatPhoneForServer(String phone) {
    if (_selectedCountry == null) return null;
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (_countryUsesTrunkPrefix(_selectedCountry!.countryCode) &&
        cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    final fullNumber = '+${_selectedCountry!.phoneCode}$cleanPhone';
    if (cleanPhone.length < 8 || cleanPhone.length > 15) return null;
    return fullNumber;
  }

  Future<void> _register() async {
    if (_loading) return;
    setState(() {
      textEroare = null;
      _loading = true;
    });

    final client = _createHttpClient();
    try {
      final body = {
        'nume': _firstNameController.text.trim(),
        'prenume': _lastNameController.text.trim(),
        'sex': _selectedGender,
        'cnp': _cnpController.text.trim(),
        'datanasterii': _birthDate!.toIso8601String(),
        'nrtelefon': _formatPhoneForServer(_phoneController.text.trim()),
        'email': _emailController.text.trim(),
        'judet': _selectedCounty,
        'localitate': _selectedCity,
        'strada': _streetController.text.trim(),
        'numar': _numberController.text.trim(),
        'bloc': _blocController.text.trim(),
        'scara': _scaraController.text.trim(),
        'apartament': _apartmentController.text.trim(),
        'codPostal': _codPostalController.text.trim(),
        'placeId': _selectedPlaceId ?? '',
      };

      final response = await client.post(
        Uri.parse('https://$serverUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final userId = data['user']?['id'] as int? ?? data['userId'] as int?;

        if (userId != null) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => TosScreen(userId: userId),
              ),
              (route) => false,
            );
          }
        } else {
          setState(() => textEroare = 'Eroare la crearea contului');
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          textEroare = data['error'] ??
              'Eroare la înregistrare (cod: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() => textEroare = 'Eroare de rețea: Nu te poți conecta la server');
      debugPrint('Register error: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextStep() {
    bool valid = false;
    switch (_currentStep) {
      case 0:
        valid = _validateStep1();
        break;
      case 1:
        valid = _validateStep2();
        break;
      case 2:
        valid = _validateStep3();
        break;
      case 3:
        valid = _validateStep4();
        break;
    }
    if (valid) {
      setState(() {
        textEroare = null;
        if (_currentStep < 3) {
          _currentStep++;
          _slideController?.reset();
          _slideController?.forward();
        }
      });
    }
  }

  void _prevStep() {
    setState(() {
      textEroare = null;
      if (_currentStep > 0) {
        _currentStep--;
        _slideController?.reset();
        _slideController?.forward();
      }
    });
  }

  // ---- Step Builders ----
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentStep ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index <= _currentStep
                  ? const Color(lightForestGreenColor)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date personale',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Completează datele tale de identificare',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: _lastNameController,
                label: 'Nume de familie',
                hint: 'Popescu',
                inputFormatters: [LastNameFormatter()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller: _firstNameController,
                label: 'Prenume',
                hint: 'Ion',
                inputFormatters: [FirstNameFormatter()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGenderSelector(),
        const SizedBox(height: 16),
        _buildField(
          controller: _cnpController,
          label: 'CNP',
          hint: '1234567890123',
          keyboardType: TextInputType.number,
          maxLength: 13,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: GestureDetector(
            onTap: _autoFillFromCNP,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.auto_fix_high, size: 20, color: Color(lightForestGreenColor)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDateField(),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Număr de telefon',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Numărul tău de contact pentru verificare',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCountryDropdown(),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPhoneField(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email și domiciliu',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Date de contact și județul/localitatea de domiciliu',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        _buildField(
          controller: _emailController,
          label: 'Email',
          hint: 'exemplu@email.com',
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._\-]'))],
        ),
        const SizedBox(height: 16),
        _buildCountyDropdown(),
        const SizedBox(height: 16),
        _buildCityDropdown(),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresa completă',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(darkGreyColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Caută-ți strada, apoi completează detaliile',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        _buildAutocompleteField(),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildAddressDetails(),
          crossFadeState: _showAddressDetails
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildAddressDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Street (read-only after selection)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _confirmedStreet,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(darkGreyColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildField(
                controller: _numberController,
                label: 'Număr',
                hint: 'ex: 4',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                controller: _blocController,
                label: 'Bloc',
                hint: 'ex: 2',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                controller: _scaraController,
                label: 'Scară',
                hint: 'ex: A',
                inputFormatters: [SingleLetterFormatter()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                controller: _apartmentController,
                label: 'Apartament',
                hint: 'ex: 12',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _codPostalController,
          label: 'Cod Poștal',
          hint: '600339',
        ),
      ],
    );
  }

  // ---- Widget Builders ----
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
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
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(darkGreyColor),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              suffixIcon: suffix,
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
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            'Gen',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _genderOption('M', 'Masculin'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _genderOption('F', 'Feminin'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderOption(String value, String label) {
    final selected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(lightForestGreenColor) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(lightForestGreenColor) : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(darkGreyColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            'Data nașterii',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthDateController.text.isEmpty
                        ? 'Selectează data'
                        : _birthDateController.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _birthDateController.text.isEmpty
                          ? Colors.grey[400]
                          : const Color(darkGreyColor),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month_outlined, size: 20, color: Color(lightForestGreenColor)),
              ],
            ),
          ),
        ),
      ],
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
          value: _selectedCountry,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 14),
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
                  Text(countryCodeToEmoji(country.countryCode), style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+${country.phoneCode}', style: const TextStyle(fontSize: 14)),
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

  Widget _buildPhoneField() {
    return Container(
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
          hintText: _getHintForCountry(),
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              Text(
                'Adresă',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isGettingLocation ? null : _getCurrentAddress,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isGettingLocation
                        ? Colors.grey[200]
                        : const Color(lightForestGreenColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isGettingLocation
                          ? Colors.grey[300]!
                          : const Color(lightForestGreenColor).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isGettingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                              color: Color(lightForestGreenColor),
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _isGettingLocation ? 'Se caută...' : 'Locația mea',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isGettingLocation
                              ? Colors.grey[500]
                              : const Color(lightForestGreenColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
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
          child: Autocomplete<Map<String, String>>(
            optionsBuilder: (TextEditingValue value) {
              if (value.text.isEmpty) return [];
              _onAddressChanged(value.text);
              return _suggestions;
            },
            displayStringForOption: (option) => option['description'] ?? '',
            onSelected: (Map<String, String> selection) {
              _onAddressSelected(selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (value) {
                  _addressValidated = false;
                  _onAddressChanged(value);
                },
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(darkGreyColor),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _isLoadingAutocomplete
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
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
                  hintText: 'Strada, număr...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildCountyDropdown() {
    final items = judete.map((j) => j['judet'] as String).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text('Județ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCounty,
              hint: Text('Selectează județ', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400])),
              items: items.map((county) {
                return DropdownMenuItem(value: county, child: Text(county, style: GoogleFonts.inter(fontSize: 15, color: const Color(darkGreyColor))));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCounty = value;
                  _selectedCity = null;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    final cities = _selectedCounty != null ? (mapLocalitati[_selectedCounty] ?? []) : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text('Localitate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCity,
              hint: Text('Selectează localitate', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400])),
              items: cities.map((city) {
                return DropdownMenuItem(value: city, child: Text(city, style: GoogleFonts.inter(fontSize: 15, color: const Color(darkGreyColor))));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCity = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(lightForestGreenColor)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Înapoi',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(lightForestGreenColor),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
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
                  onTap: _loading
                      ? null
                      : () {
                          if (_currentStep == 3) {
                            _register();
                          } else {
                            _nextStep();
                          }
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _currentStep == 3 ? 'Înregistrează-te' : 'Continuă',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(darkGreyColor),
                  ),
                  Text(
                    'Înregistrare',
                    style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                  ),
                ],
              ),
            ),
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SlideTransition(
                      position: _slideAnimation!,
                      child: FadeTransition(
                        opacity: _fadeAnimation!,
                        child: [
                          _buildStep1(),
                          _buildStep2(),
                          _buildStep3(),
                          _buildStep4(),
                        ][_currentStep],
                      ),
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
                              child: Text(textEroare!, style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNavButtons(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
