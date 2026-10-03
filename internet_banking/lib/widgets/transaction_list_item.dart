import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// Compact transaction row: direction icon, title, date and signed amount.
class TransactionListItem extends StatelessWidget {
  final String beneficiary;
  final String date;
  final String amount;
  final bool isPositive;

  const TransactionListItem({
    super.key,
    required this.beneficiary,
    required this.date,
    required this.amount,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = isPositive ? c.positive : c.negative;
    return Semantics(
      label: isPositive
          ? context.l10n.commonTxIncomingSemantics(beneficiary, date, amount)
          : context.l10n.commonTxOutgoingSemantics(beneficiary, date, amount),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 20,
                color: tone,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beneficiary,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: context.text.bodySmall?.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              amount,
              style: context.text.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
