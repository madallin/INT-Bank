import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/auth/screens/pin_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../l10n/l10n.dart';
import '../../services/jwt_api_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';
import '../storage/secure_session_manager.dart';
import 'session_timeout_service.dart';

/// App-wide protections:
/// 1. Privacy veil: hides balances in the app switcher while the app is in the background.
/// 2. Inactivity lock: after [timeout] without interaction a signed-in session is ended on the
///    server and the customer must enter their PIN again. Nothing is locked when nobody is
///    signed in.
class BankingSecurityWrapper extends StatefulWidget
{
  const BankingSecurityWrapper({
    super.key,
    required this.child,
    this.navigatorKey,
    this.timeout = const Duration(minutes: 5),
  });

  final Widget child;

  /// The app's navigator, used to open the PIN screen after the lock.
  final GlobalKey<NavigatorState>? navigatorKey;
  final Duration timeout;

  @override
  State<BankingSecurityWrapper> createState() => _BankingSecurityWrapperState();
}

class _BankingSecurityWrapperState extends State<BankingSecurityWrapper> with WidgetsBindingObserver
{
  bool _isVeilActive = false;
  bool _isSessionLocked = false;

  /// Captured when the session is ended, so the PIN screen can sign the customer back in.
  int? _lockedUserId;
  String? _lockedPhone;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionTimeoutService.instance.start(timeout: widget.timeout, onTimeout: _handleSessionTimeout);
  }

  @override
  void didUpdateWidget(BankingSecurityWrapper oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    // The customer changed the auto-lock time on the Profile tab.
    if(widget.timeout != oldWidget.timeout && !_isSessionLocked)
    {
      SessionTimeoutService.instance.start(timeout: widget.timeout, onTimeout: _handleSessionTimeout);
    }
  }

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    SessionTimeoutService.instance.stop();
    super.dispose();
  }

  Future<void> _handleSessionTimeout() async
  {
    final token = await SecureSessionManager.getAccessToken();
    if(token == null || token.isEmpty)
    {
      // Nobody is signed in (welcome, sign-in, onboarding): nothing to protect.
      SessionTimeoutService.instance.unlockSession();
      return;
    }
    _lockedUserId = await SecureSessionManager.getUserId();
    _lockedPhone = await SecureSessionManager.getPhone();
    if(mounted) setState(() => _isSessionLocked = true);
    // End the session on the server too: a locked app keeps no usable token.
    await JwtApiService.logout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state)
  {
    super.didChangeAppLifecycleState(state);
    final background = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if(background != _isVeilActive && mounted) setState(() => _isVeilActive = background);
  }

  void _reauthenticate()
  {
    SessionTimeoutService.instance.unlockSession();
    final userId = _lockedUserId;
    final phone = _lockedPhone;
    setState(() => _isSessionLocked = false);
    widget.navigatorKey?.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => userId != null && phone != null && phone.isNotEmpty
            ? PinScreen(userId: userId, set: false, popOnSuccess: false, useJwtLogin: true, phoneNumber: phone)
            : const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionTimeoutService.instance.recordUserActivity(),
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          if(_isSessionLocked) Positioned.fill(child: _SessionLockedView(onReauthenticate: _reauthenticate)),
          if(_isVeilActive && !_isSessionLocked) const Positioned.fill(child: _PrivacyVeil()),
        ],
      ),
    );
  }
}

class _SessionLockedView extends StatelessWidget
{
  const _SessionLockedView({required this.onReauthenticate});

  final VoidCallback onReauthenticate;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    return Material(
      color: c.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(color: c.brandSurface, shape: BoxShape.circle),
                  child: Icon(Icons.lock_clock_rounded, size: 56, color: c.brand),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(l10n.sessionLockedTitle, style: context.text.headlineSmall, textAlign: TextAlign.center),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.sessionLockedBody,
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(label: l10n.sessionLockedAction, icon: Icons.lock_open_rounded, onPressed: onReauthenticate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyVeil extends StatelessWidget
{
  const _PrivacyVeil();

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Material(
      color: c.background,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_rounded, size: 64, color: c.brand),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: c.brand),
                  const SizedBox(width: AppSpacing.xs),
                  Text(context.l10n.privacyVeilLabel, style: context.text.labelMedium?.copyWith(color: c.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
