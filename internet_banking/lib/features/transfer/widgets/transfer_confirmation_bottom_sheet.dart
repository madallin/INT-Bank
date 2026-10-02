import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/iban_bank_detector.dart';

class TransferConfirmationBottomSheet extends StatelessWidget {
  final String beneficiaryName;
  final String toIban;
  final String fromIban;
  final double amount;
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
    required this.reason,
    this.bankInfo,
    this.isScheduled = false,
    this.scheduleDetails,
    required this.onConfirm,
  });

  String _formatAmount(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(integerPart[i]);
    }
    return '${buffer.toString()},$decimalPart';
  }

  String _formatIban(String iban) {
    final clean = iban.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
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
                color: isDark ? Colors.grey[700] : Colors.grey[300],
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
                  color: const Color(lightForestGreenColor).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(lightForestGreenColor),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verificare transfer',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(darkGreyColor),
                      ),
                    ),
                    Text(
                      'Verifică detaliile plății înainte de trimitere',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
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
                colors: isDark
                    ? [const Color(0xFF1E2633), const Color(0xFF151C28)]
                    : [const Color(0xFFF0FDF4), const Color(0xFFE8F5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(lightForestGreenColor).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'SUMĂ DE TRANSFERAT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(lightForestGreenColor),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatAmount(amount),
                      style: GoogleFonts.spaceMono(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(darkGreyColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RON',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(lightForestGreenColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(lightForestGreenColor).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Comision: 0.00 RON • Transfer gratuit',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(lightForestGreenColor),
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
              color: isDark ? const Color(0xFF0F141C) : Colors.grey[50],
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                _buildRow(
                  label: 'Destinatar',
                  value: beneficiaryName,
                  isDark: isDark,
                  isBold: true,
                ),
                const Divider(height: 20),
                _buildRow(
                  label: 'Bancă beneficiar',
                  value: bankInfo != null ? bankInfo!.name : 'Bancă Comercială',
                  isDark: isDark,
                  trailingBadge: bankInfo?.code,
                ),
                const Divider(height: 20),
                _buildRow(
                  label: 'IBAN Destinație',
                  value: _formatIban(toIban),
                  isDark: isDark,
                  isMono: true,
                ),
                const Divider(height: 20),
                _buildRow(
                  label: 'Detalii plată',
                  value: reason,
                  isDark: isDark,
                ),
                if (isScheduled && scheduleDetails != null) ...[
                  const Divider(height: 20),
                  _buildRow(
                    label: 'Programare',
                    value: scheduleDetails!,
                    isDark: isDark,
                    highlight: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security Footnote
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Securizat prin Double-Entry Ledger & Strong Customer Authentication',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Buttons
          ElevatedButton(
            onPressed: () {
              HapticFeedbackHelper.buttonTap();
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(lightForestGreenColor),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Confirmă și autorizează',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              HapticFeedbackHelper.selection();
              Navigator.pop(context);
            },
            child: Text(
              'Modifică detaliile',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    required bool isDark,
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
            color: Colors.grey[500],
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
                    color: const Color(lightForestGreenColor).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trailingBadge,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(lightForestGreenColor),
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
                          color: isDark ? Colors.white70 : const Color(darkGreyColor),
                        )
                      : GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                          color: highlight
                              ? const Color(lightForestGreenColor)
                              : (isDark ? Colors.white : const Color(darkGreyColor)),
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
