import '../../../theme/app_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/storage/secure_session_manager.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/simple_app_bar.dart';
import 'pin_screen.dart';
import '../../../l10n/l10n.dart';

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

  /// Real text field behind the code boxes, so the OS can autofill the SMS
  /// code and the user can paste it.
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  String textEroare = '';
  bool isVerifying = false;
  String? clientToken;
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
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => textEroare = message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    _showError('');
    showAppSnackBar(context, message,
        tone: SnackBarTone.success, duration: const Duration(seconds: 3));
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
        _showError(AppL10n.current.twoFactorEroareObtinereaTokenuluiClient);
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e));
    }
  }

  void _onCodeChanged(String value) {
    if (isVerifying) return;
    if (textEroare.isNotEmpty) _showError('');
    setState(() => pin = value);
    if (value.length == 6) _verifyPin();
  }

  void _clearCode() {
    _codeController.clear();
    setState(() => pin = '');
    _codeFocus.requestFocus();
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
          _showError(data['error'] ?? context.l10n.twoFactorEroareTrimitereaCodului);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _showError(
            AppL10n.current.twoFactorTimpulVerificareExpiratRugam);
        _clearCode();
      } else {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          _showError(data['error'].toString());
        } else {
          _showError(friendlyErrorMessage(e));
        }
      }
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<void> _verifyPin() async {
    if (isVerifying) return;
    if (clientToken == null) {
      _showError(context.l10n.twoFactorCodulPututFiTrimis);
      _clearCode();
      return;
    }
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
        _showSuccess(context.l10n.twoFactorVerificareReusitaVeiFi);

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
            context.l10n.twoFactorCodInvalidDepasitNumarul;
        _showError(serverError);
        _clearCode();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          _showError(context.l10n.twoFactorSesiuneExpirataRugamSa);
          _clearCode();
        }
      } else {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          _showError(data['error'].toString());
        } else {
          _showError(friendlyErrorMessage(e));
        }
        _clearCode();
      }
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  void _resendCode() {
    if (_cooldownSeconds > 0) return;
    if (clientToken == null) {
      _getClientTokenAndSendCode();
    } else {
      _sendCode();
    }
  }

  Widget _buildPinDisplay() {
    return Stack(
      children: [
        ExcludeSemantics(child: _buildPinBoxes()),
        Positioned.fill(
          child: TextField(
            controller: _codeController,
            focusNode: _codeFocus,
            autofocus: true,
            readOnly: isVerifying,
            onChanged: _onCodeChanged,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            showCursor: false,
            enableSuggestions: false,
            autocorrect: false,
            style: const TextStyle(color: Colors.transparent),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              hintText: context.l10n.twoFactorCodVerificareSms6,
              hintStyle: TextStyle(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool isFilled = index < pin.length;
        return Flexible(
            child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          constraints: const BoxConstraints(maxWidth: 40),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFilled
                  ? context.colors.brandStrong
                  : context.colors.textMuted,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isFilled
                ? Text(pin[index],
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.colors.brandStrong))
                : const SizedBox.shrink(),
          ),
        ));
      }),
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
              title: context.l10n.twoFactorVerificare,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Text(context.l10n.twoFactorIntroduCodulVerificare,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: context.l10n.twoFactorAmTrimisCodVerificare,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: context.colors.textSecondary,
                                height: 1.5),
                          ),
                          TextSpan(
                            text: formatPhoneDisplay(widget.phoneNumber),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.brand,
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
                    TextButton(
                      onPressed: _cooldownSeconds == 0 ? _resendCode : null,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                                text: context.l10n.twoFactorPrimitCodul,
                                style: GoogleFonts.inter(
                                    color: context.colors.brand,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400)),
                            TextSpan(
                              text: _cooldownSeconds == 0
                                  ? context.l10n.twoFactorRetrimite
                                  : context.l10n.twoFactorRetrimiteS(_cooldownSeconds),
                              style: GoogleFonts.inter(
                                  color: context.colors.brand,
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
          ],
        ),
      ),
    );
  }
}