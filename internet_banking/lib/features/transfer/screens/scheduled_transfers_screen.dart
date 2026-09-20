import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../widgets/simple_app_bar.dart';

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
          _errorMessage = 'Nu s-au putut încărca plățile programate.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Eroare de conexiune: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteTransfer(int id) async {
    try {
      final response = await _dioClient.delete('/users/${widget.userId}/scheduled-transfers/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plata programată a fost anulată.', style: GoogleFonts.inter()),
            backgroundColor: const Color(lightForestGreenColor),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchScheduledTransfers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la anulare: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmCancel(int id, String beneficiary, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Anulare plată recurentă', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Ești sigur că dorești să anulezi plata recurentă de ${amount.toStringAsFixed(2)} RON către $beneficiary?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Păstrează', style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTransfer(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: Text('Anulează plata', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatFrequency(String freq) {
    switch (freq.toUpperCase()) {
      case 'WEEKLY':
        return 'Săptămânal';
      case 'MONTHLY':
        return 'Lunar';
      default:
        return 'O singură dată';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: SimpleAppBar(
        title: 'Plăți programate',
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(lightForestGreenColor)))
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red[700])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchScheduledTransfers,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(lightForestGreenColor)),
                child: const Text('Reîncearcă', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
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
                  color: const Color(lightForestGreenColor).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month_outlined, size: 48, color: Color(lightForestGreenColor)),
              ),
              const SizedBox(height: 16),
              Text(
                'Nicio plată programată',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
              ),
              const SizedBox(height: 8),
              Text(
                'Poți seta plăți recurente sau viitoare direct din ecranul de transfer activând opțiunea "Programare plată".',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchScheduledTransfers,
        color: const Color(lightForestGreenColor),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _transfers.length,
          itemBuilder: (context, index) {
            final t = _transfers[index];
            final id = t['id'] as int? ?? 0;
            final beneficiary = t['beneficiaryName'] ?? 'Beneficiar';
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
                color: Colors.white,
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(lightForestGreenColor).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.repeat_rounded, color: Color(lightForestGreenColor), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                beneficiary,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                              ),
                              if (bank != null)
                                Text(
                                  bank.name,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${amount.toStringAsFixed(2)} RON',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    iban,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], letterSpacing: 0.5),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Detalii: $reason',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
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
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatFrequency(freq),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Următoarea: $nextRun',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        tooltip: 'Anulează',
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
