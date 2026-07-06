import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/form_text_field.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';

class TransferScreen extends StatefulWidget {
  final int userId;
  final String userIban;

  const TransferScreen({
    super.key,
    required this.userId,
    required this.userIban,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with TickerProviderStateMixin {
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _loading = false;
  String _deviceId = 'dev-device';
  late String clientToken;
  late String refreshToken;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _initDeviceId().then((_) => _getClientToken());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ibanController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _formatIBAN(String input) {
    String clean = input.replaceAll(' ', '').toUpperCase();
    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += clean[i];
    }
    return formatted;
  }

  String _formatAmount(String input) {
    String clean = input.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return '';
    String reversed = clean.split('').reversed.join('');
    String formatted = '';
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) formatted += '.';
      formatted += reversed[i];
    }
    return formatted.split('').reversed.join('');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(lightForestGreenColor),
      ),
    );
  }

  Future<void> _initDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'dev-device';
      }
    } catch (_) {
      _deviceId = 'dev-device';
    }
  }

  http.Client _createHttpClient() {
    return IOClient(HttpClient());
  }

  Future<void> _getClientToken() async {
    try {
      final client = _createHttpClient();
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      } else {
        _showError('Eroare la obținerea tokenului client');
      }
    } catch (e) {
      _showError('Eroare de rețea: $e');
    }
  }

  Future<bool> _refreshToken() async {
    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'deviceId': _deviceId, 'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) clientToken = data['client_token'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> fetchTransferApi({
    required String iban,
    required String name,
    required int amount,
    required String reason,
  }) async {
    if (_loading) return {'success': false, 'error': 'Transfer în curs'};
    setState(() => _loading = true);

    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/users/${widget.userId}/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
        body: jsonEncode({
          'iban': iban.replaceAll(' ', ''),
          'beneficiaryName': name.toUpperCase(),
          'amount': amount,
          'reason': reason,
        }),
      );

      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          return await fetchTransferApi(
              iban: iban, name: name, amount: amount, reason: reason);
        }
        return {'success': false, 'error': 'Sesiune expirat. Reconectează-te.'};
      }

      final data = jsonDecode(response.body);
      return {'success': data['success'] ?? false, 'error': data['error']};
    } catch (e) {
      return {'success': false, 'error': 'Eroare de rețea: $e'};
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitTransfer() async {
    final iban = _ibanController.text.replaceAll(' ', '');
    final name = _nameController.text.trim();
    final amount =
        int.tryParse(_amountController.text.replaceAll('.', ''));
    final reason = _reasonController.text.trim();

    if (iban.isEmpty || iban.length < 16) {
      return _showError('IBAN invalid');
    }
    if (name.length < 7 || name.length > 128) {
      return _showError('Numele trebuie să aibă 7-128 caractere');
    }
    if (!name.contains(' ')) {
      return _showError('Trebuie minim un nume și un prenume');
    }
    if (reason.length < 3) return _showError('Motiv prea scurt');
    if (amount == null || amount <= 0) return _showError('Sumă invalidă');
    if (iban.toUpperCase() ==
        widget.userIban.replaceAll(' ', '').toUpperCase()) {
      return _showError('Nu poți trimite bani în propriul cont');
    }

    final capitalizedReason =
        reason[0].toUpperCase() + reason.substring(1);
    final result = await fetchTransferApi(
      iban: iban,
      name: name.toUpperCase(),
      amount: amount,
      reason: capitalizedReason,
    );

    if (result['success'] == true) {
      _showSuccess('Transfer efectuat cu succes!');
      _ibanController.clear();
      _nameController.clear();
      _amountController.clear();
      _reasonController.clear();
    } else {
      _showError(result['error'] ?? 'Eroare la transfer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: 'Transfer bancar',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 40),
            const PageTitle(
              title: 'Transfer nou',
              subtitle:
                  'Completează datele pentru a efectua transferul',
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      FormTextField(
                        controller: _ibanController,
                        label: 'IBAN destinatar',
                        icon: Icons.account_balance_outlined,
                        hint: 'RO49 AAAA 1B31 0075 9384 0000',
                        maxLength: 34,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                            final formatted = _formatIBAN(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                  offset: formatted.length),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FormTextField(
                        controller: _nameController,
                        label: 'Nume beneficiar',
                        icon: Icons.person_outline,
                        hint: 'Popescu Ion',
                        keyboardType: TextInputType.name,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s-]')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FormTextField(
                        controller: _amountController,
                        label: 'Sumă (RON)',
                        icon: Icons.payments_outlined,
                        hint: '5',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                            final formatted =
                                _formatAmount(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                  offset: formatted.length),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FormTextField(
                        controller: _reasonController,
                        label: 'Motiv transfer',
                        icon: Icons.description_outlined,
                        hint: 'Plată factură, Rambursare etc.',
                        keyboardType: TextInputType.text,
                        maxLength: 140,
                      ),
                      const SizedBox(height: 48),
                      ActionButton(
                        label: 'Transferă',
                        onTap: _loading ? null : _submitTransfer,
                        isLoading: _loading,
                        isExpanded: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}