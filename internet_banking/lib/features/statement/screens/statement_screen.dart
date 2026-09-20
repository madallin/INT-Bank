import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../transactions/widgets/transaction_details_bottom_sheet.dart';

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

  final List<String> _presets = ['30 zile', '3 luni', '6 luni', '1 an', 'Personalizat'];

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
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(lightForestGreenColor),
              onPrimary: Colors.white,
              onSurface: Color(darkGreyColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchStatement();
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDisplayDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }

  Future<void> _fetchStatement() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final fromStr = _formatDate(_startDate);
    final toStr = _formatDate(_endDate);

    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/${widget.accountId}/statement?from=$fromStr&to=$toStr',
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _statementData = Map<String, dynamic>.from(response.data as Map);
        });
      } else {
        setState(() => _errorMessage = 'Nu s-a putut încărca extrasul de cont.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Eroare de comunicare cu serverul: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    final fromStr = _formatDate(_startDate);
    final toStr = _formatDate(_endDate);

    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/${widget.accountId}/statement/pdf?from=$fromStr&to=$toStr',
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extrasul PDF ($fromStr - $toStr) a fost generat cu succes!',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(lightForestGreenColor),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la descărcarea PDF-ului: $e', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: const SimpleAppBar(title: 'Extras de cont'),
      body: Column(
        children: [
          // Period Selector Chips
          Container(
            color: Colors.white,
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
                          selectedColor: const Color(lightForestGreenColor),
                          backgroundColor: const Color(0xFFF1F5F3),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(darkGreyColor),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide.none,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Perioada: ${_formatDisplayDate(_startDate)} - ${_formatDisplayDate(_endDate)}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    Text(
                      widget.iban,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(lightForestGreenColor)))
                : _errorMessage != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchStatement,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(lightForestGreenColor)),
                      child: const Text('Reîncearcă', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
                : _buildStatementContent(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: (_loading || _downloadingPdf) ? null : _downloadPdf,
            icon: _downloadingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: Text(
              _downloadingPdf ? 'Se generează PDF...' : 'Descarcă extras PDF',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(lightForestGreenColor),
              foregroundColor: Colors.white,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryBox('SOLD INIȚIAL', openingBalance, currency, const Color(darkGreyColor))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox('SOLD FINAL', closingBalance, currency, const Color(lightForestGreenColor))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryBox('ÎNCASĂRI (+)', totalInflows, currency, const Color(0xFF2E7D32), isPositive: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryBox('PLĂȚI (-)', totalOutflows, currency, const Color(0xFFC62828), isNegative: true)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OPERAȚIUNI (${transactions.length})',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5),
            ),
            Text(
              'Atinge o tranzacție pentru detalii',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('Nicio operațiune în această perioadă', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ...transactions.map((tx) {
            final isDebit = tx['type'] == 'DEBIT';
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final partyName = tx['partyName'] ?? 'Transfer';
            final desc = tx['description'] ?? '';
            final date = tx['date'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                onTap: () => TransactionDetailsBottomSheet.show(context, tx),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDebit ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isDebit ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                    size: 20,
                  ),
                ),
                title: Text(
                  partyName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                ),
                subtitle: Text(
                  date.isNotEmpty && desc.isNotEmpty ? '$date • $desc' : (date.isNotEmpty ? date : desc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                ),
                trailing: Text(
                  '${isDebit ? "-" : "+"}${amount.toStringAsFixed(2)} $currency',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDebit ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
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
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(
            '${isPositive ? "+" : isNegative ? "-" : ""}${amount.toStringAsFixed(2)} $currency',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
