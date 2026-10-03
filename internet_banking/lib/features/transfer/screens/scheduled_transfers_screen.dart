import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../l10n/l10n.dart';

class ScheduledTransfersScreen extends StatefulWidget {
  final int userId;

  const ScheduledTransfersScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ScheduledTransfersScreen> createState() => _ScheduledTransfersScreenState();
}

class _ScheduledTransfersScreenState extends State<ScheduledTransfersScreen> {
  final DioClient _dioClient = DioClient();
  List<Map<String, dynamic>> _transfers = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScheduledTransfers();
  }

  Future<void> _fetchScheduledTransfers() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dioClient.get('/users/${widget.userId}/scheduled-transfers');
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _transfers = List<Map<String, dynamic>>.from(response.data as List);
          _loading = false;
        });
      } else {
        setState(() {
          _errorMessage = context.l10n.scheduledSAuPututIncarca;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyErrorMessage(e, fallback: context.l10n.scheduledSAuPututIncarca);
        _loading = false;
      });
    }
  }

  Future<void> _deleteTransfer(int id) async {
    try {
      final response = await _dioClient.delete('/users/${widget.userId}/scheduled-transfers/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        showSuccessSnackBar(context, context.l10n.scheduledPlataProgramataFostAnulata);
        _fetchScheduledTransfers();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, friendlyErrorMessage(e, fallback: context.l10n.scheduledPlataProgramataPututFi));
    }
  }

  Future<void> _confirmCancel(int id, String beneficiary, double amount) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.scheduledAnuleziPlataRecurenta,
      message:
          context.l10n.scheduledPlataCatreVaMai(formatMoney(amount, 'RON'), beneficiary),
      confirmLabel: context.l10n.scheduledAnuleazaPlata,
      cancelLabel: context.l10n.scheduledPastreaza,
      destructive: true,
    );
    if (confirmed) _deleteTransfer(id);
  }

  String _formatFrequency(String freq) {
    switch (freq.toUpperCase()) {
      case 'WEEKLY':
        return context.l10n.commonSaptamanal;
      case 'MONTHLY':
        return context.l10n.commonLunar;
      default:
        return context.l10n.scheduledSinguraData;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceMuted,
      appBar: SimpleAppBar(
        title: context.l10n.scheduledPlatiProgramate,
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.brand))
          : _errorMessage != null
          ? ErrorRetryView(
              message: _errorMessage!,
              onRetry: _fetchScheduledTransfers,
              icon: Icons.event_busy_rounded,
            )
          : _transfers.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.brand.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_month_outlined, size: 48, color: context.colors.brand),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.scheduledNicioPlataProgramata,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.scheduledPotiSetaPlatiRecurente,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchScheduledTransfers,
        color: context.colors.brand,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _transfers.length,
          itemBuilder: (context, index) {
            final t = _transfers[index];
            final id = t['id'] as int? ?? 0;
            final beneficiary = t['beneficiaryName'] ?? context.l10n.scheduledBeneficiar;
            final iban = t['toIban'] ?? '';
            final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
            final freq = t['frequency'] ?? 'ONCE';
            final nextRun = t['nextRunDate'] ?? '-';
            final reason = t['reason'] ?? '';
            final bank = IbanBankDetector.detectBank(iban);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.brand.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.repeat_rounded, color: context.colors.brand, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                beneficiary,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                              ),
                              if (bank != null)
                                Text(
                                  bank.name,
                                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted, fontWeight: FontWeight.w500),
                                ),
                            ],
                          )),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Text(
                        formatMoney(amount, 'RON'),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    iban,
                    style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary, letterSpacing: 0.5),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.commonDetalii(reason),
                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.colors.brandSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatFrequency(freq),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.positive),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.scheduledUrmatoarea(nextRun),
                            style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: context.colors.danger, size: 20),
                        tooltip: context.l10n.commonAnuleaza,
                        onPressed: () => _confirmCancel(id, beneficiary, amount),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
