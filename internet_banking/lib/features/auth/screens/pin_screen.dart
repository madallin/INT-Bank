import '../../../widgets/app_logo.dart';
import '../../../theme/app_tokens.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_messages.dart';
import '../../../services/jwt_api_service.dart';
import '../../../core/storage/secure_session_manager.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/pin_pad.dart';
import '../../../widgets/pin_dot_indicator.dart';
import '../../shell/app_shell.dart';
import '../../../l10n/l10n.dart';

class PinScreen extends StatefulWidget {
  final int userId;
  final bool set;
  final bool popOnSuccess;
  /// Kept for existing routes; the PIN is always checked through phone + PIN sign-in.
  final bool useJwtLogin;
  final String? phoneNumber;

  /// Onboarding token from the SMS step; required to choose the first PIN ([set]).
  final String? preAuthToken;

  const PinScreen({
    super.key,
    required this.userId,
    required this.set,
    this.popOnSuccess = true,
    this.useJwtLogin = false,
    this.phoneNumber,
    this.preAuthToken,
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

  AnimationController? _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
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

  /// Phone for sign-in: from the SMS step, or the one remembered on this device.
  Future<String?> _phone() async {
    final phone = widget.phoneNumber;
    if (phone != null && phone.isNotEmpty) return phone;
    return SecureSessionManager.getPhone();
  }

  /// Signs in with phone + PIN (the server checks the PIN and its lockout) and opens
  /// the app. Returns false, after showing why, when the bank refuses.
  Future<bool> _signInAndOpenHome(String pinCode) async {
    final phone = await _phone();
    if (phone == null || phone.isEmpty) {
      _showError(AppL10n.current.pinEroareAutentificareIncearcaNou);
      return false;
    }
    int userId = widget.userId;
    try {
      final session = await JwtApiService.login(phone, pinCode);
      if (session == null) {
        _showError(AppL10n.current.pinEroarePotiConectaServer);
        return false;
      }
      userId = session.userId ?? userId;
    } on DioException catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.pinPinIncorect));
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loggedUserId', userId);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AppShell(userId: userId)),
        (route) => false,
      );
    }
    return true;
  }

  Future<void> _verifyExistingPin() async {
    if (isVerifying) return;
    setState(() => isVerifying = true);
    try {
      if (!await _signInAndOpenHome(pin) && mounted) setState(() => pin = '');
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  void _restartPinEntry() {
    if (!mounted) return;
    setState(() {
      pin = '';
      confirmPin = '';
      isConfirming = false;
    });
  }

  Future<void> _setNewPin() async {
    if (pin != confirmPin) {
      _showError(context.l10n.pinPinUrileCoincid);
      _restartPinEntry();
      return;
    }
    // Choosing the first PIN needs the onboarding token from the SMS step.
    final token = widget.preAuthToken;
    if (token == null || token.isEmpty) {
      _showError(AppL10n.current.pinEroareAutentificareIncearcaNou);
      _restartPinEntry();
      return;
    }

    setState(() => isVerifying = true);
    try {
      await DioClient().put(
        '/users/${widget.userId}/set-pin',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'codPin': pin},
      );
      if (!await _signInAndOpenHome(pin)) _restartPinEntry();
    } on DioException catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.pinEroareSetareaPinUlui));
      _restartPinEntry();
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