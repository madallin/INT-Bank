import '../../../theme/app_tokens.dart';
import 'dart:async';

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
import '../../../widgets/circular_icon_badge.dart';
import '../../../widgets/section_header.dart';
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

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  AnimationController? _swapController;
  Animation<double>? _swapAnimation;

  Timer? _debounce;

  final Map<String, String> _currencySymbols = {
    'RON': 'lei',
    'EUR': '€',
    'USD': r'$',
    'GBP': '£',
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController!, curve: Curves.easeInOut);
    _fadeController!.forward();

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
    _debounce?.cancel();
    _fadeController?.dispose();
    _swapController?.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    try {
      final response = await _dioClient.get('/users/${widget.userId}/accounts');
      if (response.statusCode == 200 && response.data != null) {
        final list = List<Map<String, dynamic>>.from(response.data as List);
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

  void _showSuccess(String message) {
    if (!mounted) return;
    showSuccessSnackBar(context, message);
  }

  void _confirmAndExecuteExchange() {
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

    final amount = parseRomanianNumber(_fromAmountController.text) ?? 0.0;
    if (amount <= 0) {
      _showError(context.l10n.exchangeIntroduSumaValidaSchimb);
      return;
    }

    final available = (fromAcc['sold'] as num?)?.toDouble() ?? 0.0;
    if (amount > available) {
      _showError(context.l10n.exchangeFonduriInsuficienteDisponibil(formatMoney(available, _fromCurrency)));
      return;
    }

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
                      Text(formatMoney(amount, _fromCurrency), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: context.colors.danger)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangePrimesti, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text('${_toAmountController.text} $_toCurrency', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: context.colors.brand)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangeCursSchimb, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text('1 $_fromCurrency = ${formatRate(_originalRate)} $_toCurrency', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.exchangeComisionTranzactie, style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13)),
                      Text(_commissionAmount == 0 ? context.l10n.exchangeGratuit : '${formatMoney(_commissionAmount, _toCurrency)} (${formatPercent(CurrencyService.instance.commissionPercent)})', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.colors.brand, fontSize: 13)),
                    ],
                  ),
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
                      await _executeExchange(fromAcc['id'], toAcc['id'], amount);
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

  Future<void> _executeExchange(dynamic fromId, dynamic toId, double amount) async {
    setState(() => _isExecuting = true);
    try {
      final response = await _dioClient.post(
        '/currency/api/v1/users/${widget.userId}/exchange/internal',
        data: {
          'fromAccountId': fromId,
          'toAccountId': toId,
          'amount': amount,
        },
      );

      if (response.statusCode == 200) {
        _showSuccess(AppL10n.current.exchangeSchimbValutarRealizatSucces);
        _fromAmountController.clear();
        _toAmountController.clear();
        await _fetchAccounts();
      } else {
        _showError(AppL10n.current.exchangeEroareRealizareaSchimbuluiValutar);
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.exchangeSchimbulValutarPututFi));
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  void _onFromAmountChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _recalculate();
    });
  }

  void _recalculate() {
    final service = CurrencyService.instance;
    final rate = service.getRate(_fromCurrency, _toCurrency);

    if (rate == null) {
      setState(() => _hasRate = false);
      return;
    }

    final amount =
        parseRomanianNumber(_fromAmountController.text) ?? 0;

    setState(() {
      _originalRate = rate;
      _rateWithCommission = rate * (1 - service.commissionPercent / 100);
      _commissionAmount =
          amount * rate * (service.commissionPercent / 100);
      _hasRate = true;

      final result = amount * _rateWithCommission;
      _toAmountController.text = formatAmount(result);
    });
  }

  void _swapCurrencies() {
    _swapController!.forward().then((_) {
      setState(() {
        final temp = _fromCurrency;
        _fromCurrency = _toCurrency;
        _toCurrency = temp;

        final tempAmount = _fromAmountController.text;
        _fromAmountController.text = _toAmountController.text;
        _toAmountController.text = tempAmount;
      });
      _recalculate();
      _swapController!.reverse();
    });
  }

  void _onFromCurrencyChanged(String? value) {
    if (value == null) return;
    setState(() => _fromCurrency = value);
    _recalculate();
  }

  void _onToCurrencyChanged(String? value) {
    if (value == null) return;
    setState(() => _toCurrency = value);
    _recalculate();
  }

  Widget _buildCurrencyInput({
    required String label,
    required TextEditingController controller,
    required String currency,
    required ValueChanged<String?> onCurrencyChanged,
  }) {
    final currencyKeys = _currencySymbols.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 110,
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: context.colors.border, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currency,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: context.colors.textMuted, size: 20),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                  items: currencyKeys.map((curr) {
                    return DropdownMenuItem<String>(
                        value: curr, child: Text(curr));
                  }).toList(),
                  onChanged: onCurrencyChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [RomanianAmountInputFormatter()],
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: context.colors.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: context.colors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: context.colors.brand,
                        width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
                  hintText: '0,00',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = CurrencyService.instance;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: context.l10n.exchangeSchimbValutar,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0),
                child: _fadeAnimation != null
                    ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            const CircularIconBadge(
                              icon:
                                  Icons.currency_exchange_rounded,
                              size: 90,
                            ),
                            const SizedBox(height: 40),
                            PageTitle(
                              title: context.l10n.exchangeSchimbValutar,
                              subtitle:
                                  context.l10n.exchangeSchimbaIntreDiferiteValute,
                            ),
                            const SizedBox(height: 40),
                            _buildCurrencyInput(
                              label: context.l10n.exchangeValuta,
                              controller: _fromAmountController,
                              currency: _fromCurrency,
                              onCurrencyChanged:
                                  _onFromCurrencyChanged,
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: RotationTransition(
                                turns: _swapAnimation!,
                                child: Container(
                                  // 48dp button inside the 2px ring.
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.brand
                                        .withOpacity(0.1),
                                    border: Border.all(
                                      color: context.colors.brand
                                          .withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: context.l10n.exchangeInverseazaValutele,
                                    icon: Icon(
                                        Icons.swap_vert_rounded,
                                        color: context.colors.brand,
                                        size: 24),
                                    onPressed: _swapCurrencies,
                                  ),
                                ),
                              ),
                            ),
                            _buildCurrencyInput(
                              label: context.l10n.exchangeValuta2,
                              controller: _toAmountController,
                              currency: _toCurrency,
                              onCurrencyChanged:
                                  _onToCurrencyChanged,
                            ),
                            const SizedBox(height: 20),
                            if (!service.hasRates)
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              )
                            else if (!_hasRate)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.colors.danger.withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: context.colors.danger
                                          .withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                        Icons.error_outline_rounded,
                                        color: context.colors.danger,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        context.l10n.exchangeCursulValutarEsteDisponibil,
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: context.colors.danger,
                                            fontWeight:
                                                FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.colors.brand
                                      .withOpacity(0.05),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.colors.brand
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                            Icons.info_outline_rounded,
                                            color: context.colors.brand,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '1 $_fromCurrency = ${formatRate(_originalRate)} $_toCurrency',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: context.colors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const SizedBox(width: 26),
                                        Expanded(
                                          child: Text(
                                            context.l10n.exchangeComision(formatPercent(service.commissionPercent), formatMoney(_commissionAmount, _toCurrency)),
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w400,
                                                color:
                                                    context.colors.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const SizedBox(width: 26),
                                        Expanded(
                                          child: Text(
                                            context.l10n.exchangeRataEfectiva1(_fromCurrency, formatRate(_rateWithCommission), _toCurrency),
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color: context.colors.brandStrong),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: AppButton(
                label: context.l10n.exchangeSchimbaValuta,
                isLoading: _isExecuting,
                onPressed: (!service.hasRates || !_hasRate)
                    ? null
                    : _confirmAndExecuteExchange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}