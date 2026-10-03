import '../../../theme/app_tokens.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/error_retry_view.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/transaction_entry.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/services/privacy_mode_service.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../widgets/shimmer_loading.dart';
import '../widgets/transaction_details_bottom_sheet.dart';
import '../../../l10n/l10n.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final int userId;
  final int accountId;
  final String currency;

  const TransactionHistoryScreen({
    super.key,
    required this.userId,
    required this.accountId,
    this.currency = 'RON',
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
  String? _loadError;
  int _selectedFilterIndex = 0; // 0: Toate, 1: Intrări (+), 2: Ieșiri (-), 3: Luna curentă
  String _searchQuery = '';

  List<String> get _filterChips => [
    context.l10n.historyToate,
    context.l10n.historyIntrari,
    context.l10n.historyIesiri,
    context.l10n.historyLunaCurenta,
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

  String get _loadErrorFallback =>
      context.l10n.historySPututIncarcaIstoricul;

  Future<void> _fetchTransactions({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    String? error;
    try {
      final response = await DioClient().get(
        '/users/${widget.userId}/accounts/${widget.accountId}/transactions',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;
        if (data['transactions'] != null && mounted) {
          setState(() => _transactions =
              List<Map<String, dynamic>>.from(data['transactions']));
        }
      } else {
        error = _loadErrorFallback;
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      error = friendlyErrorMessage(e, fallback: _loadErrorFallback);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error;
        });
      }
    }
    // A failed pull-to-refresh keeps the list already on screen.
    if (silent && error != null && _transactions.isNotEmpty && mounted) {
      showErrorSnackBar(context, error);
    }
  }

  Widget _buildLoadError() {
    return ErrorRetryView(
      message: _loadError!,
      onRetry: _fetchTransactions,
      icon: Icons.receipt_long_outlined,
    );
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    final now = DateTime.now();
    return _transactions.where((t) {
      final entry = TransactionEntry.fromJson(t);
      if (_selectedFilterIndex == 1 && !entry.isIncoming) return false;
      if (_selectedFilterIndex == 2 && entry.isIncoming) return false;
      if (_selectedFilterIndex == 3) {
        final d = entry.date;
        if (d == null || d.month != now.month || d.year != now.year) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty &&
          !entry.searchText.contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  double get _filteredTotalSum => _filteredTransactions.fold(
      0.0, (sum, t) => sum + TransactionEntry.fromJson(t).signedAmount);

  String _formatAmount(TransactionEntry entry) {
    if (PrivacyModeService().isPrivacyModeEnabled.value) {
      return maskedFigure;
    }
    return formatAmount(entry.signedAmount, showSign: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final totalSum = _filteredTotalSum;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SimpleAppBar(
              title: context.l10n.historyIstoricTranzactii,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const TransactionListSkeleton(itemCount: 7)
                  : _loadError != null && _transactions.isEmpty
                  ? _buildLoadError()
                  : FadeTransition(
                      opacity: _fadeAnimation!,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: context.colors.surface,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: GoogleFonts.inter(fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: false,
                                      hintText: context.l10n.historyCautaComerciantDescriere,
                                      hintStyle: GoogleFonts.inter(
                                          fontSize: 14, color: context.colors.textMuted),
                                      prefixIcon: Icon(Icons.search_rounded,
                                          color: context.colors.textMuted, size: 20),
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
                                              context.colors.brand,
                                          backgroundColor:
                                              context.colors.surfaceMuted,
                                          labelStyle: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : context.colors.textPrimary,
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
                            color: context.colors.background,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                Text(
                                  context.l10n.historyResultsCount(filtered.length),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  PrivacyModeService().isPrivacyModeEnabled.value
                                      ? context.l10n.historyTotal(maskedMoney(widget.currency))
                                      : context.l10n.historyTotal2(formatMoney(totalSum, widget.currency, showSign: true)),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: totalSum >= 0
                                        ? context.colors.brand
                                        : context.colors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: EmptyStatePlaceholder(
                                      title:
                                          context.l10n.historyAuFostGasiteTranzactii,
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () =>
                                        _fetchTransactions(silent: true),
                                    color: context.colors.brand,
                                    child: ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        return _buildTransactionCard(
                                            filtered[index]);
                                      },
                                    ),
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
    final entry = TransactionEntry.fromJson(transaction);
    final isPositive = entry.isIncoming;
    final amountStr = _formatAmount(entry);

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
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border, width: 1.2),
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
                      ? context.colors.brandSurface
                      : context.colors.dangerSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isPositive
                      ? context.colors.positive
                      : context.colors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.date == null ? '' : formatDateTime(entry.date!),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.colors.textMuted,
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
                          ? context.colors.brand
                          : context.colors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.currency ?? widget.currency,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMuted,
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
