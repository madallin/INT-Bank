import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/services/privacy_mode_service.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../widgets/shimmer_loading.dart';
import '../widgets/transaction_details_bottom_sheet.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final int userId;
  final int accountId;

  const TransactionHistoryScreen({
    super.key,
    required this.userId,
    required this.accountId,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with TickerProviderStateMixin {
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  int _selectedFilterIndex = 0; // 0: Toate, 1: Intrări (+), 2: Ieșiri (-), 3: Luna curentă
  String _searchQuery = '';

  final List<String> _filterChips = [
    'Toate',
    'Intrări (+)',
    'Ieșiri (-)',
    'Luna curentă',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController!, curve: Curves.easeInOut);
    _fadeController!.forward();

    PrivacyModeService().init();
    PrivacyModeService().isPrivacyModeEnabled.addListener(_onPrivacyChanged);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _fetchTransactions();
  }

  void _onPrivacyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PrivacyModeService().isPrivacyModeEnabled.removeListener(_onPrivacyChanged);
    _fadeController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _loading = true);
    try {
      final response = await DioClient().get(
        '/users/${widget.userId}/accounts/${widget.accountId}/transactions',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;
        if (data['transactions'] != null) {
          setState(() => _transactions =
              List<Map<String, dynamic>>.from(data['transactions']));
        }
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((t) {
      if (_selectedFilterIndex == 1 && t['type'] != 'received') {
        return false;
      }
      if (_selectedFilterIndex == 2 && t['type'] == 'received') {
        return false;
      }
      if (_selectedFilterIndex == 3) {
        try {
          final d = DateTime.parse(t['dataTransfer'] ?? '');
          final now = DateTime.now();
          if (d.month != now.month || d.year != now.year) return false;
        } catch (_) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final beneficiary = (t['beneficiary'] ?? '').toString().toLowerCase();
        final reason = (t['motiv'] ?? '').toString().toLowerCase();
        final iban = (t['iban'] ?? '').toString().toLowerCase();
        final matches = beneficiary.contains(_searchQuery) ||
            reason.contains(_searchQuery) ||
            iban.contains(_searchQuery);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  double get _filteredTotalSum {
    double total = 0.0;
    for (final t in _filteredTransactions) {
      final amt = (t['suma'] as num?)?.toDouble() ?? 0.0;
      if (t['type'] == 'received') {
        total += amt;
      } else {
        total -= amt;
      }
    }
    return total;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year;
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$d.$m.$y, $h:$min';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmount(Map<String, dynamic> transaction) {
    if (PrivacyModeService().isPrivacyModeEnabled.value) {
      return '\u2022\u2022\u2022\u2022';
    }
    final type = transaction['type'];
    final double amount = (transaction['suma'] as num).toDouble();
    final displayAmount = type == 'received' ? amount : -amount;
    final absAmount = displayAmount.abs();
    final formatted = absAmount.toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    final sign = displayAmount >= 0 ? '+' : '-';
    return '$sign$intPart,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final totalSum = _filteredTotalSum;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: 'Istoric tranzacții',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const TransactionListSkeleton(itemCount: 7)
                  : FadeTransition(
                      opacity: _fadeAnimation!,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: GoogleFonts.inter(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Caută comerciant, descriere...',
                                      hintStyle: GoogleFonts.inter(
                                          fontSize: 14, color: Colors.grey[500]),
                                      prefixIcon: Icon(Icons.search_rounded,
                                          color: Colors.grey[500], size: 20),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear_rounded,
                                                  size: 18),
                                              onPressed: () {
                                                HapticFeedbackHelper.selection();
                                                _searchController.clear();
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(
                                        _filterChips.length, (index) {
                                      final isSelected =
                                          _selectedFilterIndex == index;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: ChoiceChip(
                                          label: Text(_filterChips[index]),
                                          selected: isSelected,
                                          onSelected: (_) {
                                            HapticFeedbackHelper.selection();
                                            setState(() =>
                                                _selectedFilterIndex = index);
                                          },
                                          selectedColor:
                                              const Color(lightForestGreenColor),
                                          backgroundColor:
                                              const Color(0xFFF1F5F3),
                                          labelStyle: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(darkGreyColor),
                                          ),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          side: BorderSide.none,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            color: const Color(0xFFF9FAFB),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${filtered.length} ${filtered.length == 1 ? "tranzacție găsită" : "tranzacții găsite"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  PrivacyModeService().isPrivacyModeEnabled.value
                                      ? 'Total: •••• RON'
                                      : 'Total: ' + (totalSum >= 0 ? '+' : '') + totalSum.toStringAsFixed(2) + ' RON',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: totalSum >= 0
                                        ? const Color(lightForestGreenColor)
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: filtered.isEmpty
                                ? const Center(
                                    child: EmptyStatePlaceholder(
                                      title:
                                          'Nu au fost găsite tranzacții care să corespundă căutării.',
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      return _buildTransactionCard(
                                          filtered[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final isPositive = transaction['type'] == 'received';
    final amountStr = _formatAmount(transaction);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedbackHelper.buttonTap();
          TransactionDetailsBottomSheet.show(context, transaction);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey[200]!, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isPositive
                      ? const Color(0xFF2E7D32)
                      : Colors.red.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['beneficiary'] ??
                          transaction['motiv'] ??
                          'Tranzacție',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(darkGreyColor),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(transaction['dataTransfer'] ?? ''),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountStr,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPositive
                          ? const Color(lightForestGreenColor)
                          : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction['moneda'] ?? 'RON',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
