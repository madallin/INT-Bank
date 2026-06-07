// lib/features/exchange/screens/exchange_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';

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
  final bool _loading = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  AnimationController? _swapController;
  Animation<double>? _swapAnimation;

  final Map<String, String> _currencySymbols = {
    'RON': 'lei',
    'EUR': '€',
    'USD': r'$',
    'GBP': '£',
  };

  final Map<String, double> _exchangeRates = {
    'RON_EUR': 0.20,
    'RON_USD': 0.22,
    'RON_GBP': 0.17,
    'EUR_RON': 4.97,
    'EUR_USD': 1.09,
    'EUR_GBP': 0.85,
    'USD_RON': 4.56,
    'USD_EUR': 0.92,
    'USD_GBP': 0.78,
    'GBP_RON': 5.88,
    'GBP_EUR': 1.18,
    'GBP_USD': 1.28,
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
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _swapController?.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
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
      _swapController!.reverse();
    });
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

  double _getExchangeRate(String from, String to) {
    if (from == to) return 1.0;
    final key = '${from}_$to';
    return _exchangeRates[key] ?? 1.0;
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
                              onCurrencyChanged: (value) {
                                if (value != null) setState(() => _fromCurrency = value);
                              },
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
                              onCurrencyChanged: (value) {
                                if (value != null) setState(() => _toCurrency = value);
                              },
                            ),
                            const SizedBox(height: 42),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(lightForestGreenColor).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(lightForestGreenColor).withOpacity(0.2), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: const Color(lightForestGreenColor), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Curs: 1 $_fromCurrency = ${_getExchangeRate(_fromCurrency, _toCurrency).toStringAsFixed(4)} $_toCurrency',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
                                    ),
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
                    onTap: _loading ? null : () {},
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
