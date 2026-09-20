import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';

class OpenCurrencyAccountDialog extends StatefulWidget {
  final int userId;
  final VoidCallback onAccountCreated;

  const OpenCurrencyAccountDialog({
    super.key,
    required this.userId,
    required this.onAccountCreated,
  });

  static void show(BuildContext context, {
    required int userId,
    required VoidCallback onAccountCreated,
  }) {
    showDialog(
      context: context,
      builder: (_) => OpenCurrencyAccountDialog(
        userId: userId,
        onAccountCreated: onAccountCreated,
      ),
    );
  }

  @override
  State<OpenCurrencyAccountDialog> createState() => _OpenCurrencyAccountDialogState();
}

class _OpenCurrencyAccountDialogState extends State<OpenCurrencyAccountDialog> {
  final DioClient _client = DioClient();
  String _selectedCurrency = 'EUR';
  bool _loading = false;

  final List<Map<String, String>> _currencies = [
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'desc': 'Cont curent în Euro pentru plăți SEPA'},
    {'code': 'USD', 'name': 'Dolar American', 'symbol': r'$', 'desc': 'Cont curent în USD pentru transferuri internaționale'},
    {'code': 'GBP', 'name': 'Liră sterlină', 'symbol': '£', 'desc': 'Cont curent în GBP pentru plăți în Regatul Unit'},
  ];

  Future<void> _createAccount() async {
    setState(() => _loading = true);
    try {
      final response = await _client.post(
        '/users/${widget.userId}/accounts',
        data: {'currency': _selectedCurrency},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onAccountCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contul tău în $_selectedCurrency a fost deschis cu succes!', style: GoogleFonts.inter()),
            backgroundColor: const Color(lightForestGreenColor),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError('Eroare la deschiderea contului');
      }
    } catch (e) {
      _showError('Eroare: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter()), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(lightForestGreenColor).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.currency_exchange_rounded, color: Color(lightForestGreenColor), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Deschide cont valutar',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Alege moneda dorită. Se va genera instant un IBAN unic fără comisioane de administrare.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            ..._currencies.map((c) {
              final isSelected = _selectedCurrency == c['code'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCurrency = c['code']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0F7F4) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(lightForestGreenColor) : Colors.grey[300]!,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(lightForestGreenColor) : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            c['symbol']!,
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : const Color(darkGreyColor),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['name']} (${c['code']})',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                            ),
                            Text(
                              c['desc']!,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(lightForestGreenColor), size: 20),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Anulează', style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(lightForestGreenColor),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Deschide', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
