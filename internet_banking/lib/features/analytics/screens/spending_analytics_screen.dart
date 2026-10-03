import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/error_retry_view.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../l10n/l10n.dart';

class SpendingAnalyticsScreen extends StatefulWidget {
  final int userId;
  final int accountId;
  final String currency;

  const SpendingAnalyticsScreen({
    super.key,
    required this.userId,
    required this.accountId,
    this.currency = 'RON',
  });

  @override
  State<SpendingAnalyticsScreen> createState() => _SpendingAnalyticsScreenState();
}

class _SpendingAnalyticsScreenState extends State<SpendingAnalyticsScreen> {
  final DioClient _client = DioClient();

  late DateTime _currentMonth;
  bool _loading = true;
  Map<String, dynamic>? _analyticsData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _fetchAnalytics();
  }

  String _getMonthName(int month) {
    final months = [
      context.l10n.analyticsIanuarie, context.l10n.analyticsFebruarie, context.l10n.analyticsMartie, context.l10n.analyticsAprilie, context.l10n.analyticsMai, context.l10n.analyticsIunie,
      context.l10n.analyticsIulie, context.l10n.analyticsAugust, context.l10n.analyticsSeptembrie, context.l10n.analyticsOctombrie, context.l10n.analyticsNoiembrie, context.l10n.analyticsDecembrie
    ];
    return months[month - 1];
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final monthStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/${widget.accountId}/analytics?month=$monthStr',
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _analyticsData = Map<String, dynamic>.from(response.data as Map);
        });
      } else {
        setState(() => _errorMessage = context.l10n.analyticsSAuPututIncarca);
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyErrorMessage(e, fallback: context.l10n.analyticsSAuPututIncarca2));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _analyticsData?['currency'] ?? widget.currency;
    final totalSpent = (_analyticsData?['totalSpent'] as num?)?.toDouble() ?? 0.0;
    final topCategory = _analyticsData?['topCategory'] ?? '-';
    final totalTransactions = _analyticsData?['totalTransactions'] as int? ?? 0;
    final categories = (_analyticsData?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: SimpleAppBar(
        title: context.l10n.analyticsStatisticiCheltuieli,
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Month Selector Bar
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  tooltip: context.l10n.analyticsLunaAnterioara,
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  tooltip: context.l10n.analyticsLunaUrmatoare,
                  onPressed: (_currentMonth.year == DateTime.now().year && _currentMonth.month >= DateTime.now().month)
                      ? null
                      : () => _changeMonth(1),
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
                    onRetry: _fetchAnalytics,
                    icon: Icons.pie_chart_outline_rounded,
                  )
                : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.heroStart, context.colors.heroEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.analyticsTotalCheltuit(_getMonthName(_currentMonth.month).toUpperCase()),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatMoney(totalSpent, currency),
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.analyticsCategorieTop(topCategory),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                          Text(
                            context.l10n.analyticsPlati(totalTransactions),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  context.l10n.analyticsDistributieCategorii,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),

                if (totalSpent == 0)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_outlined, size: 40, color: context.colors.border),
                          const SizedBox(height: 10),
                          Text(context.l10n.analyticsNicioCheltuialaAceastaLuna, style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted)),
                        ],
                      ),
                    ),
                  )
                else
                  ...categories.where((c) => ((c['amount'] as num?)?.toDouble() ?? 0) > 0).map((c) {
                    final name = c['categoryName'] ?? '';
                    final key = c['categoryKey'] ?? '';
                    final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
                    final pct = (c['percentage'] as num?)?.toDouble() ?? 0.0;
                    final count = c['transactionCount'] as int? ?? 0;
                    final color = _getCategoryColor(key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_getCategoryIcon(key), color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                                    ),
                                    Text(
                                      context.l10n.analyticsCategoryCount(count, formatPercent(pct)),
                                      style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatMoney(amt, currency),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              backgroundColor: context.colors.surfaceMuted,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String key) {
    switch (key) {
      case 'ALIMENTE':
        return context.colors.positive;
      case 'UTILITATI':
        return const Color(0xFFE65100);
      case 'RESTAURANTE':
        return const Color(0xFFC2185B);
      case 'TRANSPORT':
        return const Color(0xFF1565C0);
      case 'DIVERTISMENT':
        return const Color(0xFF7B1FA2);
      default:
        return context.colors.brand;
    }
  }

  IconData _getCategoryIcon(String key) {
    switch (key) {
      case 'ALIMENTE':
        return Icons.shopping_cart_outlined;
      case 'UTILITATI':
        return Icons.bolt_rounded;
      case 'RESTAURANTE':
        return Icons.restaurant_rounded;
      case 'TRANSPORT':
        return Icons.directions_car_filled_outlined;
      case 'DIVERTISMENT':
        return Icons.movie_creation_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}
