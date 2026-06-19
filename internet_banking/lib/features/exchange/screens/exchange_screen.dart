// lib/features/exchange/screens/exchange_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../services/currency_service.dart';

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

  String _fromCurrency = 'RON';
  String _toCurrency = 'EUR';

  // Live rate data (computed from CurrencyService)
  double _originalRate = 0.0;
  double _rateWithCommission = 0.0;
  double _commissionAmount = 0.0;
  bool _hasRate = false;

  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  AnimationController? _swapController;
  Animation<double>? _swapAnimation;

  // Debounce timer for amount changes
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
    _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut);
    _fadeController!.forward();

    _swapController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _swapAnimation = CurvedAnimation(parent: _swapController!, curve: Curves.easeInOut);

    // If rates haven't been fetched yet, fetch them
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

    final amount = double.tryParse(_fromAmountController.text.replaceAll(',', '')) ?? 0;

    setState(() {
      _originalRate = rate;
      _rateWithCommission = rate * (1 - service.commissionPercent / 100);
      _commissionAmount = amount * rate * (service.commissionPercent / 100);
      _hasRate = true;

      final result = amount * _rateWithCommission;
      _toAmountController.text = _formatAmount(result.toStringAsFixed(2));
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

  String _formatAmount(String input) {
    String clean = input.replaceAll(RegExp(r'[^\d.]'), '');
    if (clean.isEmpty) return '';

    final parts = clean.split('.');
    String intPart = parts[0];

    String reversed = intPart.split('').reversed.join('');
    String formatted = '';
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) formatted += ',';
      formatted += reversed[i];
    }
    intPart = formatted.split('').reversed.join('');

    if (parts.length > 1) {
      return '$intPart.${parts[1]}';
    }
    return intPart;
  }

  Widget _buildCurrencyInput({
    required String label,
    required TextEditingController controller,
    required String currency,
    required Function(String?) onCurrencyChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280), letterSpacing: 0.3)),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 110,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currency,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                    items: _currencySymbols.keys.map((curr) {
                      return DropdownMenuItem<String>(value: curr, child: Text(curr));
                    }).toList(),
                    onChanged: onCurrencyChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.contains('.')) {
                          final parts = newValue.text.split('.');
                          if (parts.length > 2) return oldValue;
                          if (parts.length == 2 && parts[1].length > 2) return oldValue;
                        }
                        final formatted = _formatAmount(newValue.text);
                        return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                      }),
                    ],
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(lightForestGreenColor), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      hintText: '0.00',
                      hintStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = CurrencyService.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22), onPressed: () => Navigator.pop(context), color: const Color(darkGreyColor)),
                  Text('Schimb valutar', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _fadeAnimation != null
                    ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
                                ),
                                boxShadow: [BoxShadow(color: const Color(lightForestGreenColor).withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
                              ),
                              child: const Center(child: Icon(Icons.currency_exchange_rounded, size: 44, color: Colors.white)),
                            ),
                            const SizedBox(height: 40),
                            Text('Schimb valutar', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor), letterSpacing: -0.5)),
                            const SizedBox(height: 12),
                            Text('Schimbă între diferite valute la cursul zilei', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w400, height: 1.5)),
                            const SizedBox(height: 40),
                            _buildCurrencyInput(
                              label: 'Din valuta',
                              controller: _fromAmountController,
                              currency: _fromCurrency,
                              onCurrencyChanged: _onFromCurrencyChanged,
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: RotationTransition(
                                turns: _swapAnimation!,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(lightForestGreenColor).withOpacity(0.1),
                                    border: Border.all(color: const Color(lightForestGreenColor).withOpacity(0.3), width: 2),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.swap_vert_rounded, color: const Color(lightForestGreenColor), size: 24),
                                    onPressed: _swapCurrencies,
                                  ),
                                ),
                              ),
                            ),
                            _buildCurrencyInput(
                              label: 'În valuta',
                              controller: _toAmountController,
                              currency: _toCurrency,
                              onCurrencyChanged: _onToCurrencyChanged,
                            ),
                            const SizedBox(height: 20),

                            // ── Rate info card with commission ──
                            if (!service.hasRates)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            else if (!_hasRate)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cursul valutar nu este disponibil',
                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(lightForestGreenColor).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(lightForestGreenColor).withOpacity(0.2), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Current rate
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: const Color(lightForestGreenColor), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '1 $_fromCurrency = ${_originalRate.toStringAsFixed(4)} $_toCurrency',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Commission info
                                    Row(
                                      children: [
                                        const SizedBox(width: 26),
                                        Expanded(
                                          child: Text(
                                            'Comision ${service.commissionPercent}%: ${_commissionAmount.toStringAsFixed(2)} ${_currencySymbols[_fromCurrency] ?? _fromCurrency}',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Effective rate
                                    Row(
                                      children: [
                                        const SizedBox(width: 26),
                                        Expanded(
                                          child: Text(
                                            'Rată efectivă: 1 $_fromCurrency = ${_rateWithCommission.toStringAsFixed(4)} $_toCurrency',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(darkForestGreenColor)),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(lightForestGreenColor), Color(lightForestGreenColor).withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Color(lightForestGreenColor).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (!service.hasRates || !_hasRate) ? null : () {},
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Text('Schimbă valuta', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
