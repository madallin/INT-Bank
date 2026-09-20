import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/iban_bank_detector.dart';

class SavedBeneficiariesBottomSheet extends StatefulWidget {
  final int userId;
  final Function(String name, String iban) onSelect;

  const SavedBeneficiariesBottomSheet({
    super.key,
    required this.userId,
    required this.onSelect,
  });

  static void show(BuildContext context, {
    required int userId,
    required Function(String name, String iban) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavedBeneficiariesBottomSheet(userId: userId, onSelect: onSelect),
    );
  }

  @override
  State<SavedBeneficiariesBottomSheet> createState() => _SavedBeneficiariesBottomSheetState();
}

class _SavedBeneficiariesBottomSheetState extends State<SavedBeneficiariesBottomSheet> {
  final DioClient _client = DioClient();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _beneficiaries = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBeneficiaries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBeneficiaries() async {
    setState(() => _loading = true);
    try {
      final response = await _client.get('/users//beneficiaries');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['beneficiaries'] != null) {
          setState(() {
            _beneficiaries = List<Map<String, dynamic>>.from(data['beneficiaries']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching beneficiaries: ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBeneficiaries {
    if (_searchQuery.trim().isEmpty) return _beneficiaries;
    final q = _searchQuery.toLowerCase();
    return _beneficiaries.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      final iban = (b['iban'] ?? '').toString().toLowerCase();
      final nickname = (b['nickname'] ?? '').toString().toLowerCase();
      return name.contains(q) || iban.contains(q) || nickname.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Beneficiari salvați',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(lightForestGreenColor).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_beneficiaries.length} contacte',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(lightForestGreenColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Caută după nume sau IBAN...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(lightForestGreenColor)),
              filled: true,
              fillColor: const Color(0xFFF7FAF8),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(lightForestGreenColor)))
                : _filteredBeneficiaries.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isEmpty ? 'Nu ai niciun beneficiar salvat încă' : 'Niciun rezultat găsit',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredBeneficiaries.length,
              itemBuilder: (context, index) {
                final b = _filteredBeneficiaries[index];
                final name = b['name'] ?? '';
                final iban = b['iban'] ?? '';
                final bankName = b['bankName'] ?? '';
                final bankInfo = IbanBankDetector.detectBank(iban);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(name, iban);
                    },
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (bankInfo?.primaryColor ?? const Color(lightForestGreenColor)).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'B',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: bankInfo?.primaryColor ?? const Color(lightForestGreenColor),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(iban, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        if (bankName.isNotEmpty)
                          Text(bankName, style: GoogleFonts.inter(fontSize: 10, color: const Color(lightForestGreenColor), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
