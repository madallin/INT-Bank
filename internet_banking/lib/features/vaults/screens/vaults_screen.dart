import 'package:flutter/material.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../shell/app_shell.dart';
import '../data/vault_api.dart';

/// Savings vaults: money set aside in the customer's own savings accounts at INTBank.
class VaultsScreen extends StatefulWidget
{
  const VaultsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> with ReloadWhenTabShown
{
  late final VaultApi _api = VaultApi(widget.userId);

  @override
  AppTab get tab => AppTab.savings;

  @override
  void onTabShown() => _load();
  List<Vault> _vaults = [];
  List<VaultAccount> _accounts = [];
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
    setState(()
    {
      _loading = true;
      _error = null;
    });
    try
    {
      final results = await Future.wait([_api.list(), _api.accounts()]);
      if(!mounted) return;
      setState(()
      {
        _vaults = results[0] as List<Vault>;
        _accounts = results[1] as List<VaultAccount>;
        _loading = false;
      });
    }
    catch(e)
    {
      if(!mounted) return;
      setState(()
      {
        _error = friendlyErrorMessage(e, fallback: context.l10n.vaultsLoadError);
        _loading = false;
      });
    }
  }

  List<VaultAccount> _accountsIn(String currency) => _accounts.where((a) => a.currency == currency).toList();

