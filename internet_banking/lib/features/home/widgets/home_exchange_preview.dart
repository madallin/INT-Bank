import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/currency_service.dart';
import '../../../l10n/l10n.dart';

/// Today's exchange rates against RON.
class HomeExchangePreview extends StatelessWidget {
  const HomeExchangePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final rates = CurrencyService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.colors.brand.withValues(alpha: 0.08),
              context.colors.brandStrong.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  context.colors.brand.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 18, color: context.colors.brand),
                const SizedBox(width: 8),
                Text(context.l10n.homeCursValutar,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            if (!rates.hasRates)
              Center(
                child: Text(context.l10n.homeSeIncarca,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: context.colors.textMuted)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _rateTile(context, 'EUR', rates.getRate('EUR', 'RON'))),
                  Expanded(child: _rateTile(context, 'USD', rates.getRate('USD', 'RON'))),
                  Expanded(child: _rateTile(context, 'GBP', rates.getRate('GBP', 'RON'))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _rateTile(BuildContext context, String currency, double? rate) {
    return Column(
      children: [
        Text(currency,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          rate != null ? formatRate(rate) : '---',
          style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.colors.brand),
        ),
      ],
    );
  }

}
