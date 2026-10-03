import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../l10n/l10n.dart';

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

  List<Map<String, String>> get _currencies => [
    {'code': 'EUR', 'name': context.l10n.openCurrencyEuro, 'symbol': '€', 'desc': context.l10n.openCurrencyContCurentEuroPlati},
    {'code': 'USD', 'name': context.l10n.openCurrencyDolarAmerican, 'symbol': r'$', 'desc': context.l10n.openCurrencyContCurentUsdTransferuri},
    {'code': 'GBP', 'name': context.l10n.openCurrencyLiraSterlina, 'symbol': '£', 'desc': context.l10n.openCurrencyContCurentGbpPlati},
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
        showSuccessSnackBar(context, context.l10n.openCurrencyContulTauFostDeschis(_selectedCurrency));
      } else {
        _showError(AppL10n.current.openCurrencyEroareDeschidereaContului);
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.openCurrencyContulPututFiDeschis));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showErrorSnackBar(context, msg);
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
                    color: context.colors.brand.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.currency_exchange_rounded, color: context.colors.brand, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.openCurrencyDeschideContValutar,
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.openCurrencyAlegeMonedaDoritaSe,
              style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
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
                    color: isSelected ? context.colors.brandSurface : context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? context.colors.brand : context.colors.border,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? context.colors.brand : context.colors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            c['symbol']!,
                            style: GoogleFonts.inter(
                              color: isSelected ? context.colors.onBrand : context.colors.textPrimary,
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
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                            ),
                            Text(
                              c['desc']!,
                              style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: context.colors.brand, size: 20),
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
                    child: Text(context.l10n.commonAnuleaza, style: GoogleFonts.inter(color: context.colors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      foregroundColor: context.colors.onBrand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: context.colors.onBrand, strokeWidth: 2))
                        : Text(context.l10n.openCurrencyDeschide, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
