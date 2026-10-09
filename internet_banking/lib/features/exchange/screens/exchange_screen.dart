import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../home/widgets/open_currency_account_dialog.dart';
import '../../../services/currency_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/success_badge.dart';
import '../../accounts/screens/accounts_screen.dart' show CurrencyBadge;
import '../../../widgets/simple_app_bar.dart';
import '../../../l10n/l10n.dart';

class ExchangeScreen extends StatefulWidget {
  final int userId;

  const ExchangeScreen({super.key, required this.userId});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();
  final DioClient _dioClient = DioClient();

  List<Map<String, dynamic>> _userAccounts = [];
  bool _isExecuting = false;

  String _fromCurrency = 'RON';
  String _toCurrency = 'EUR';

  double _originalRate = 0.0;
  double _rateWithCommission = 0.0;
  double _commissionAmount = 0.0;
  bool _hasRate = false;

  AnimationController? _swapController;
  Animation<double>? _swapAnimation;

  static const _currencies = ['RON', 'EUR', 'USD', 'GBP'];

  @override
  void initState() {
    super.initState();
    _swapController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _swapAnimation =
        CurvedAnimation(parent: _swapController!, curve: Curves.easeInOut);

    _fetchAccounts();
    if (!CurrencyService.instance.hasRates) {
      CurrencyService.instance.fetchRates().then((_) {
        if (mounted) _recalculate();
      });
    } else {
      _recalculate();
    }

    _fromAmountController.addListener(_onFromAmountChanged);
  }

