import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../l10n/l10n.dart';

class TransferConfirmationBottomSheet extends StatelessWidget {
  final String beneficiaryName;
  final String toIban;
  final String fromIban;
  final double amount;
  final String currency;
  final String reason;
  final RomanianBankInfo? bankInfo;
  final bool isScheduled;
  final String? scheduleDetails;
  final VoidCallback onConfirm;

  const TransferConfirmationBottomSheet({
    super.key,
    required this.beneficiaryName,
    required this.toIban,
    required this.fromIban,
    required this.amount,
    this.currency = 'RON',
    required this.reason,
    this.bankInfo,
    this.isScheduled = false,
    this.scheduleDetails,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
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
                  color: context.colors.brand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: context.colors.brand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.transferConfirmVerificareTransfer,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      context.l10n.transferConfirmVerificaDetaliilePlatiiInainte,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.colors.surfaceMuted, context.colors.brandSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.brand.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  context.l10n.transferConfirmSumaTransferat,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: context.colors.brand,
                  ),
                ),
                const SizedBox(height: 6),
                // Large amounts shrink to fit instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatAmount(amount),
                      style: GoogleFonts.spaceMono(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currency,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.brand,
                      ),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.l10n.transferConfirmComisionTransferGratuit(formatMoney(0, currency)),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.border,
              ),
            ),
            child: Column(
              children: [
                _buildRow(context,
                  label: context.l10n.commonContul,
                  value: fromIban.isEmpty ? '—' : formatIban(fromIban),
                  isMono: true,
                ),
                const Divider(height: 20),
                _buildRow(context,
                  label: context.l10n.transferConfirmDestinatar,
                  value: beneficiaryName,
                  isBold: true,
                ),
                const Divider(height: 20),
                _buildRow(context,
                  label: context.l10n.transferConfirmBancaBeneficiar,
                  value: bankInfo != null ? bankInfo!.name : context.l10n.transferConfirmBancaComerciala,
                  trailingBadge: bankInfo?.code,
                ),
                const Divider(height: 20),
                _buildRow(context,
                  label: context.l10n.transferConfirmIbanDestinatie,
                  value: formatIban(toIban),
                  isMono: true,
                ),
                const Divider(height: 20),
                _buildRow(context,
                  label: context.l10n.commonDetaliiPlata,
                  value: reason,
                ),
                if (isScheduled && scheduleDetails != null) ...[
                  const Divider(height: 20),
                  _buildRow(context,
                    label: context.l10n.commonProgramare,
                    value: scheduleDetails!,
                    highlight: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // What happens after confirming
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: context.colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isScheduled
                      ? context.l10n.transferConfirmPlataVaFiExecutata
                      : context.l10n.transferConfirmVerificaIbanUlSuma,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Buttons
          AppButton(
            label: isScheduled ? context.l10n.transferConfirmConfirmaProgramarea : context.l10n.transferConfirmConfirmaTransferul,
            icon: isScheduled ? Icons.event_available_rounded : Icons.send_rounded,
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              HapticFeedbackHelper.selection();
              Navigator.pop(context);
            },
            child: Text(
              context.l10n.transferConfirmModificaDetaliile,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
    bool isMono = false,
    bool highlight = false,
    String? trailingBadge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.colors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingBadge != null) ...[
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trailingBadge,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.brand,
                    ),
                  ),
                ),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: isMono
                      ? GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        )
                      : GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                          color: highlight
                              ? context.colors.brand
                              : (context.colors.textPrimary),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
