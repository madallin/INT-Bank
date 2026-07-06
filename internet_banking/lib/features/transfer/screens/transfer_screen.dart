import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';

class TransferScreen extends StatefulWidget
{
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
    with TickerProviderStateMixin
{
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
  void initState()
  {
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
  void dispose()
  {
    _fadeController.dispose();
    _ibanController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _formatIBAN(String input)
  {
    String clean = input.replaceAll(' ', '').toUpperCase();
    String formatted = '';
    for(int i = 0; i < clean.length; i++)
{
      if(i > 0 && i % 4 == 0) formatted += ' ';
      formatted += clean[i];
    }
    return formatted;
  }

  String _formatAmount(String input)
  {
    String clean = input.replaceAll(RegExp(r'[^\d]'), '');
    if(clean.isEmpty) return '';
    String reversed = clean.split('').reversed.join('');
    String formatted = '';
    for(int i = 0; i < reversed.length; i++)
{
      if(i > 0 && i % 3 == 0) formatted += '.';
      formatted += reversed[i];
    }
    return formatted.split('').reversed.join('');
  }

  void _showError(String message)
  {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message)
  {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [const Icon(Icons.check_circle_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))],
        ),
        backgroundColor: const Color(lightForestGreenColor),
      ),
    );
  }

  Future<void> _initDeviceId() async
  {
    final deviceInfo = DeviceInfoPlugin();
    try
    {
      if(Platform.isAndroid)
{
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      }
      else if(Platform.isIOS)
{
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'dev-device';
      }
    }
    catch (_)
{
      _deviceId = 'dev-device';
    }
  }

  http.Client _createHttpClient()
  {
    return IOClient(HttpClient());
  }

  Future<void> _getClientToken() async
  {
    try
    {
      final client = _createHttpClient();
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId}),
      );
      if(response.statusCode == 200)
{
        final data = jsonDecode(response.body);
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      }
      else
{
        _showError('Eroare la obținerea tokenului client');
      }
    }
    catch (e)
{
      _showError('Eroare de rețea: $e');
    }
  }

  Future<bool> _refreshToken() async
  {
    final client = _createHttpClient();
    try
    {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId, 'refreshToken': refreshToken}),
      );
      if(response.statusCode == 200)
{
        final data = jsonDecode(response.body);
        if(mounted) clientToken = data['client_token'];
        return true;
      }
      return false;
    }
    catch (_)
{
      return false;
    }
    finally
    {
      client.close();
    }
  }

  Future<Map<String, dynamic>> fetchTransferApi({
    required String iban,
    required String name,
    required int amount,
    required String reason,
  }) async
  {
    if(_loading) return {'success': false, 'error': 'Transfer în curs'};
    setState(() => _loading = true);

    final client = _createHttpClient();
    try
    {
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

      if(response.statusCode == 401)
{
        final refreshed = await _refreshToken();
        if(refreshed)
{
          return await fetchTransferApi(iban: iban, name: name, amount: amount, reason: reason);
        }
        return {'success': false, 'error': 'Sesiune expirat. Reconectează-te.'};
      }

      final data = jsonDecode(response.body);
      return {'success': data['success'] ?? false, 'error': data['error']};
    }
    catch (e)
{
      return {'success': false, 'error': 'Eroare de rețea: $e'};
    }
    finally
    {
      client.close();
      if(mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitTransfer() async
  {
    final iban = _ibanController.text.replaceAll(' ', '');
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.replaceAll('.', ''));
    final reason = _reasonController.text.trim();

    if(iban.isEmpty || iban.length < 16) return _showError('IBAN invalid');
    if(name.length < 7 || name.length > 128) return _showError('Numele trebuie să aibă 7-128 caractere');
    if(!name.contains(' ')) return _showError('Trebuie minim un nume și un prenume');
    if(reason.length < 3) return _showError('Motiv prea scurt');
    if(amount == null || amount <= 0) return _showError('Sumă invalidă');
    if(iban.toUpperCase() == widget.userIban.replaceAll(' ', '').toUpperCase())
{
      return _showError('Nu poți trimite bani în propriul cont');
    }

    final capitalizedReason = reason[0].toUpperCase() + reason.substring(1);
    final result = await fetchTransferApi(
      iban: iban,
      name: name.toUpperCase(),
      amount: amount,
      reason: capitalizedReason,
    );

    if(result['success'] == true)
{
      _showSuccess('Transfer efectuat cu succes!');
      _ibanController.clear();
      _nameController.clear();
      _amountController.clear();
      _reasonController.clear();
    }
    else
{
      _showError(result['error'] ?? 'Eroare la transfer');
    }
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
                  Text('Transfer bancar', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text('Transfer nou', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor), letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text('Completează datele pentru a efectua transferul', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w400, height: 1.5)),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildInputField(controller: _ibanController, label: 'IBAN destinatar', icon: Icons.account_balance_outlined, hint: 'RO49 AAAA 1B31 0075 9384 0000', keyboardType: TextInputType.text, maxLength: 34, inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                        TextInputFormatter.withFunction((oldValue, newValue)
                        {
                          final formatted = _formatIBAN(newValue.text);
                          return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }),
                      ]),
                      const SizedBox(height: 24),
                      _buildInputField(controller: _nameController, label: 'Nume beneficiar', icon: Icons.person_outline, hint: 'Popescu Ion', keyboardType: TextInputType.name, inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s-]')),
                      ]),
                      const SizedBox(height: 24),
                      _buildInputField(controller: _amountController, label: 'Sumă (RON)', icon: Icons.payments_outlined, hint: '5', keyboardType: TextInputType.number, inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction((oldValue, newValue)
                        {
                          final formatted = _formatAmount(newValue.text);
                          return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }),
                      ]),
                      const SizedBox(height: 24),
                      _buildInputField(controller: _reasonController, label: 'Motiv transfer', icon: Icons.description_outlined, hint: 'Plată factură, Rambursare etc.', keyboardType: TextInputType.text, maxLines: 3, maxLength: 140),
                      const SizedBox(height: 48),
                      _buildTransferButton(),
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

  Widget _buildTransferButton()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(lightForestGreenColor), Color(lightForestGreenColor).withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Color(lightForestGreenColor).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _submitTransfer,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Transferă', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    int? maxLength,
  })
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
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
            maxLines: maxLines ?? 1,
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
}

