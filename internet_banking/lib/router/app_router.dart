import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pin_screen.dart';
import '../features/auth/screens/two_factor_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/error/screens/error_screen.dart';
import '../features/exchange/screens/exchange_screen.dart';
import '../features/transactions/screens/transaction_history_screen.dart';
import '../features/transfer/screens/transfer_screen.dart';
import '../features/onboarding/screens/approval_screen.dart';
import '../features/onboarding/screens/tos_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (c, s) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (c, s) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (c, s) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/pin/:userId/:set/:pop/:jwt/:phone',
      builder: (c, s) => PinScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
        set: s.pathParameters['set'] == 'true',
        popOnSuccess: s.pathParameters['pop'] != 'false',
        useJwtLogin: s.pathParameters['jwt'] == 'true',
        phoneNumber: s.pathParameters['phone'],
      ),
    ),
    GoRoute(
      path: '/two-factor/:phone/:userId',
      builder: (c, s) => TwoFactorScreen(
        phoneNumber: s.pathParameters['phone'] ?? '',
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
      ),
    ),
    GoRoute(
      path: '/home/:userId',
      builder: (c, s) => HomeScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
      ),
    ),
    GoRoute(
      path: '/exchange/:userId',
      builder: (c, s) => ExchangeScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
      ),
    ),
    GoRoute(
      path: '/transactions/:userId/:accountId',
      builder: (c, s) => TransactionHistoryScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
        accountId: int.parse(s.pathParameters['accountId'] ?? '0'),
      ),
    ),
    GoRoute(
      path: '/transfer/:userId/:iban',
      builder: (c, s) => TransferScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
        userIban: s.pathParameters['iban'] ?? '',
      ),
    ),
    GoRoute(
      path: '/onboarding/tos/:userId',
      builder: (c, s) => TosScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
      ),
    ),
    GoRoute(
      path: '/onboarding/approval/:userId',
      builder: (c, s) => ApprovalScreen(
        userId: int.parse(s.pathParameters['userId'] ?? '0'),
      ),
    ),
  ],
  errorBuilder: (c, s) => ErrorScreen(
    errorMessage: s.error.toString(),
    onConnectionRestored: (ctx) {},
  ),
);
