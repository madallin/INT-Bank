import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_config.dart';
import 'session_timeout_service.dart';

/// Banking Security Wrapper that enforces:
/// 1. App Switcher Privacy Veil (obfuscates sensitive bank data in OS recent apps).
/// 2. Inactivity Session Lockout (PSD2 RTS compliance after idle timeout).
class BankingSecurityWrapper extends StatefulWidget {
  final Widget child;

  const BankingSecurityWrapper({super.key, required this.child});

  @override
  State<BankingSecurityWrapper> createState() => _BankingSecurityWrapperState();
}

class _BankingSecurityWrapperState extends State<BankingSecurityWrapper> with WidgetsBindingObserver {
  bool _isVeilActive = false;
  bool _isSessionLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionTimeoutService.instance.start(
      timeout: const Duration(minutes: 5),
      onTimeout: _handleSessionTimeout,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionTimeoutService.instance.stop();
    super.dispose();
  }

  void _handleSessionTimeout() {
    if (mounted) {
      setState(() => _isSessionLocked = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isVeilActive && mounted) {
        setState(() => _isVeilActive = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isVeilActive && mounted) {
        setState(() => _isVeilActive = false);
      }
    }
  }

  void _unlockSession() {
    SessionTimeoutService.instance.unlockSession();
    if (mounted) {
      setState(() => _isSessionLocked = false);
      // Navigate to welcome/login for security re-auth
      try {
        context.go('/welcome');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionTimeoutService.instance.recordUserActivity(),
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,

          // Inactivity Session Lock Screen
          if (_isSessionLocked)
            Positioned.fill(
              child: Material(
                color: const Color(0xFF0B0F17),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(lightForestGreenColor).withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(lightForestGreenColor).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_clock_rounded,
                              size: 56,
                              color: Color(lightForestGreenColor),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Sesiune Expirată',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pentru securitatea fondurilor și a datelor tale bancare, sesiunea a fost blocată din cauza inactivității.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          ElevatedButton.icon(
                            onPressed: _unlockSession,
                            icon: const Icon(Icons.lock_open_rounded, size: 20),
                            label: Text(
                              'Reautentificare',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(lightForestGreenColor),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // App Switcher Privacy Veil (draws over content when app is backgrounded)
          if (_isVeilActive && !_isSessionLocked)
            Positioned.fill(
              child: Material(
                color: const Color(0xFF0B0F17),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(darkForestGreenColor).withOpacity(0.95),
                          const Color(0xFF0B0F17).withOpacity(0.98),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo_full_white.png',
                            width: 140,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.account_balance_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                size: 16,
                                color: Color(lightForestGreenColor),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'INTBank • Protecție Confidențialitate',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
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
}
