import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';

class TransactionDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsBottomSheet({
    super.key,
    required this.transaction,
  });

  static void show(BuildContext context, Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailsBottomSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction['type'] == 'DEBIT';
    final amount = (transaction['amount'] is num)
        ? (transaction['amount'] as num).toDouble()
        : double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final currency = transaction['currency'] ?? 'RON';
    final description = transaction['reason'] ?? transaction['description'] ?? 'Transfer bancar';
    final date = transaction['date'] ?? '-';
    final trackingId = transaction['trackingId'] ?? transaction['id'] ?? 'TX-INTBANK';
    final fromIban = transaction['fromIban'] ?? '-';
    final toIban = transaction['toIban'] ?? transaction['partyIban'] ?? '-';
    final status = transaction['status'] ?? 'COMPLETED';

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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dovadă de plată',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(darkGreyColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      status == 'COMPLETED' ? 'Finalizată' : 'În procesare',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                Text(
                  '${isDebit ? "-" : "+"}${amount.toStringAsFixed(2)} $currency',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDebit ? const Color(0xFFC62828) : const Color(lightForestGreenColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          _buildDetailRow('Data & Ora', date),
          _buildDetailRow('Referință tranzacție', trackingId.toString(), copyable: true, context: context),
          _buildDetailRow('Tip operațiune', isDebit ? 'Plată / Transfer trimis' : 'Încasare / Transfer primit'),
          if (fromIban != '-') _buildDetailRow('Cont expeditor (IBAN)', fromIban, copyable: true, context: context),
          if (toIban != '-') _buildDetailRow('Cont beneficiar (IBAN)', toIban, copyable: true, context: context),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'Tranzacție INTBank: $trackingId | Suma: ${isDebit ? "-" : "+"}${amount.toStringAsFixed(2)} $currency | Data: $date'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Detaliile tranzacției au fost copiate', style: GoogleFonts.inter()),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(lightForestGreenColor),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text('Copiază', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(lightForestGreenColor),
                    side: const BorderSide(color: Color(lightForestGreenColor)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Închide', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(lightForestGreenColor),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false, BuildContext? context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(darkGreyColor),
                    ),
                  ),
                ),
                if (copyable && context != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label a fost copiat în clipboard', style: GoogleFonts.inter()),
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
          ),
        ],
      ),
    );
  }
}
