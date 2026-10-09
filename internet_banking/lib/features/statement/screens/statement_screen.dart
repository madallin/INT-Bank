import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../transactions/widgets/transaction_details_bottom_sheet.dart';
import '../../../l10n/l10n.dart';

class StatementScreen extends StatefulWidget {
  final int userId;
  final int accountId;
  final String iban;
  final String currency;

  const StatementScreen({
    super.key,
    required this.userId,
    required this.accountId,
    required this.iban,
    this.currency = 'RON',
  });

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final DioClient _client = DioClient();

  int _selectedPresetIndex = 0; // 0: 30zile, 1: 3luni, 2: 6luni, 3: 1an, 4: Custom
  late DateTime _startDate;
  late DateTime _endDate;

  bool _loading = true;
  bool _downloadingPdf = false;
  Map<String, dynamic>? _statementData;
  String? _errorMessage;

  List<String> get _presets => [context.l10n.statement30Zile, context.l10n.statement3Luni, context.l10n.statement6Luni, context.l10n.statement1An, context.l10n.statementPersonalizat];

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _fetchStatement();
  }

  void _onPresetSelected(int index) {
    if (index == _selectedPresetIndex && index != 4) return;

    final now = DateTime.now();
    setState(() {
      _selectedPresetIndex = index;
      _endDate = now;
      switch (index) {
        case 0:
          _startDate = now.subtract(const Duration(days: 30));
          break;
        case 1:
          _startDate = now.subtract(const Duration(days: 90));
          break;
        case 2:
          _startDate = now.subtract(const Duration(days: 180));
          break;
        case 3:
          _startDate = now.subtract(const Duration(days: 365));
          break;
        case 4:
          _pickCustomDateRange();
          return;
      }
    });
    _fetchStatement();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: oneYearAgo,
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchStatement();
    }
  }

  Future<void> _fetchStatement() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final fromStr = formatApiDate(_startDate);
    final toStr = formatApiDate(_endDate);

    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/${widget.accountId}/statement?from=$fromStr&to=$toStr',
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _statementData = Map<String, dynamic>.from(response.data as Map);
        });
      } else {
        setState(() => _errorMessage = context.l10n.statementSPututIncarcaExtrasul);
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyErrorMessage(e, fallback: context.l10n.statementSPututIncarcaExtrasul));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    final fromStr = formatApiDate(_startDate);
    final toStr = formatApiDate(_endDate);

    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/${widget.accountId}/statement/pdf?from=$fromStr&to=$toStr',
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        showSuccessSnackBar(context,
            context.l10n.statementExtrasulPdfFostGenerat(formatDate(_startDate), formatDate(_endDate)));
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, friendlyErrorMessage(e, fallback: context.l10n.statementPdfUlPututFi));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: SimpleAppBar(title: context.l10n.statementExtrasCont),
      body: Column(
        children: [
          // Period Selector Chips
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_presets.length, (index) {
                      final isSelected = _selectedPresetIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_presets[index]),
                          selected: isSelected,
                          onSelected: (_) => _onPresetSelected(index),
                          selectedColor: context.colors.brand,
                          backgroundColor: context.colors.surfaceMuted,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? context.colors.onBrand : context.colors.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide.none,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      context.l10n.statementPerioada(formatDate(_startDate), formatDate(_endDate)),
                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      formatIban(widget.iban),
                      style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: context.colors.brand))
                : _errorMessage != null
                ? ErrorRetryView(
                    message: _errorMessage!,
                    onRetry: _fetchStatement,
                    icon: Icons.description_outlined,
                  )
                : _buildStatementContent(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: (_loading || _downloadingPdf) ? null : _downloadPdf,
            icon: _downloadingPdf
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: context.colors.onBrand, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: Text(
              _downloadingPdf ? context.l10n.statementSeGenereazaPdf : context.l10n.statementDescarcaExtrasPdf,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: context.colors.onBrand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatementContent() {
    if (_statementData == null) return const SizedBox();

    final openingBalance = (_statementData!['openingBalance'] as num?)?.toDouble() ?? 0.0;
    final totalInflows = (_statementData!['totalInflows'] as num?)?.toDouble() ?? 0.0;
    final totalOutflows = (_statementData!['totalOutflows'] as num?)?.toDouble() ?? 0.0;
    final closingBalance = (_statementData!['closingBalance'] as num?)?.toDouble() ?? 0.0;
    final currency = _statementData!['currency'] ?? widget.currency;
    final transactions = (_statementData!['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryBox(context.l10n.statementSoldInitial, openingBalance, currency, context.colors.textPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox(context.l10n.statementSoldFinal, closingBalance, currency, context.colors.brand)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryBox(context.l10n.statementIncasari, totalInflows, currency, context.colors.positive, isPositive: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox(context.l10n.statementPlati, totalOutflows, currency, context.colors.danger, isNegative: true)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              context.l10n.statementOperatiuni(transactions.length),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted, letterSpacing: 0.5),
            ),
            Text(
              context.l10n.statementAtingeTranzactieDetalii,
              style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: context.colors.border),
                  const SizedBox(height: 10),
                  Text(context.l10n.statementNicioOperatiuneAceastaPerioada, style: GoogleFonts.inter(color: context.colors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ...transactions.map((tx) {
            final isDebit = tx['type'] == 'DEBIT';
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final partyName = tx['partyName'] ?? context.l10n.commonTransfer;
            final desc = tx['description'] ?? '';
            final date = tx['date'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                onTap: () => TransactionDetailsBottomSheet.show(context, tx),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDebit ? context.colors.dangerSurface : context.colors.brandSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isDebit ? context.colors.danger : context.colors.positive,
                    size: 20,
                  ),
                ),
                title: Text(
                  partyName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                ),
                subtitle: Text(
                  date.isNotEmpty && desc.isNotEmpty ? '$date • $desc' : (date.isNotEmpty ? date : desc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
                ),
                trailing: Text(
                  formatMoney(isDebit ? -amount.abs() : amount.abs(), currency, showSign: true),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDebit ? context.colors.danger : context.colors.positive,
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSummaryBox(String label, double amount, String currency, Color color, {bool isPositive = false, bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: context.colors.textMuted)),
          const SizedBox(height: 4),
          Text(
            formatMoney(
              isNegative ? -amount.abs() : (isPositive ? amount.abs() : amount),
              currency,
              showSign: isPositive,
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
