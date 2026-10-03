import '../../../widgets/app_logo.dart';
import '../../../theme/app_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_messages.dart';
import '../../../services/jwt_api_service.dart';
import '../../../core/storage/secure_session_manager.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/pin_pad.dart';
import '../../../widgets/pin_dot_indicator.dart';
import '../../home/screens/home_screen.dart';
import '../../../l10n/l10n.dart';

class PinScreen extends StatefulWidget {
  final int userId;
  final bool set;
  final bool popOnSuccess;
  final bool useJwtLogin;
  final String? phoneNumber;

  const PinScreen({
    super.key,
    required this.userId,
    required this.set,
    this.popOnSuccess = true,
    this.useJwtLogin = false,
    this.phoneNumber,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with TickerProviderStateMixin {
  String pin = '';
  String confirmPin = '';
  bool isConfirming = false;
  String textEroare = '';
  bool isVerifying = false;
  String? clientToken;
  String _deviceId = 'dev-device';

  AnimationController? _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initDeviceId().then((_) => _getClientToken());
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    super.dispose();
  }

  void _clearError() {
    if (textEroare.isNotEmpty) setState(() => textEroare = '');
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => textEroare = message);
    _shakeController?.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      _shakeController?.stop();
      _shakeController?.reset();
    });
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

  Future<void> _getClientToken() async {
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
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e));
    }
  }

  void _onNumberPress(String number) {
    if (isVerifying) return;
    _clearError();

    if (!isConfirming) {
      if (pin.length < 6) {
        setState(() => pin += number);
        if (pin.length == 6 && widget.set) {
          setState(() => isConfirming = true);
        } else if (pin.length == 6 && !widget.set) {
          _verifyExistingPin();
        }
      }
    } else {
      if (confirmPin.length < 6) {
        setState(() => confirmPin += number);
        if (confirmPin.length == 6) {
          _setNewPin();
        }
      }
    }
  }

  void _onDeletePress() {
    if (isVerifying) return;
    _clearError();
    if (!isConfirming) {
      if (pin.isNotEmpty) {
        setState(() => pin = pin.substring(0, pin.length - 1));
      }
    } else {
      if (confirmPin.isNotEmpty) {
        setState(
            () => confirmPin = confirmPin.substring(0, confirmPin.length - 1));
      } else {
        setState(() => isConfirming = false);
      }
    }
  }

  Future<void> _verifyExistingPin() async {
    if (isVerifying) return;
    setState(() => isVerifying = true);

    try {
      if (!await _ensureClientToken()) {
        setState(() => pin = '');
        return;
      }
      final response = await DioClient().post(
        '/users/${widget.userId}/verify-pin',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
        data: {'pin': pin},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (widget.useJwtLogin) {
          final success = await _performJwtLogin();
          if (!success) {
            _showError(AppL10n.current.pinEroareAutentificareIncearcaNou);
            setState(() => pin = '');
            return;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('loggedUserId', widget.userId);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        }
      } else {
        _showError(data['error'] ?? AppL10n.current.pinPinIncorect);
        setState(() => pin = '');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        _showError(data['error'].toString());
      } else {
        _showError(AppL10n.current.pinEroarePotiConectaServer);
      }
      setState(() => pin = '');
    } catch (e) {
      _showError(AppL10n.current.pinEroarePotiConectaServer);
      setState(() => pin = '');
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<bool> _ensureClientToken() async {
    if (clientToken == null) await _getClientToken();
    if (clientToken == null && textEroare.isEmpty) {
      _showError(AppL10n.current.pinPotiConectaServerIncearca);
    }
    return clientToken != null;
  }

  Future<bool> _performJwtLogin() async {
    try {
      String? phone = widget.phoneNumber;
      if (phone == null || phone.isEmpty) {
        phone = await SecureSessionManager.getPhone();
      }
      if (phone == null || phone.isEmpty) {
        return true;
      }

      final result = await JwtApiService.login(phone, pin);
      return result != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setNewPin() async {
    if (pin != confirmPin) {
      _showError(context.l10n.pinPinUrileCoincid);
      setState(() {
        pin = '';
        confirmPin = '';
        isConfirming = false;
      });
      return;
    }

    setState(() => isVerifying = true);
    try {
      if (!await _ensureClientToken()) {
        setState(() {
          pin = '';
          confirmPin = '';
          isConfirming = false;
        });
        return;
      }
      final response = await DioClient().put(
        '/users/${widget.userId}/set-pin',
        options: Options(headers: {'Authorization': 'Bearer $clientToken'}),
        data: {'codPin': pin},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (widget.useJwtLogin) {
          await _performJwtLogin();
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('loggedUserId', widget.userId);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        }
      } else {
        _showError(data['error'] ?? AppL10n.current.pinEroareSetareaPinUlui);
        setState(() {
          pin = '';
          confirmPin = '';
          isConfirming = false;
        });
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        _showError(data['error'].toString());
      } else {
        _showError(AppL10n.current.pinEroarePotiConectaServer);
      }
      setState(() {
        pin = '';
        confirmPin = '';
        isConfirming = false;
      });
    } catch (e) {
      _showError(AppL10n.current.pinEroarePotiConectaServer);
      setState(() {
        pin = '';
        confirmPin = '';
        isConfirming = false;
      });
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.set
        ? (isConfirming ? context.l10n.pinConfirmaPinUl : context.l10n.pinSeteazaPinUl)
        : context.l10n.pinIntroduPinUl;
    final subtitle = widget.set
        ? (isConfirming
            ? context.l10n.pinReintroducetiCodulPinConfirmare
            : context.l10n.pinAlegetiCodPin6)
        : context.l10n.pinContinuaRugamSaIntroduci;

    final currentPin = isConfirming ? confirmPin : pin;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const AppLogo(height: 60),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _shakeController!,
              builder: (context, child) {
                final offset = _shakeController!.isAnimating
                    ? _shakeController!.value * 10 - 5
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            PinDotIndicator(length: currentPin.length),
            if (textEroare.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ErrorBanner(message: textEroare),
              ),
            ],
            const Spacer(),
            PinPad(
              onDigit: _onNumberPress,
              onDelete: _onDeletePress,
              enabled: !isVerifying,
            ),
          ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}