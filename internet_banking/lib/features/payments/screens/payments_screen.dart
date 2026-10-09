import 'package:flutter/material.dart';

import '../../../core/services/privacy_mode_service.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/bank_account.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../widgets/list_section.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../exchange/screens/exchange_screen.dart';
import '../../shell/app_shell.dart';
import '../../transfer/screens/scheduled_transfers_screen.dart';
import '../../transfer/screens/transfer_screen.dart';

/// Payments tab: pick the account to pay from, then what to do. Every payment stays
/// inside INTBank.
class PaymentsScreen extends StatefulWidget
{
  const PaymentsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with ReloadWhenTabShown
{
  @override
  AppTab get tab => AppTab.payments;

  @override
  void onTabShown() => _load();

  List<BankAccount> _accounts = const [];
  int? _selectedId;
  bool _loading = true;
  String? _error;

  BankAccount? get _selected
  {
    for(final account in _accounts)
    {
      if(account.id == _selectedId) return account;
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  Future<void> _load() async
  {
    try
    {
      final accounts = await BankAccount.fetchAll(widget.userId);
      if(mounted) setState(() { _accounts = accounts; _error = null; });
    }
    catch(e)
    {
      if(mounted) setState(() => _error = friendlyErrorMessage(e, fallback: context.l10n.accountsLoadError));
    }
    finally
    {
      if(mounted) setState(() => _loading = false);
    }
  }

  Future<void> _push(Widget screen) async
  {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load(); // balances change after a payment
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: context.l10n.paymentsTitle),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context)
  {
    final l10n = context.l10n;
    if(_loading)
    {
      return const ShimmerLoading(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              SkeletonBox(height: 78, borderRadius: AppRadii.lg),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 78, borderRadius: AppRadii.lg),
              SizedBox(height: AppSpacing.lg),
              SkeletonBox(height: 200, borderRadius: AppRadii.lg),
            ],
          ),
        ),
      );
    }
    if(_error != null) return ErrorRetryView(message: _error!, onRetry: () { setState(() => _loading = true); _load(); });

    final from = _selected;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if(from == null)
            EmptyStatePlaceholder(icon: Icons.account_balance_wallet_outlined, title: l10n.accountsEmpty)
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
              child: Text(l10n.paymentsFrom, style: context.text.labelMedium?.copyWith(color: context.colors.textSecondary)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: PrivacyModeService().isPrivacyModeEnabled,
              builder: (context, hidden, _) => Column(
                children: [
                  for(final account in _accounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AccountTile(
                        account: account,
                        hidden: hidden,
                        selected: account.id == from.id,
                        onTap: () => setState(() => _selectedId = account.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListSection(
              children: [
                ListRow(
                  icon: Icons.send_rounded,
                  title: l10n.paymentsTransferTitle,
                  subtitle: l10n.paymentsTransferBody,
                  onTap: () => _push(TransferScreen(
                    userId: widget.userId,
                    userIban: from.iban,
                    currency: from.currency,
                    availableBalance: from.balance,
                  )),
                ),
                ListRow(
                  icon: Icons.currency_exchange_rounded,
                  title: l10n.paymentsExchangeTitle,
                  subtitle: l10n.paymentsExchangeBody,
                  onTap: () => _push(ExchangeScreen(userId: widget.userId)),
                ),
                ListRow(
                  icon: Icons.event_repeat_rounded,
                  title: l10n.paymentsScheduledTitle,
                  subtitle: l10n.paymentsScheduledBody,
                  onTap: () => _push(ScheduledTransfersScreen(userId: widget.userId)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
