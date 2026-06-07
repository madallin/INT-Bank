// lib/features/auth/screens/two_factor_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform, X509Certificate;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';
import '../../../core/utils/helpers.dart';
import 'pin_screen.dart';

class TwoFactorScreen extends StatefulWidget {
  final String phoneNumber;
  final int userId;

  const TwoFactorScreen({
    super.key,
    required this.phoneNumber,
    required this.userId,
  });

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  String pin = '';
  String textEroare = '';
  bool isVerifying = false;
  late String clientToken;
  late String refreshToken;
  String _deviceId = 'dev-device';
  late int _userId;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId;
    _initDeviceId().then((_) => _getClientTokenAndSendCode());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => textEroare = message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    _showError('');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(lightForestGreenColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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
    if (mounted) setState(() {});
  }

  Future<void> _getClientTokenAndSendCode() async {
    try {
      final client = _createHttpClient();
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
        await _sendCode();
      } else {
        _showError('Eroare la obținerea tokenului client');
      }
    } catch (e) {
      _showError('Eroare de rețea: $e');
    }
  }

  http.Client _createHttpClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  void _onNumberPress(String number) {
    if (isVerifying) return;
    if (pin.length < 6) {
      _showError('');
      setState(() => pin += number);
      if (pin.length == 6) _verifyPin();
    }
  }

  void _onDeletePress() {
    if (isVerifying) return;
    if (pin.isNotEmpty) {
      _showError('');
      setState(() => pin = pin.substring(0, pin.length - 1));
    }
  }

  Future<void> _startCooldown() async {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendCode() async {
    if (isVerifying || _cooldownSeconds > 0) return;
    _showError('');
    setState(() => isVerifying = true);

    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('https://$serverUrl/2fa/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
        body: jsonEncode({'phone': widget.phoneNumber}),
      );

      if (response.statusCode == 401) {
        _showError('Timpul pentru verificare a expirat. Te rugăm să reîncepi procesul.');
        setState(() => pin = '');
        return;
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await _startCooldown();
      } else {
        if (mounted) _showError(data['error'] ?? 'Eroare la trimiterea codului');
      }
    } catch (e) {
      if (mounted) _showError('Eroare de rețea: $e');
    } finally {
      client.close();
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<void> _verifyPin() async {
    if (isVerifying) return;
    _showError('');
    setState(() => isVerifying = true);

    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('https://$serverUrl/2fa/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
        body: jsonEncode({'phone': widget.phoneNumber, 'code': pin}),
      );

      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          await _verifyPin();
        } else if (mounted) {
          _showError('Sesiune expirată. Te rugăm să te reconectezi');
          setState(() => pin = '');
        }
        return;
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        setState(() => isVerifying = true);
        _showSuccess('Verificare reușită! Vei fi redirecționat...');

        bool setPin = true;
        final hasPinResponse = await client.get(
          Uri.parse('https://$serverUrl/users/$_userId/has-pin'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $clientToken',
          },
        );

        if (hasPinResponse.statusCode == 200) {
          final hasPinData = jsonDecode(hasPinResponse.body);
          setPin = !(hasPinData['hasPin'] ?? false);
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PinScreen(userId: _userId, set: setPin),
            ),
            (route) => false,
          );
        });
      } else if (mounted) {
        final serverError = (data['error'] as String?) ?? 'Cod invalid sau ai depasit numarul de incercari';
        _showError(serverError);
        setState(() => pin = '');
      }
    } catch (e) {
      if (mounted) _showError('Eroare de rețea: $e');
    } finally {
      client.close();
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<bool> _refreshToken() async {
    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId, 'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => clientToken = data['client_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  void _resendCode() {
    if (_cooldownSeconds == 0) _sendCode();
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
                  Text('Verificare', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Text('Introdu codul de verificare', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Am trimis un cod de verificare la\n',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], height: 1.5),
                          ),
                          TextSpan(
                            text: formatPhoneDisplay(widget.phoneNumber),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(lightForestGreenColor), height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        bool isFilled = index < pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 40,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFilled ? const Color(darkForestGreenColor) : Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isFilled
                                ? Text(pin[index], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(darkForestGreenColor)))
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (textEroare.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
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
                                Expanded(child: Text(textEroare, style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        GestureDetector(
                          onTap: _resendCode,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(text: "Nu ai primit codul? ", style: GoogleFonts.inter(color: const Color(lightForestGreenColor), fontSize: 14, fontWeight: FontWeight.w400)),
                                TextSpan(
                                  text: _cooldownSeconds == 0 ? "Retrimite" : "Retrimite (${_cooldownSeconds}s)",
                                  style: GoogleFonts.inter(color: const Color(lightForestGreenColor), fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 72),
              child: Column(
                children: [
                  ...List.generate(3, (row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (col) {
                          return _buildNumberButton((row * 3 + col + 1).toString());
                        }),
                      ),
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 64, height: 64),
                      _buildNumberButton('0'),
                      _buildDeleteButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberPress(number),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey, width: 1.5),
        ),
        child: Center(child: Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _onDeletePress,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey, width: 1.5),
        ),
        child: const Center(child: Icon(Icons.backspace_outlined)),
      ),
    );
  }
}
