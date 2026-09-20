import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/storage/secure_session_manager.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/numpad_button.dart';
import '../../../widgets/simple_app_bar.dart';
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
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(lightForestGreenColor),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final response = await DioClient().post(
        '/auth/get-client-token',
        data: {'deviceId': _deviceId},
      );
      if (response.statusCode == 200) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;
        clientToken = data['client_token'];
        await _sendCode();
      } else {
        _showError('Eroare la obținerea tokenului client');
      }
    } catch (e) {
      _showError('Eroare de rețea: $e');
    }
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

    try {
      final response = await DioClient().post(
        '/2fa/request',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
        data: {'phone': widget.phoneNumber},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        await _startCooldown();
      } else {
        if (mounted) {
          _showError(data['error'] ?? 'Eroare la trimiterea codului');
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _showError(
            'Timpul pentru verificare a expirat. Te rugăm să reîncepi procesul.');
        setState(() => pin = '');
      } else {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          _showError(data['error'].toString());
        } else {
          _showError('Eroare de rețea: $e');
        }
      }
    } catch (e) {
      if (mounted) _showError('Eroare de rețea: $e');
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<void> _verifyPin() async {
    if (isVerifying) return;
    _showError('');
    setState(() => isVerifying = true);

    try {
      final response = await DioClient().post(
        '/2fa/verify',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
        data: {'phone': widget.phoneNumber, 'code': pin},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        setState(() => isVerifying = true);
        _showSuccess('Verificare reușită! Vei fi redirecționat...');

        bool setPin = true;
        try {
          final hasPinResponse = await DioClient().get(
            '/users/$_userId/has-pin',
            options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
          );

          if (hasPinResponse.statusCode == 200) {
            final hasPinData = hasPinResponse.data is Map<String, dynamic>
                ? hasPinResponse.data as Map<String, dynamic>
                : jsonDecode(hasPinResponse.data.toString()) as Map<String, dynamic>;
            setPin = !(hasPinData['hasPin'] ?? false);
          }
        } catch (_) {}

        await SecureSessionManager.savePhone(widget.phoneNumber);

        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PinScreen(
                userId: _userId,
                set: setPin,
                useJwtLogin: true,
                phoneNumber: widget.phoneNumber,
              ),
            ),
            (route) => false,
          );
        });
      } else if (mounted) {
        final serverError = (data['error'] as String?) ??
            'Cod invalid sau ai depasit numarul de incercari';
        _showError(serverError);
        setState(() => pin = '');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          _showError('Sesiune expirată. Te rugăm să te reconectezi');
          setState(() => pin = '');
        }
      } else {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          _showError(data['error'].toString());
        } else {
          _showError('Eroare de rețea: $e');
        }
        setState(() => pin = '');
      }
    } catch (e) {
      if (mounted) _showError('Eroare de rețea: $e');
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  void _resendCode() {
    if (_cooldownSeconds == 0) _sendCode();
  }

  Widget _buildPinDisplay() {
    return Row(
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
              color: isFilled
                  ? const Color(darkForestGreenColor)
                  : Colors.grey,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isFilled
                ? Text(pin[index],
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(darkForestGreenColor)))
                : const SizedBox.shrink(),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 72),
      child: Column(
        children: [
          ...List.generate(3, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (col) {
                  return NumpadButton(
                    label: (row * 3 + col + 1).toString(),
                    onTap: () =>
                        _onNumberPress((row * 3 + col + 1).toString()),
                  );
                }),
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64, height: 64),
              NumpadButton(
                label: '0',
                onTap: () => _onNumberPress('0'),
              ),
              NumpadDeleteButton(onTap: _onDeletePress),
            ],
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
            SimpleAppBar(
              title: 'Verificare',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Text('Introdu codul de verificare',
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Am trimis un cod de verificare la\n',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5),
                          ),
                          TextSpan(
                            text: formatPhoneDisplay(widget.phoneNumber),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(lightForestGreenColor),
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPinDisplay(),
                    if (textEroare.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ErrorBanner(message: textEroare),
                    ],
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: _resendCode,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                                text: "Nu ai primit codul? ",
                                style: GoogleFonts.inter(
                                    color: const Color(lightForestGreenColor),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400)),
                            TextSpan(
                              text: _cooldownSeconds == 0
                                  ? "Retrimite"
                                  : "Retrimite (${_cooldownSeconds}s)",
                              style: GoogleFonts.inter(
                                  color: const Color(lightForestGreenColor),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildNumpad(),
          ],
        ),
      ),
    );
  }
}