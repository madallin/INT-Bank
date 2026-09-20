import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';

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
      decoration: const BoxDecoration(
        color: Colors.white,
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
                color: Colors.grey[300],
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
                  color: const Color(lightForestGreenColor).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_rounded, size: 22, color: Color(lightForestGreenColor)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalii cont curent',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(darkGreyColor),
                    ),
                  ),
                  Text(
                    'Cont principal · $currency',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2ECE6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONT IBAN',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
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
                          color: const Color(darkGreyColor),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(lightForestGreenColor), size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: iban));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('IBAN-ul a fost copiat în clipboard', style: GoogleFonts.inter()),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(lightForestGreenColor),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInfoRow('Titular cont', holderName),
          _buildInfoRow('Cod BIC / SWIFT', 'INTBROBUXXX', copyable: true, context: context),
          _buildInfoRow('Banca', 'INTBank S.A. România'),
          _buildInfoRow('Monedă cont', currency),
          _buildInfoRow('Sold disponibil', '${balance.toStringAsFixed(2)} $currency'),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {
              final shareText = 'Date cont INTBank:\nTitular: $holderName\nIBAN: $iban\nBIC/SWIFT: INTBROBUXXX\nBanca: INTBank România';
              Clipboard.setData(ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Toate datele contului au fost copiate pentru partajare', style: GoogleFonts.inter()),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(lightForestGreenColor),
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text('Copiază datele pentru transfer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(lightForestGreenColor),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false, BuildContext? context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
          Row(
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
              if (copyable && context != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copiat', style: GoogleFonts.inter()),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(lightForestGreenColor),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 14, color: Color(lightForestGreenColor)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
