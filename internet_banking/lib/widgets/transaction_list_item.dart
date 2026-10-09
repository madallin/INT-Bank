import 'package:flutter/material.dart';

import '../data/models/transaction_category.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// Compact transaction row: category (or direction) icon, title, date and signed amount.
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
    this.category,
  });

  /// Icon and colour of what it was for; without it, an arrow for money in or out.
  final TransactionCategory? category;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = isPositive ? c.positive : c.negative;
    final iconColor = categoryIconColor(category, isPositive, c, Theme.of(context).brightness);
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
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon(category, isPositive),
                size: 20,
                color: iconColor,
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

/// The icon for a transaction: its category's, or an arrow for money in or out.
IconData categoryIcon(TransactionCategory? category, bool isIncoming) =>
    category?.icon ?? (isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);

/// Spending categories have their own colour; money in, money out and moves between
/// accounts keep the green/red of their direction.
Color categoryIconColor(TransactionCategory? category, bool isIncoming, AppColors c, Brightness brightness)
{
  if(category != null && category.isSpending && category != TransactionCategory.other)
  {
    return category.color(c, brightness);
  }
  if(category == TransactionCategory.ownAccounts) return c.brand;
  return isIncoming ? c.positive : c.negative;
}
