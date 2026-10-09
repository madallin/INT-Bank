import 'package:internet_banking/data/models/bank_account.dart';
import 'package:internet_banking/features/accounts/screens/account_detail_screen.dart';
import 'package:internet_banking/features/accounts/screens/accounts_screen.dart';
import 'package:internet_banking/features/payments/screens/payments_screen.dart';
import 'package:internet_banking/features/profile/screens/change_pin_screen.dart';
import 'package:internet_banking/features/profile/screens/profile_screen.dart';
import 'package:internet_banking/features/shell/app_shell.dart';
import 'package:internet_banking/features/vaults/screens/vaults_screen.dart';
import 'package:internet_banking/features/transfer/widgets/sca_pin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:internet_banking/data/models/card_model.dart';
import 'package:internet_banking/features/analytics/screens/spending_analytics_screen.dart';
import 'package:internet_banking/features/auth/screens/pin_screen.dart';
import 'package:internet_banking/features/auth/screens/two_factor_screen.dart';
import 'package:internet_banking/features/cards/screens/card_settings_screen.dart';
import 'package:internet_banking/features/error/screens/error_screen.dart';
import 'package:internet_banking/features/exchange/screens/exchange_screen.dart';
import 'package:internet_banking/features/home/screens/home_screen.dart';
import 'package:internet_banking/features/home/widgets/account_details_bottom_sheet.dart';
import 'package:internet_banking/features/notifications/widgets/notification_center_bottom_sheet.dart';
import 'package:internet_banking/features/statement/screens/statement_screen.dart';
import 'package:internet_banking/features/transactions/screens/transaction_history_screen.dart';
import 'package:internet_banking/features/transactions/widgets/transaction_details_bottom_sheet.dart';
import 'package:internet_banking/features/transfer/screens/scheduled_transfers_screen.dart';
import 'package:internet_banking/features/transfer/screens/transfer_receipt_screen.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';
import 'package:internet_banking/features/transfer/widgets/transfer_confirmation_bottom_sheet.dart';
import 'package:internet_banking/features/welcome/welcome_screen.dart';

/// Every customer-facing screen and sheet, built against [demoCustomerApi]
/// data, for accessibility, theming and layout checks.
const _card = CardModel(
  id: 11,
  accountId: 101,
  cardNumber: '4111111111114821',
  cardHolder: 'Ion Popescu',
  expiryDate: '09/29',
  cvv: '123',
  cardType: 'VISA',
);

/// Opens a bottom sheet from a blank page once the first frame is drawn.
Widget _sheet(void Function(BuildContext) open) => Builder(builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(context));
      return const Scaffold();
    });

void _noop() {}

final Map<String, Widget Function()> appScreens = {
  'welcome': () => const WelcomeScreen(),
  'pin': () => const PinScreen(userId: 1, set: false),
  'two_factor': () => const TwoFactorScreen(phoneNumber: '+40712345678', userId: 1),
  'home': () => const HomeScreen(userId: 1),
  'shell': () => const AppShell(userId: 1),
  'accounts': () => const AccountsScreen(userId: 1),
  'account_detail': () => const AccountDetailScreen(
        userId: 1,
        account: BankAccount(id: 101, iban: 'RO49INTB0001RON0000000001', currency: 'RON', balance: 12345.67),
      ),
  'payments': () => const PaymentsScreen(userId: 1),
  'profile': () => const ProfileScreen(userId: 1),
  'change_pin': () => const ChangePinScreen(userId: 1),
  'history': () => const TransactionHistoryScreen(userId: 1, accountId: 101),
  'transfer': () => const TransferScreen(
        userId: 1,
        userIban: 'RO49INTB0001RON0000000001',
        availableBalance: 12345.67,
      ),
  'confirm_sheet': () => const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: TransferConfirmationBottomSheet(
            beneficiaryName: 'ION POPESCU',
            toIban: 'RO96INTBRON0000000000002',
            fromIban: 'RO49INTB0001RON0000000001',
            amount: 1250,
            reason: 'Chirie octombrie',
            onConfirm: _noop,
          ),
        ),
      ),
  'receipt': () => TransferReceiptScreen(
        receipt: TransferReceipt(
          amount: 1250,
          currency: 'RON',
          beneficiaryName: 'ION POPESCU',
          toIban: 'RO96INTBRON0000000000002',
          fromIban: 'RO49INTB0001RON0000000001',
          reason: 'Chirie octombrie',
          createdAt: DateTime(2026, 10, 2, 14, 5),
          trackingId: '8f2c-11a0',
          status: 'COMPLETED',
        ),
      ),
  'scheduled': () => const ScheduledTransfersScreen(userId: 1),
  'exchange': () => const ExchangeScreen(userId: 1),
  'analytics': () => const SpendingAnalyticsScreen(userId: 1, accountId: 101, currency: 'RON'),
  'statement': () => const StatementScreen(
        userId: 1,
        accountId: 101,
        iban: 'RO49INTB0001RON0000000001',
        currency: 'RON',
      ),
  'card_settings': () => const CardSettingsScreen(userId: 1, card: _card),
  'vaults': () => const VaultsScreen(userId: 1),
  'sca_sheet': () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ScaPinSheet(
            challenge: const ScaChallenge(challengeId: 'sca-1', amount: 1500, currency: 'RON', toIban: 'RO26INTBRON0000000000001'),
            beneficiaryName: 'ION POPESCU',
            onSubmit: (_) async => null,
          ),
        ),
      ),
  'error': () => ErrorScreen(
        errorMessage: 'Nu s-a putut realiza conexiunea cu serverul. Așteptăm conexiunea...',
        onConnectionRestored: (_) {},
      ),
  'sheet_notifications': () => _sheet((c) => NotificationCenterBottomSheet.show(c, userId: 1)),
  'sheet_account': () => _sheet((c) => AccountDetailsBottomSheet.show(
        c,
        iban: 'RO49INTB0001RON0000000001',
        currency: 'RON',
        balance: 12345.67,
        holderName: 'Ion Popescu',
      )),
  'sheet_transaction': () => _sheet((c) => TransactionDetailsBottomSheet.show(c, {
        'id': 1,
        'trackingId': '8f2c-11a0',
        'amount': 1250,
        'currency': 'RON',
        'type': 'DEBIT',
        'reason': 'Chirie octombrie',
        'date': '2026-10-01T09:30:00',
        'status': 'COMPLETED',
        'fromIban': 'RO49INTB0001RON0000000001',
        'toIban': 'RO96INTBRON0000000000002',
      })),
};
