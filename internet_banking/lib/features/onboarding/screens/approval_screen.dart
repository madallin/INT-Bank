// lib/features/onboarding/screens/approval_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, X509Certificate, WebSocket;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../auth/screens/login_screen.dart';
import '../../welcome/welcome_screen.dart';

class ApprovalScreen extends StatefulWidget {
  final int userId;

  const ApprovalScreen({super.key, required this.userId});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with TickerProviderStateMixin {
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

  // ========== Lifecycle ==========

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _connectWebSocket();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _checkController.dispose();
    _fadeController.dispose();
    _ws?.close();
    super.dispose();
  }

  // ========== WebSocket ==========

  void _connectWebSocket() async {
    try {
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final uri = 'wss://$serverUrl';
      debugPrint('Incerc conexiune WS la: $uri');

      _ws = await WebSocket.connect(uri, customClient: client);
      debugPrint('WebSocket conectat!');

      final registerMsg = jsonEncode({'userId': widget.userId});
      try {
        _ws!.add(registerMsg);
        debugPrint('Trimis userId la server: ${widget.userId}');
      } catch (e) {
        debugPrint('Eroare la trimiterea userId: $e');
      }

      _ws!.listen(
        (message) {
          debugPrint('WS message: $message');
          dynamic data;
          try {
            data = jsonDecode(message);
          } catch (e) {
            debugPrint('Nu s-a putut decoda JSON: $e');
            return;
          }

          final messageType = data['type'];
          final incomingId = data['id'];
          final incomingIdInt = incomingId is int
              ? incomingId
              : int.tryParse(incomingId?.toString() ?? '');

          if ((messageType == 'contAprobat' || messageType == null) &&
              incomingIdInt == widget.userId) {
            debugPrint('Approval matched for user ${widget.userId}');
            _onApprovalReceived();
          }
        },
        onDone: () {
          debugPrint('WebSocket inchis');
        },
        onError: (err) {
          debugPrint('Eroare WebSocket: $err');
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      debugPrint('Eroare la conectarea WebSocket: $e\n$st');
    }
  }

  // ========== Polling fallback ==========

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isApproved) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final client = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        final request = await client.getUrl(
          Uri.parse('https://$serverUrl/users/${widget.userId}/has-approved'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final isApproved = data['contaprobat'] ?? false;
        if (isApproved) {
          debugPrint('Polling: cont aprobat pentru user ${widget.userId}');
          _onApprovalReceived();
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  // ========== Approval handler ==========

  void _onApprovalReceived() {
    _ws?.close();
    _pollTimer?.cancel();
    setState(() => _isApproved = true);
    _pulseController.stop();
    _checkController.forward();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showSuccessMessage = true);
        _fadeController.forward();

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
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

  // ========== Animations ==========

  void _initAnimations() {
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

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

  Widget _buildWaitingIcon() {
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
              const Color(lightForestGreenColor),
              const Color(darkForestGreenColor),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(lightForestGreenColor).withOpacity(0.4),
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
                  color: const Color(lightForestGreenColor).withOpacity(0.3),
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

  Widget _buildSuccessIcon() {
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
              const Color(lightForestGreenColor),
              const Color(darkForestGreenColor),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(lightForestGreenColor).withOpacity(0.4),
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
                  color: const Color(lightForestGreenColor).withOpacity(0.3),
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

  Widget _buildWaitingMessage() {
    return Column(
      key: const ValueKey('waiting_text'),
      children: [
        Text(
          'Verificare in curs',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(darkForestGreenColor),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Un operator verifica datele tale in acest moment',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
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
                const Color(lightForestGreenColor),
                const Color(darkForestGreenColor),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(lightForestGreenColor).withOpacity(0.3),
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
                'Aprobare in cateva momente...',
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

  Widget _buildSuccessMessage() {
    return FadeTransition(
      key: const ValueKey('success_text'),
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'Cont verificat cu succes!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(darkForestGreenColor),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Datele tale au fost aprobate.\nVei fi redirectionat in 5 secunde.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
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
                  const Color(lightForestGreenColor),
                  const Color(darkForestGreenColor),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(lightForestGreenColor).withOpacity(0.3),
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
                  'Verificare completa',
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
