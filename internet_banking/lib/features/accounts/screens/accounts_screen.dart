import 'package:flutter/material.dart';

import '../../../core/services/privacy_mode_service.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bank_account.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../home/widgets/open_currency_account_dialog.dart';
import '../../shell/app_shell.dart';
import 'account_detail_screen.dart';

/// Accounts tab: every current account with its balance; tapping one opens its details.
class AccountsScreen extends StatefulWidget
{
  const AccountsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with ReloadWhenTabShown
{
  @override
  AppTab get tab => AppTab.accounts;

  @override
  void onTabShown() => _load();

  List<BankAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

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

  Future<void> _open(BankAccount account) async
  {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountDetailScreen(userId: widget.userId, account: account),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: context.l10n.accountsTitle),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context)
  {
    if(_loading) return const _AccountsSkeleton();
    if(_error != null) return ErrorRetryView(message: _error!, onRetry: () { setState(() => _loading = true); _load(); });

    return RefreshIndicator(
      onRefresh: _load,
      child: ValueListenableBuilder<bool>(
        valueListenable: PrivacyModeService().isPrivacyModeEnabled,
        builder: (context, hidden, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if(_accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: EmptyStatePlaceholder(icon: Icons.account_balance_wallet_outlined, title: context.l10n.accountsEmpty),
              ),
            for(final account in _accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AccountTile(account: account, hidden: hidden, onTap: () => _open(account)),
              ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: context.l10n.accountsOpenCurrency,
              icon: Icons.add_rounded,
              variant: AppButtonVariant.outline,
              onPressed: () => OpenCurrencyAccountDialog.show(context, userId: widget.userId, onAccountCreated: _load),
            ),
          ],
        ),
      ),
    );
  }
}

/// An account with its currency, IBAN and balance.
class AccountTile extends StatelessWidget
{
  const AccountTile({super.key, required this.account, required this.hidden, this.onTap, this.selected});

  final BankAccount account;
  final bool hidden;
  final VoidCallback? onTap;

  /// Set when the tile is one choice of a picker (Payments tab); null when it opens the account.
  final bool? selected;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final selected = this.selected ?? false;
    final name = context.l10n.accountsCurrentAccount(account.currency);
    final balance = hidden ? maskedMoney(account.currency) : formatMoney(account.balance, account.currency);
    return Semantics(
      button: onTap != null,
      selected: this.selected,
      inMutuallyExclusiveGroup: this.selected != null,
      label: '$name, $balance',
      excludeSemantics: true,
      child: Material(
        color: selected ? c.brandSurface : c.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                CurrencyBadge(currency: account.currency),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.text.labelMedium?.copyWith(color: c.textSecondary)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(balance, style: context.text.titleMedium),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatIban(account.iban),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ExcludeSemantics(
                  child: switch(this.selected)
                  {
                    true => Icon(Icons.check_circle_rounded, color: c.brand),
                    false => Icon(Icons.radio_button_unchecked_rounded, color: c.textMuted),
                    null => Icon(Icons.chevron_right_rounded, color: c.textMuted),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round badge with the currency code.
class CurrencyBadge extends StatelessWidget
{
  const CurrencyBadge({super.key, required this.currency, this.size = 44});

  final String currency;
  final double size;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.brandSurface, shape: BoxShape.circle),
        child: Text(
          currency,
          style: context.text.labelMedium?.copyWith(color: c.brand, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AccountsSkeleton extends StatelessWidget
{
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context)
  {
    return ShimmerLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for(var i = 0; i < 2; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: SkeletonBox(height: 78, borderRadius: AppRadii.lg),
            ),
        ],
      ),
    );
  }
}
