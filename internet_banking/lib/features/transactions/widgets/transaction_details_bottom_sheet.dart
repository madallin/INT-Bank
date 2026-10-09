import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_category.dart';
import '../../../l10n/l10n.dart';

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
    final description = transaction['reason'] ?? transaction['description'] ?? context.l10n.commonTransferBancar;
    final rawDate = transaction['date']?.toString();
    final date = rawDate == null ? '-' : formatIsoDate(rawDate, withTime: true);
    final signedAmount = formatMoney(isDebit ? -amount.abs() : amount.abs(), currency.toString(), showSign: true);
    final trackingId = transaction['trackingId'] ?? transaction['id'] ?? 'TX-INTBANK';
    final fromIban = transaction['fromIban'] ?? '-';
    final toIban = transaction['toIban'] ?? transaction['partyIban'] ?? '-';
    final status = transaction['status'] ?? 'COMPLETED';
    final completed = status == 'COMPLETED';
    final category = TransactionCategory.fromKey(transaction['category']);

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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.txDetailsDovadaPlata,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completed ? context.colors.brandSurface : context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completed ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 14,
                      color: completed ? context.colors.positive : context.colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      completed ? context.l10n.txDetailsFinalizata : context.l10n.commonProcesare,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: completed ? context.colors.positive : context.colors.textSecondary,
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
                  signedAmount,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDebit ? context.colors.danger : context.colors.brand,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          _buildDetailRow(context, context.l10n.txDetailsDataOra, date),
          _buildDetailRow(context, context.l10n.txDetailsReferintaTranzactie, trackingId.toString(), copyable: true),
          _buildDetailRow(context, context.l10n.txDetailsTipOperatiune, isDebit ? context.l10n.txDetailsPlataTransferTrimis : context.l10n.txDetailsIncasareTransferPrimit),
          if (category != null) _buildDetailRow(context, context.l10n.txDetailsCategory, category.label(context.l10n)),
          if (fromIban != '-') _buildDetailRow(context, context.l10n.txDetailsContExpeditorIban, fromIban, copyable: true),
          if (toIban != '-') _buildDetailRow(context, context.l10n.txDetailsContBeneficiarIban, toIban, copyable: true),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: context.l10n.txDetailsTranzactieIntbankSumaData(trackingId, signedAmount, date)));
                    showSuccessSnackBar(context, context.l10n.txDetailsDetaliileTranzactieiAuFost);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(context.l10n.txDetailsCopiaza, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.brand,
                    side: BorderSide(color: context.colors.brand),
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
                  label: Text(context.l10n.commonInchide, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    foregroundColor: context.colors.onBrand,
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

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool copyable = false}) {
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
                color: context.colors.textMuted,
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
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (copyable) ...[
                  IconButton(
                    tooltip: context.l10n.commonCopiaza(label),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      showSuccessSnackBar(context, context.l10n.txDetailsFostCopiatClipboard(label));
                    },
                    icon: Icon(Icons.copy_rounded, size: 16, color: context.colors.brand),
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
