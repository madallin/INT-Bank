import 'package:flutter/widgets.dart';

import '../onboarding/screens/approval_screen.dart';
import '../onboarding/screens/tos_screen.dart';
import 'screens/pin_screen.dart';

/// What the app knows right after the SMS code was verified.
///
/// [preAuthToken] is the short-lived token the server issues for a verified phone. It only
/// opens the onboarding steps (terms, approval status, first PIN) of this customer; banking
/// needs the full session from phone + PIN sign-in.
@immutable
class OnboardingSession
{
  const OnboardingSession({
    required this.userId,
    required this.phoneNumber,
    required this.preAuthToken,
    required this.acceptedTerms,
    required this.approved,
    required this.hasPin,
  });

  final int userId;
  final String phoneNumber;
  final String preAuthToken;
  final bool acceptedTerms;
  final bool approved;
  final bool hasPin;

  /// Parses the `/2fa/verify` reply; null when it carries no onboarding token.
  static OnboardingSession? fromVerifyResponse(Map<dynamic, dynamic> data, String phoneNumber)
  {
    final token = data['preAuthToken'];
    final userId = data['userId'];
    if(token is! String || token.isEmpty || userId is! num) return null;
    return OnboardingSession(
      userId: userId.toInt(),
      phoneNumber: phoneNumber,
      preAuthToken: token,
      acceptedTerms: data['acceptedTerms'] == true,
      approved: data['approved'] == true,
      hasPin: data['hasPin'] == true,
    );
  }

  /// `Authorization` header for onboarding requests.
  Map<String, String> get authHeader => {'Authorization': 'Bearer $preAuthToken'};

  OnboardingSession copyWith({bool? acceptedTerms, bool? approved, bool? hasPin}) => OnboardingSession(
        userId: userId,
        phoneNumber: phoneNumber,
        preAuthToken: preAuthToken,
        acceptedTerms: acceptedTerms ?? this.acceptedTerms,
        approved: approved ?? this.approved,
        hasPin: hasPin ?? this.hasPin,
      );

  /// The next step: accept the terms, wait for approval, then choose or enter the PIN.
  Widget nextScreen()
  {
    if(!acceptedTerms) return TosScreen(userId: userId, session: this);
    if(!approved) return ApprovalScreen(userId: userId, preAuthToken: preAuthToken);
    return PinScreen(
      userId: userId,
      set: !hasPin,
      popOnSuccess: false,
      useJwtLogin: true,
      phoneNumber: phoneNumber,
      preAuthToken: preAuthToken,
    );
  }
}
