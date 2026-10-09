import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/helpers.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/success_badge.dart';
import '../../../l10n/l10n.dart';

/// What the user chose on the receipt; the transfer screen acts on it.
enum TransferReceiptAction { done, newTransfer }

/// Everything shown on the receipt after a transfer is accepted.
class TransferReceipt
{
  const TransferReceipt({
    required this.amount,
    required this.currency,
    required this.beneficiaryName,
    required this.toIban,
    required this.fromIban,
    required this.reason,
    required this.createdAt,
    this.bankName,
    this.trackingId,
    this.status,
    this.scheduleSummary,
  });

  final double amount;
  final String currency;
  final String beneficiaryName;
  final String toIban;
  final String fromIban;
  final String reason;
  final DateTime createdAt;
  final String? bankName;

  /// Server tracking id and status (`PENDING`/`COMPLETED`) for instant transfers.
  final String? trackingId;
  final String? status;

  /// Set for scheduled/recurring payments, e.g. "Lunar, din 01.11.2026".
  final String? scheduleSummary;

  bool get isScheduled => scheduleSummary != null;
  bool get isCompleted => status?.toUpperCase() == 'COMPLETED';

  String get title
  {
    if(isScheduled) return AppL10n.current.receiptPlataProgramata;
    return isCompleted ? AppL10n.current.receiptTransferEfectuat : AppL10n.current.receiptTransferProcesare;
  }

  String get statusLabel
  {
    if(isScheduled) return AppL10n.current.receiptProgramata;
    return isCompleted ? AppL10n.current.receiptFinalizat : AppL10n.current.commonProcesare;
  }

  String toShareText()
  {
    final lines = <String>[
      AppL10n.current.receiptIntBank(title),
      AppL10n.current.receiptSuma(formatMoney(amount, currency)),
      AppL10n.current.receiptBeneficiar(beneficiaryName),
      AppL10n.current.receiptIbanBeneficiar(formatIban(toIban)),
      AppL10n.current.commonDetalii(reason),
      AppL10n.current.receiptData(formatDateTime(createdAt)),
      if(scheduleSummary != null) AppL10n.current.receiptProgramare(scheduleSummary!),
      if(trackingId != null) AppL10n.current.receiptIdTranzactie(trackingId!),
    ];
    return lines.join('\n');
  }
}

class TransferReceiptScreen extends StatelessWidget
{
  const TransferReceiptScreen({super.key, required this.receipt});

  final TransferReceipt receipt;

  void _close(BuildContext context, TransferReceiptAction action) =>
      Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final r = receipt;
    final icon = r.isScheduled
        ? Icons.event_available_rounded
        : (r.isCompleted ? Icons.check_rounded : Icons.schedule_send_rounded);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if(!didPop) _close(context, TransferReceiptAction.done);
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.md),
                  child: Column(
                    children: [
                      if(r.isScheduled || r.isCompleted)
                        SuccessBadge(icon: r.isScheduled ? icon : null)
                      else
                        ExcludeSemantics(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(color: c.brandSurface, shape: BoxShape.circle),
                            child: Icon(icon, size: 44, color: c.brand),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        header: true,
                        child: Text(r.title, textAlign: TextAlign.center, style: context.text.titleLarge),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatMoney(r.amount, r.currency),
                          style: context.text.displaySmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        context.l10n.receiptCatre(r.beneficiaryName),
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                      ),
                      if(!r.isScheduled && !r.isCompleted) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          context.l10n.receiptBancaProceseazaTransferulVei,
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _DetailsCard(receipt: r),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: r.toShareText()));
                          showSuccessSnackBar(context, context.l10n.receiptDetaliileAuFostCopiate);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(context.l10n.receiptCopiazaDetaliile),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.md),
                child: Column(
                  children: [
                    AppButton(
                      label: context.l10n.receiptGata,
                      onPressed: () => _close(context, TransferReceiptAction.done),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      label: context.l10n.commonTransferNou,
                      variant: AppButtonVariant.outline,
                      onPressed: () => _close(context, TransferReceiptAction.newTransfer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget
{
  const _DetailsCard({required this.receipt});

  final TransferReceipt receipt;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final r = receipt;
    final rows = <(String, String)>[
      (context.l10n.receiptStatus, r.statusLabel),
      (context.l10n.receiptData2, formatDateTime(r.createdAt)),
      if(r.scheduleSummary != null) (context.l10n.commonProgramare, r.scheduleSummary!),
      (context.l10n.commonContul, formatIban(r.fromIban)),
      (context.l10n.receiptCatre2, formatIban(r.toIban)),
      if(r.bankName != null) (context.l10n.commonBanca, r.bankName!),
      (context.l10n.commonDetaliiPlata, r.reason),
      if(r.trackingId != null) (context.l10n.receiptIdTranzactie2, r.trackingId!),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for(var i = 0; i < rows.length; i++) ...[
            if(i > 0) Divider(height: 1, color: c.border),
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(rows[i].$1, style: context.text.bodySmall),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        textAlign: TextAlign.end,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
