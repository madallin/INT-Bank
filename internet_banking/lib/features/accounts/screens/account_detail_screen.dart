import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/privacy_mode_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/bank_account.dart';
import '../../../data/models/transaction_entry.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../widgets/transaction_list_item.dart';
import '../../analytics/screens/spending_analytics_screen.dart';
import '../../statement/screens/statement_screen.dart';
import '../../transactions/screens/transaction_history_screen.dart';
import '../../transactions/widgets/transaction_details_bottom_sheet.dart';
import '../../transfer/screens/transfer_screen.dart';

/// One account: balance, IBAN to share, what you can do with it and its latest activity.
class AccountDetailScreen extends StatefulWidget
{
  const AccountDetailScreen({super.key, required this.userId, required this.account});

  final int userId;
  final BankAccount account;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
{
  late BankAccount _account = widget.account;
  List<Map<String, dynamic>> _recent = const [];
  bool _loadingRecent = true;

  @override
  void initState()
  {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async
  {
    await Future.wait([_loadAccount(), _loadRecent()]);
  }

  Future<void> _loadAccount() async
  {
    try
    {
      final account = await BankAccount.fetch(widget.userId, _account.id);
      if(mounted) setState(() => _account = account);
    }
    catch(_)
    {
      // Keep showing the balance we already have.
    }
  }

  Future<void> _loadRecent() async
  {
    try
    {
      final response = await DioClient().get('/users/${widget.userId}/accounts/${_account.id}/transactions');
      final data = response.data as Map<String, dynamic>;
      final all = List<Map<String, dynamic>>.from(data['transactions'] as List? ?? const []);
      if(mounted) setState(() => _recent = all.take(5).toList());
    }
    catch(_)
    {
      if(mounted) setState(() => _recent = const []);
    }
    finally
    {
      if(mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _copyIban() async
  {
    await Clipboard.setData(ClipboardData(text: _account.iban));
    HapticFeedbackHelper.selection();
    if(mounted) showSuccessSnackBar(context, context.l10n.accountsIbanCopied);
  }

  Future<void> _push(Widget screen) async
  {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: l10n.accountsCurrentAccount(_account.currency)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ValueListenableBuilder<bool>(
          valueListenable: PrivacyModeService().isPrivacyModeEnabled,
          builder: (context, hidden, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _BalanceHero(account: _account, hidden: hidden, onCopyIban: _copyIban),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _Action(
                    icon: Icons.send_rounded,
                    label: l10n.commonTransfer,
                    onTap: () => _push(TransferScreen(
                      userId: widget.userId,
                      userIban: _account.iban,
                      currency: _account.currency,
                      availableBalance: _account.balance,
                    )),
                  ),
                  _Action(
                    icon: Icons.receipt_long_rounded,
                    label: l10n.homeIstoric,
                    onTap: () => _push(TransactionHistoryScreen(
                      userId: widget.userId,
                      accountId: _account.id,
                      currency: _account.currency,
                    )),
                  ),
                  _Action(
                    icon: Icons.description_outlined,
                    label: l10n.homeExtras,
                    onTap: () => _push(StatementScreen(
                      userId: widget.userId,
                      accountId: _account.id,
                      iban: _account.iban,
                      currency: _account.currency,
                    )),
                  ),
                  _Action(
                    icon: Icons.pie_chart_outline_rounded,
                    label: l10n.homeStatistici,
                    onTap: () => _push(SpendingAnalyticsScreen(
                      userId: widget.userId,
                      accountId: _account.id,
                      currency: _account.currency,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.homeTranzactiiRecente, style: context.text.titleMedium),
                    ),
                  ),
                  if(_recent.isNotEmpty)
                    TextButton(
                      onPressed: () => _push(TransactionHistoryScreen(
                        userId: widget.userId,
                        accountId: _account.id,
                        currency: _account.currency,
                      )),
                      child: Text(l10n.homeVeziToate),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if(_loadingRecent)
                const ShimmerLoading(
                  child: Column(
                    children: [
                      SkeletonBox(height: 64, borderRadius: AppRadii.md),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(height: 64, borderRadius: AppRadii.md),
                    ],
                  ),
                )
              else if(_recent.isEmpty)
                EmptyStatePlaceholder(icon: Icons.receipt_long_outlined, title: l10n.homeExistaTranzactiiRecente)
              else
                for(final tx in _recent) _recentRow(context, tx, hidden),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentRow(BuildContext context, Map<String, dynamic> tx, bool hidden)
  {
    final entry = TransactionEntry.fromJson(tx);
    final currency = entry.currency ?? _account.currency;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => TransactionDetailsBottomSheet.show(context, tx),
        child: TransactionListItem(
          beneficiary: entry.title,
          date: entry.date == null ? '' : formatDate(entry.date!),
          amount: hidden ? maskedMoney(currency) : formatMoney(entry.signedAmount, currency, showSign: true),
          isPositive: entry.isIncoming,
          category: entry.category,
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget
{
  const _BalanceHero({required this.account, required this.hidden, required this.onCopyIban});

  final BankAccount account;
  final bool hidden;
  final VoidCallback onCopyIban;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    const onHero = Colors.white;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.heroStart, c.heroEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.commonSoldDisponibil, style: context.text.labelMedium?.copyWith(color: onHero.withValues(alpha: 0.85))),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? maskedMoney(account.currency) : formatMoney(account.balance, account.currency),
              style: context.text.headlineMedium?.copyWith(color: onHero, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IBAN', style: context.text.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.85))),
                    SelectableText(
                      formatIban(account.iban),
                      style: context.text.bodyMedium?.copyWith(color: onHero, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCopyIban,
                tooltip: context.l10n.accountsCopyIban,
                icon: const Icon(Icons.copy_rounded, color: onHero),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget
{
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () {
            HapticFeedbackHelper.buttonTap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: c.brandSurface, borderRadius: BorderRadius.circular(AppRadii.md)),
                  child: Icon(icon, color: c.brand),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
