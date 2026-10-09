import '../../../theme/app_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../core/network/transport_security.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/screens/login_screen.dart';
import '../../welcome/welcome_screen.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/app_log.dart';

class ApprovalScreen extends StatefulWidget
{
  final int userId;

  /// Onboarding token from the SMS step; lets the screen ask the server about approval.
  /// Without it (or once it expires) the screen relies on the approval broadcast.
  final String? preAuthToken;

  const ApprovalScreen({super.key, required this.userId, this.preAuthToken});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with TickerProviderStateMixin
{
  bool _isApproved = false;
  bool _showSuccessMessage = false;
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _pollTimer;
  WebSocket? _ws;

  @override
  void initState()
  {
    super.initState();
    _initAnimations();
    _connectWebSocket();
    _startPolling();
  }

  @override
  void dispose()
  {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _checkController.dispose();
    _fadeController.dispose();
    _ws?.close();
    super.dispose();
  }

  void _connectWebSocket() async
  {
    try
    {
      // The socket only serves a customer with a token; without one, the screen
      // falls back to asking again later (sign in once more).
      final token = widget.preAuthToken;
      if(token == null) return;
      final client = TransportPolicy.httpClient(Uri.parse(AppConfig.wsUrl).host);

      final uri = AppConfig.wsUrl;
      _ws = await WebSocket.connect(uri, headers: {'Authorization': 'Bearer $token'}, customClient: client);
      AppLog.debug('WebSocket conectat!');

      _ws!.listen(
        (message)
        {
          AppLog.debug('WebSocket message received');
          dynamic data;
          try
          {
            data = jsonDecode(message);
          }
          catch (e)
{
            AppLog.debug('Nu s-a putut decoda JSON', e);
            return;
          }

          final messageType = data['type'];
          final incomingId = data['id'];
          final incomingIdInt = incomingId is int
              ? incomingId
              : int.tryParse(incomingId?.toString() ?? '');

          if((messageType == 'contAprobat' || messageType == null) &&
              incomingIdInt == widget.userId)
{
            AppLog.debug('Approval matched for user ${widget.userId}');
            _onApprovalReceived();
          }
        },
        onDone: ()
        {
          AppLog.debug('WebSocket inchis');
        },
        onError: (err)
        {
          AppLog.debug('Eroare WebSocket', err);
        },
        cancelOnError: true,
      );
    }
    catch (e)
{
      AppLog.debug('Eroare la conectarea WebSocket', e);
    }
  }

  void _startPolling()
  {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async
    {
      if(_isApproved)
{
        _pollTimer?.cancel();
        return;
      }
      final token = widget.preAuthToken;
      if(token == null)
      {
        _pollTimer?.cancel(); // no way to ask the server; wait for the broadcast instead
        return;
      }
      try
      {
        final response = await DioClient().get(
          '/users/${widget.userId}/has-approved',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final data = response.data;
        if(data is Map && data['contaprobat'] == true)
        {
          AppLog.debug('Polling: cont aprobat pentru user ${widget.userId}');
          _onApprovalReceived();
        }
      }
      on DioException catch (e)
      {
        // 401/403: the onboarding token expired; keep listening for the broadcast only.
        if(e.response?.statusCode == 401 || e.response?.statusCode == 403) _pollTimer?.cancel();
      }
      catch (e)
{
        AppLog.debug('Polling error', e);
      }
    });
  }

  void _onApprovalReceived()
  {
    _ws?.close();
    _pollTimer?.cancel();
    setState(() => _isApproved = true);
    _pulseController.stop();
    _checkController.forward();

    Future.delayed(const Duration(milliseconds: 1000), ()
    {
      if(mounted)
{
        setState(() => _showSuccessMessage = true);
        _fadeController.forward();

        Future.delayed(const Duration(seconds: 5), ()
        {
          if(mounted)
{
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        });
      }
    });
  }

  void _initAnimations()
  {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _isApproved
                            ? _buildSuccessIcon()
                            : _buildWaitingIcon(),
                      ),
                      const SizedBox(height: 58),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _showSuccessMessage
                            ? _buildSuccessMessage()
                            : _buildWaitingMessage(),
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

  Widget _buildWaitingIcon()
  {
    return ScaleTransition(
      key: const ValueKey('waiting'),
      scale: _pulseAnimation,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.heroStart,
              context.colors.heroEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brand.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.brand.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
            ),
            const Icon(Icons.person_search_rounded, size: 85, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIcon()
  {
    return ScaleTransition(
      key: const ValueKey('success'),
      scale: _checkAnimation,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.heroStart,
              context.colors.heroEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brand.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.brand.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
            ),
            const Icon(Icons.check_rounded, size: 80, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingMessage()
  {
    return Column(
      key: const ValueKey('waiting_text'),
      children: [
        Text(
          context.l10n.approvalVerificareCurs,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: context.colors.brandStrong,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.approvalOperatorVerificaDateleTale,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.colors.heroStart,
                context.colors.heroEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.colors.brand.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.approvalAprobareCatevaMomente,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage()
  {
    return FadeTransition(
      key: const ValueKey('success_text'),
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            context.l10n.approvalContVerificatSucces,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: context.colors.brandStrong,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.approvalDateleTaleAuFost,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.heroStart,
                  context.colors.heroEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brand.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  context.l10n.approvalVerificareCompleta,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

