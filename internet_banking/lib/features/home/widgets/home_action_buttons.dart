import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../l10n/l10n.dart';

/// Quick actions on Home: transfer, history, exchange, analytics.
class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({
    super.key,
    required this.onTransfer,
    required this.onHistory,
    required this.onExchange,
    required this.onAnalytics,
  });

  final VoidCallback onTransfer;
  final VoidCallback onHistory;
  final VoidCallback onExchange;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
              child: _actionCard(context, 
                  Icons.send_rounded, context.l10n.commonTransfer, onTransfer)),
          const SizedBox(width: 8),
          Expanded(
              child: _actionCard(context, Icons.receipt_long_rounded,
                  context.l10n.homeIstoric, onHistory)),
          const SizedBox(width: 8),
          Expanded(
              child: _actionCard(context, Icons.currency_exchange_rounded,
                  context.l10n.homeSchimb, onExchange)),
          const SizedBox(width: 8),
          Expanded(
              child: _actionCard(context, Icons.pie_chart_outline_rounded,
                  context.l10n.homeStatistici, onAnalytics)),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, 
      IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedbackHelper.buttonTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.brand
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: context.colors.brand,
                  size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
          ],
        ),
      ),
    ),
    );
  }

}