  Future<void> _openCreate() async
  {
    final created = await showModalBottomSheet<Vault>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateVaultSheet(api: _api, accounts: _accounts),
    );
    if(created == null || !mounted) return;
    showSuccessSnackBar(context, context.l10n.vaultsCreated(created.name));
    _load();
  }

  Future<void> _openMove(Vault vault, {required bool deposit}) async
  {
    final accounts = _accountsIn(vault.currency);
    if(accounts.isEmpty)
    {
      showErrorSnackBar(context, context.l10n.vaultsNoAccount(vault.currency));
      return;
    }
    final moved = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveMoneySheet(api: _api, vault: vault, accounts: accounts, deposit: deposit),
    );
    if(moved == null || !mounted) return;
    final amount = formatMoney(moved, vault.currency);
    showSuccessSnackBar(
      context,
      deposit ? context.l10n.vaultsDeposited(amount, vault.name) : context.l10n.vaultsWithdrawn(amount, vault.name),
    );
    _load();
  }

  Future<void> _close(Vault vault) async
  {
    final accounts = _accountsIn(vault.currency);
    if(accounts.isEmpty)
    {
      showErrorSnackBar(context, context.l10n.vaultsNoAccount(vault.currency));
      return;
    }
    final account = accounts.first;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.vaultsCloseTitle(vault.name),
      message: context.l10n.vaultsCloseMessage(formatMoney(vault.balance, vault.currency), formatIban(account.iban)),
      confirmLabel: context.l10n.vaultsClose,
      destructive: true,
    );
    if(!confirmed || !mounted) return;
    try
    {
      await _api.close(vault.id, accountId: account.id);
      if(!mounted) return;
      HapticFeedbackHelper.success();
      showSuccessSnackBar(context, context.l10n.vaultsClosed(vault.name));
      _load();
    }
    catch(e)
    {
      if(mounted) showErrorSnackBar(context, friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: context.l10n.vaultsTitle),
      floatingActionButton: _loading || _error != null || _accounts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: c.brand,
              foregroundColor: c.onBrand,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.vaultsNew),
            ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context)
  {
    if(_loading) return const Center(child: CircularProgressIndicator());
    if(_error != null) return ErrorRetryView(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
        children: [
          _Summary(vaults: _vaults),
          const SizedBox(height: AppSpacing.lg),
          if(_vaults.isEmpty)
            _EmptyState()
          else
            for(final vault in _vaults)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _VaultCard(
                  key: ValueKey('vault-${vault.id}'),
                  vault: vault,
                  onDeposit: () => _openMove(vault, deposit: true),
                  onWithdraw: () => _openMove(vault, deposit: false),
                  onClose: () => _close(vault),
                ),
              ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget
{
  const _Summary({required this.vaults});

  final List<Vault> vaults;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final totals = <String, double>{};
    for(final v in vaults)
    {
      totals.update(v.currency, (sum) => sum + v.balance, ifAbsent: () => v.balance);
    }
    if(totals.isEmpty) totals['RON'] = 0;

    // Hero panels use white text in both themes (checked in test/theme/contrast_test.dart).
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.heroStart, c.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.vaultsTotalSaved,
              style: context.text.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: AppSpacing.xxs),
          for(final entry in totals.entries)
            Text(
              formatMoney(entry.value, entry.key),
              style: context.text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(context.l10n.vaultsNoInterestNote,
              style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget
{
  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 56, color: c.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(context.l10n.vaultsEmptyTitle, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.vaultsEmptyBody,
            style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VaultCard extends StatelessWidget
{
  const _VaultCard({super.key, required this.vault, required this.onDeposit, required this.onWithdraw, required this.onClose});

  final Vault vault;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    final badge = vault.lockedToday && vault.targetDate != null
        ? l10n.vaultsLockedUntil(formatDate(vault.targetDate!))
        : l10n.vaultsFlexible;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(vault.lockedToday ? Icons.lock_outline_rounded : Icons.savings_outlined, color: c.brand),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(vault.name, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.vaultsMoreActions(vault.name),
                onSelected: (_) => onClose(),
                itemBuilder: (_) => [PopupMenuItem(value: 'close', child: Text(l10n.vaultsClose))],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              _Chip(label: badge, color: vault.lockedToday ? c.textSecondary : c.positive),
              if(vault.goalReached) _Chip(label: l10n.vaultsGoalReached, color: c.positive),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(formatMoney(vault.balance, vault.currency),
              style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: l10n.vaultsProgress(formatMoney(vault.balance, vault.currency), formatMoney(vault.targetAmount, vault.currency)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: vault.progress,
                minHeight: 8,
                backgroundColor: c.surfaceMuted,
                color: c.brand,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          ExcludeSemantics(
            child: Text(
              l10n.vaultsProgress(formatMoney(vault.balance, vault.currency), formatMoney(vault.targetAmount, vault.currency)),
              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
          if(vault.targetDate != null && !vault.lockedToday)
            Text(l10n.vaultsTargetBy(formatDate(vault.targetDate!)),
                style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.vaultsDeposit,
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: onDeposit,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: l10n.vaultsWithdraw,
                  icon: Icons.remove_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: vault.lockedToday || vault.balance <= 0 ? null : onWithdraw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget
{
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(label, style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

/// Bottom-sheet frame shared by the vault forms.
class _Sheet extends StatelessWidget
{
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget
{
  const _AccountPicker({required this.label, required this.accounts, required this.selected, required this.onChanged});

  final String label;
  final List<VaultAccount> accounts;
  final VaultAccount selected;
  final ValueChanged<VaultAccount> onChanged;

  @override
  Widget build(BuildContext context)
  {
    return DropdownButtonFormField<int>(
      initialValue: selected.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for(final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${formatIban(a.iban)} · ${formatMoney(a.balance, a.currency)}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) => onChanged(accounts.firstWhere((a) => a.id == id)),
    );
  }
}

class _MoveMoneySheet extends StatefulWidget
{
  const _MoveMoneySheet({required this.api, required this.vault, required this.accounts, required this.deposit});

  final VaultApi api;
  final Vault vault;
  final List<VaultAccount> accounts;
  final bool deposit;

  @override
  State<_MoveMoneySheet> createState() => _MoveMoneySheetState();
}

class _MoveMoneySheetState extends State<_MoveMoneySheet>
{
  final _amount = TextEditingController();
  late VaultAccount _account = widget.accounts.first;
  String? _error;
  bool _busy = false;

  double get _available => widget.deposit ? _account.balance : widget.vault.balance;

  @override
  void dispose()
  {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async
  {
    final l10n = context.l10n;
    final amount = parseAmount(_amount.text);
    if(amount == null || amount <= 0)
    {
      setState(() => _error = l10n.vaultsAmountInvalid);
      return;
    }
    if(amount > _available)
    {
      setState(() => _error = l10n.vaultsAmountTooHigh(formatMoney(_available, widget.vault.currency)));
      return;
    }
    setState(()
    {
      _busy = true;
      _error = null;
    });
    try
    {
      if(widget.deposit)
      {
        await widget.api.deposit(widget.vault.id, accountId: _account.id, amount: amount);
      }
      else
      {
        await widget.api.withdraw(widget.vault.id, accountId: _account.id, amount: amount);
      }
      HapticFeedbackHelper.success();
      if(mounted) Navigator.of(context).pop(amount);
    }
    catch(e)
    {
      if(mounted)
      {
        setState(()
        {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final l10n = context.l10n;
    return _Sheet(
      title: widget.deposit ? l10n.vaultsDepositTitle(widget.vault.name) : l10n.vaultsWithdrawTitle(widget.vault.name),
      children: [
        _AccountPicker(
          label: widget.deposit ? l10n.vaultsFromAccount : l10n.vaultsToAccount,
          accounts: widget.accounts,
          selected: _account,
          onChanged: (a) => setState(() => _account = a),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountInputFormatter()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.vaultsAmount(widget.vault.currency),
            helperText: l10n.vaultsAvailable(formatMoney(_available, widget.vault.currency)),
            errorText: _error,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: l10n.vaultsConfirm, isLoading: _busy, onPressed: _busy ? null : _submit),
      ],
    );
  }
}

class _CreateVaultSheet extends StatefulWidget
{
  const _CreateVaultSheet({required this.api, required this.accounts});

  final VaultApi api;
  final List<VaultAccount> accounts;

  @override
  State<_CreateVaultSheet> createState() => _CreateVaultSheetState();
}

class _CreateVaultSheetState extends State<_CreateVaultSheet>
{
  final _name = TextEditingController();
  final _target = TextEditingController();
  late VaultAccount _account = widget.accounts.first;
  bool _locked = false;
  DateTime? _targetDate;
  String? _nameError;
  String? _targetError;
  String? _dateError;
  String? _error;
  bool _busy = false;

  @override
  void dispose()
  {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async
  {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 3, now.day),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 30),
    );
    if(picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async
  {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    setState(()
    {
      _nameError = name.isEmpty || name.length > 60 ? l10n.vaultsNameInvalid : null;
      _targetError = target == null || target <= 0 ? l10n.vaultsAmountInvalid : null;
      _dateError = _locked && _targetDate == null ? l10n.vaultsTargetDateRequired : null;
      _error = null;
    });
    if(_nameError != null || _targetError != null || _dateError != null) return;

    setState(() => _busy = true);
    try
    {
      final vault = await widget.api.create(
        name: name,
        targetAmount: target!,
        sourceAccountId: _account.id,
        locked: _locked,
        targetDate: _targetDate,
      );
      HapticFeedbackHelper.success();
      if(mounted) Navigator.of(context).pop(vault);
    }
    catch(e)
    {
      if(mounted)
      {
        setState(()
        {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final l10n = context.l10n;
    final c = context.colors;
    return _Sheet(
      title: l10n.vaultsNew,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.vaultsNameLabel, hintText: l10n.vaultsNameHint, errorText: _nameError),
        ),
        const SizedBox(height: AppSpacing.xs),
        _AccountPicker(
          label: l10n.vaultsFromAccount,
          accounts: widget.accounts,
          selected: _account,
          onChanged: (a) => setState(() => _account = a),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountInputFormatter()],
          decoration: InputDecoration(labelText: l10n.vaultsTargetLabel(_account.currency), errorText: _targetError),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.vaultsTypeFlexible), icon: const Icon(Icons.savings_outlined)),
            ButtonSegment(value: true, label: Text(l10n.vaultsTypeLocked), icon: const Icon(Icons.lock_outline_rounded)),
          ],
          selected: {_locked},
          onSelectionChanged: (s) => setState(() => _locked = s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _locked ? l10n.vaultsTypeLockedHint : l10n.vaultsTypeFlexibleHint,
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event_outlined),
          label: Text(_targetDate == null
              ? l10n.vaultsTargetDateNone
              : '${l10n.vaultsTargetDateLabel}: ${formatDate(_targetDate!)}'),
        ),
        if(_dateError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(_dateError!, style: context.text.bodySmall?.copyWith(color: c.danger)),
          ),
        if(_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: c.danger)),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: l10n.vaultsCreate, isLoading: _busy, onPressed: _busy ? null : _submit),
      ],
    );
  }
}
