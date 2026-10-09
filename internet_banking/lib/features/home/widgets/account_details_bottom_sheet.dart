import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/l10n.dart';

class AccountDetailsBottomSheet extends StatelessWidget {
  final String iban;
  final String currency;
  final double balance;
  final String holderName;

  const AccountDetailsBottomSheet({
    super.key,
    required this.iban,
    required this.currency,
    required this.balance,
    required this.holderName,
  });

  static void show(BuildContext context, {
    required String iban,
    required String currency,
    required double balance,
    required String holderName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountDetailsBottomSheet(
        iban: iban,
        currency: currency,
        balance: balance,
        holderName: holderName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_rounded, size: 22, color: context.colors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.accountDetailsDetaliiContCurent,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    context.l10n.accountDetailsContPrincipal(currency),
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.surfaceMuted),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accountDetailsContIban,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        iban,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.accountDetailsCopiazaIbanUl,
                      icon: Icon(Icons.copy_rounded, color: context.colors.brand, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: iban));
                        showSuccessSnackBar(context, context.l10n.accountDetailsIbanUlFostCopiat);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInfoRow(context, context.l10n.accountDetailsTitularCont, holderName),
          _buildInfoRow(context, context.l10n.accountDetailsCodBicSwift, 'INTBROBUXXX', copyable: true),
          _buildInfoRow(context, context.l10n.commonBanca, context.l10n.accountDetailsIntbankSRomania),
          _buildInfoRow(context, context.l10n.accountDetailsMonedaCont, currency),
          _buildInfoRow(context, context.l10n.commonSoldDisponibil, formatMoney(balance, currency)),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {
              final shareText = context.l10n.accountDetailsDateContIntbankTitular(holderName, iban);
              Clipboard.setData(ClipboardData(text: shareText));
              showSuccessSnackBar(context, context.l10n.accountDetailsToateDateleContuluiAu);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(context.l10n.accountDetailsCopiazaDateleTransfer, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: context.colors.onBrand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted))),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              if (copyable) ...[
                IconButton(
                  tooltip: context.l10n.commonCopiaza(label),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    showSuccessSnackBar(context, context.l10n.accountDetailsCopiat(label));
                  },
                  icon: Icon(Icons.copy_rounded, size: 16, color: context.colors.brand),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