  @override
  void dispose() {
    _swapController?.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    try {
      final response = await _dioClient.get('/users/${widget.userId}/accounts');
      if (response.statusCode == 200 && response.data != null) {
        // The API wraps the list: {"accounts": [...]}.
        final data = response.data;
        final raw = data is Map ? data['accounts'] : data;
        final list = raw is List
            ? raw.whereType<Map>().map((a) => Map<String, dynamic>.from(a)).toList()
            : <Map<String, dynamic>>[];
        if (mounted) {
          setState(() {
            _userAccounts = list;
          });
        }
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _getAccountForCurrency(String cur) {
    for (final a in _userAccounts) {
      final m = (a['moneda'] ?? a['currency'] ?? '').toString().toUpperCase();
      if (m == cur.toUpperCase()) return a;
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    showErrorSnackBar(context, message);
  }

  Future<void> _showDone({required String paid, required String received}) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessBadge(size: 72),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(sheet.l10n.exchangeDone, style: sheet.text.titleLarge, textAlign: TextAlign.center),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('$paid  →  $received', style: sheet.text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: sheet.l10n.receiptGata, onPressed: () => Navigator.of(sheet).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndExecuteExchange() async {
    final fromAcc = _getAccountForCurrency(_fromCurrency);
    final toAcc = _getAccountForCurrency(_toCurrency);

    if (fromAcc == null) {
      _showError(context.l10n.exchangeContActiv(_fromCurrency));
      return;
    }
    if (toAcc == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(context.l10n.exchangeContInexistent(_toCurrency), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text(context.l10n.exchangeCumparaTrebuieSaDeschizi(_toCurrency), style: GoogleFonts.inter()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonInchide, style: GoogleFonts.inter(color: context.colors.textMuted))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenCurrencyAccountDialog.show(
                  context,
                  userId: widget.userId,
                  onAccountCreated: _fetchAccounts,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.brand),
              child: Text(context.l10n.exchangeDeschideCont, style: GoogleFonts.inter(color: context.colors.onBrand, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    final amount = parseAmount(_fromAmountController.text) ?? 0.0;
    if (amount <= 0) {
      _showError(context.l10n.exchangeIntroduSumaValidaSchimb);
      return;
    }

    final available = (fromAcc['sold'] as num?)?.toDouble() ?? 0.0;
    if (amount > available) {
      _showError(context.l10n.exchangeFonduriInsuficienteDisponibil(formatMoney(available, _fromCurrency)));
      return;
    }

    // The bank prices the exchange first; the customer confirms exactly these numbers.
    setState(() => _isExecuting = true);
    final Map<String, dynamic> quote;
    try {
      final response = await _dioClient.post(
        '/currency/api/v1/users/${widget.userId}/exchange/quote',
        data: {'fromAccountId': fromAcc['id'], 'toAccountId': toAcc['id'], 'amount': amount},
      );
      quote = Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.exchangeSchimbulValutarPututFi));
      return;
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
    if (!mounted) return;
    final quotedSource = (quote['sourceAmount'] as num).toDouble();
    final quotedDestination = (quote['destinationAmount'] as num).toDouble();
    final quotedRate = (quote['rate'] as num).toDouble();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(context.l10n.exchangeConfirmaSchimbulValutar, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangePlatesti, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text(formatMoney(quotedSource, _fromCurrency), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: context.colors.danger)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangePrimesti, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text(formatMoney(quotedDestination, _toCurrency), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: context.colors.brand)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangeCursSchimb, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text('1 $_fromCurrency = ${formatRate(quotedRate)} $_toCurrency', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangeComisionTranzactie, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      // The quote is what the bank books; it includes no fee.
                      Text(context.l10n.exchangeGratuit, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.colors.brand, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.exchangeQuoteValidity,
                      style: GoogleFonts.inter(color: context.colors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.l10n.commonAnuleaza, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _executeExchange(
                        quote['quoteId'] as String,
                        paid: formatMoney(quotedSource, _fromCurrency),
                        received: formatMoney(quotedDestination, _toCurrency),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: context.colors.brand, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.l10n.commonConfirma, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: context.colors.onBrand)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeExchange(String quoteId, {required String paid, required String received}) async {
    setState(() => _isExecuting = true);
    try {
      final response = await _dioClient.post(
        '/currency/api/v1/users/${widget.userId}/exchange/internal',
        data: {'quoteId': quoteId},
      );

      if (response.statusCode == 200) {
        _fromAmountController.clear();
        _toAmountController.clear();
        await _fetchAccounts();
        if (mounted) await _showDone(paid: paid, received: received);
      } else {
        _showError(AppL10n.current.exchangeEroareRealizareaSchimbuluiValutar);
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.exchangeSchimbulValutarPututFi));
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  // Local arithmetic on cached rates: update as the customer types.
  void _onFromAmountChanged() => _recalculate();

  void _recalculate() {
    final service = CurrencyService.instance;
    final rate = service.getRate(_fromCurrency, _toCurrency);

    if (rate == null) {
      setState(() => _hasRate = false);
      return;
    }

    final amount =
        parseAmount(_fromAmountController.text) ?? 0;

    setState(() {
      _originalRate = rate;
      _rateWithCommission = rate * (1 - service.commissionPercent / 100);
      _commissionAmount =
          amount * rate * (service.commissionPercent / 100);
      _hasRate = true;

      final result = amount * _rateWithCommission;
      // Empty until there is something to convert, so the faint 0,00 hint shows.
      _toAmountController.text = amount > 0 ? formatAmount(result) : '';
    });
  }

  void _swapCurrencies() {
    _swapController!.forward().then((_) {
      setState(() {
        final temp = _fromCurrency;
        _fromCurrency = _toCurrency;
        _toCurrency = temp;

        if (_toAmountController.text.isNotEmpty) {
          _fromAmountController.text = _toAmountController.text;
        }
      });
      _recalculate();
      _swapController!.reverse();
    });
  }

  /// Picking the currency already on the other side swaps the two, so they never match.
  void _setCurrency({required bool sell, required String value}) {
    setState(() {
      if (sell) {
        if (value == _toCurrency) _toCurrency = _fromCurrency;
        _fromCurrency = value;
      } else {
        if (value == _fromCurrency) _fromCurrency = _toCurrency;
        _toCurrency = value;
      }
    });
    _recalculate();
  }

  double? _balanceOf(String currency) {
    final sold = _getAccountForCurrency(currency)?['sold'];
    return sold is num ? sold.toDouble() : double.tryParse('$sold');
  }

  String _currencyName(String code) => switch (code) {
        'RON' => context.l10n.currencyRon,
        'EUR' => context.l10n.openCurrencyEuro,
        'USD' => context.l10n.openCurrencyDolarAmerican,
        'GBP' => context.l10n.openCurrencyLiraSterlina,
        _ => code,
      };

  Future<void> _pickCurrency({required bool sell}) async {
    final current = sell ? _fromCurrency : _toCurrency;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
              child: Semantics(header: true, child: Text(sheet.l10n.exchangeChooseCurrency, style: sheet.text.titleMedium)),
            ),
            for (final code in _currencies)
              Semantics(
                selected: code == current,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  leading: CurrencyBadge(currency: code, size: 40),
                  title: Text(_currencyName(code)),
                  subtitle: Text(_balanceOf(code) == null
                      ? sheet.l10n.exchangeNoAccount(code)
                      : sheet.l10n.exchangeBalance(formatMoney(_balanceOf(code)!, code))),
                  trailing: code == current ? Icon(Icons.check_rounded, color: sheet.colors.brand) : null,
                  onTap: () => Navigator.of(sheet).pop(code),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) _setCurrency(sell: sell, value: picked);
  }

  void _useWholeBalance() {
    final balance = _balanceOf(_fromCurrency);
    if (balance == null) return;
    _fromAmountController.text = formatAmount(balance);
  }

  /// One side of the exchange: the currency (tap to change), its balance, and the amount.
  Widget _buildSide({required bool sell}) {
    final c = context.colors;
    final currency = sell ? _fromCurrency : _toCurrency;
    final balance = _balanceOf(currency);
    final big = context.text.headlineMedium!.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxs),
      decoration: BoxDecoration(
        color: sell ? c.surface : c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(sell ? context.l10n.exchangeSell : context.l10n.exchangeBuy, style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Semantics(
                button: true,
                label: '${context.l10n.exchangeChooseCurrency}: ${_currencyName(currency)}',
                excludeSemantics: true,
                child: Material(
                  color: c.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  child: InkWell(
                    key: ValueKey(sell ? 'sell-currency' : 'buy-currency'),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    onTap: () => _pickCurrency(sell: sell),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: kMinTapTarget),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xs, AppSpacing.xxs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrencyBadge(currency: currency, size: 36),
                            const SizedBox(width: AppSpacing.xxs),
                            Icon(Icons.keyboard_arrow_down_rounded, color: c.brand),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: sell ? _fromAmountController : _toAmountController,
                  // The bought amount is worked out from the rate; it is only read.
                  readOnly: !sell,
                  canRequestFocus: sell,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: sell ? [AmountInputFormatter()] : null,
                  textAlign: TextAlign.end,
                  style: big,
                  decoration: InputDecoration(
                    hintText: '0,00',
                    hintStyle: big.copyWith(color: c.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    constraints: const BoxConstraints(minHeight: kMinTapTarget),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  balance == null
                      ? context.l10n.exchangeNoAccount(currency)
                      : context.l10n.exchangeBalance(formatMoney(balance, currency)),
                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ),
              if (sell && balance != null && balance > 0)
                TextButton(onPressed: _useWholeBalance, child: Text(context.l10n.exchangeAll))
              else if (!sell && balance == null)
                TextButton(
                  onPressed: () => OpenCurrencyAccountDialog.show(context, userId: widget.userId, onAccountCreated: _fetchAccounts),
                  child: Text(context.l10n.exchangeDeschideCont),
                )
              else
                const SizedBox(height: kMinTapTarget),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRate() {
    final c = context.colors;
    final service = CurrencyService.instance;
    if (!service.hasRates) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    if (!_hasRate) {
      return Text(
        context.l10n.exchangeCursulValutarEsteDisponibil,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: c.danger),
      );
    }
    final fee = service.commissionPercent;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.xl)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up_rounded, size: 16, color: c.brand),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    '1 $_fromCurrency = ${formatRate(_originalRate)} $_toCurrency',
                    style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ],
              ),
            ),
            Text(
              fee == 0
                  ? context.l10n.exchangeNoFee
                  : context.l10n.exchangeComision(formatPercent(fee), formatMoney(_commissionAmount, _toCurrency)),
              style: context.text.bodySmall?.copyWith(color: fee == 0 ? c.positive : c.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (fee != 0) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.l10n.exchangeRataEfectiva1(_fromCurrency, formatRate(_rateWithCommission), _toCurrency),
            style: context.text.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(context.l10n.exchangeEstimateNote, textAlign: TextAlign.center, style: context.text.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = CurrencyService.instance;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: context.l10n.exchangeSchimbValutar),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // The swap button sits on the seam between the two cards.
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          _buildSide(sell: true),
                          const SizedBox(height: AppSpacing.xs),
                          _buildSide(sell: false),
                        ],
                      ),
                      RotationTransition(
                        turns: _swapAnimation!,
                        child: Material(
                          color: c.surface,
                          shape: CircleBorder(side: BorderSide(color: c.border, width: 1.5)),
                          elevation: 2,
                          shadowColor: c.shadow,
                          child: IconButton(
                            tooltip: context.l10n.exchangeInverseazaValutele,
                            icon: Icon(Icons.swap_vert_rounded, color: c.brand),
                            onPressed: _swapCurrencies,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildRate(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
              child: AppButton(
                label: context.l10n.exchangeSchimbaValuta,
                isLoading: _isExecuting,
                onPressed: (!service.hasRates || !_hasRate) ? null : _confirmAndExecuteExchange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
