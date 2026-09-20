import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../widgets/simple_app_bar.dart';

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
    const months = [
      'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
      'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
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
        setState(() => _errorMessage = 'Nu s-au putut încarca statisticile.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Eroare de conexiune: $e');
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
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: SimpleAppBar(
        title: 'Statistici cheltuieli',
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Month Selector Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onPressed: (_currentMonth.year == DateTime.now().year && _currentMonth.month >= DateTime.now().month)
                      ? null
                      : () => _changeMonth(1),
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
                    Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchAnalytics,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(lightForestGreenColor)),
                      child: const Text('Reîncearcă', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
                : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(lightForestGreenColor), Color(darkForestGreenColor)],
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
                        'TOTAL CHELTUIT ÎN ${_getMonthName(_currentMonth.month).toUpperCase()}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalSpent.toStringAsFixed(2)} $currency',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Categorie top: $topCategory',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                          Text(
                            '$totalTransactions plăți',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'DISTRIBUȚIE PE CATEGORII',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),

                if (totalSpent == 0)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_outlined, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text('Nicio cheltuială în această lună', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
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
                        color: Colors.white,
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
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                                    ),
                                    Text(
                                      '$count ${count == 1 ? 'tranzacție' : 'tranzacții'} • ${pct.toStringAsFixed(1)}%',
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${amt.toStringAsFixed(2)} $currency',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[100],
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
        return const Color(0xFF2E7D32);
      case 'UTILITATI':
        return const Color(0xFFE65100);
      case 'RESTAURANTE':
        return const Color(0xFFC2185B);
      case 'TRANSPORT':
        return const Color(0xFF1565C0);
      case 'DIVERTISMENT':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(lightForestGreenColor);
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
