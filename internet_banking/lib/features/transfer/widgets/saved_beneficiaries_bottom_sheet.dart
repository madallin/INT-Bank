import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/app_log.dart';

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
      final response = await _client.get('/users/${widget.userId}/beneficiaries');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['beneficiaries'] != null) {
          setState(() {
            _beneficiaries = List<Map<String, dynamic>>.from(data['beneficiaries']);
          });
        }
      }
    } catch (e) {
      AppLog.debug('Error fetching beneficiaries', e);
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
      decoration: BoxDecoration(
        color: context.colors.surface,
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
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.beneficiariesBeneficiariSalvati,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.l10n.beneficiariesContacte(_beneficiaries.length),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: context.l10n.beneficiariesCautaDupaNumeIban,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.colors.brand),
              filled: true,
              fillColor: context.colors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: context.colors.brand))
                : _filteredBeneficiaries.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_outlined, size: 48, color: context.colors.border),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isEmpty ? context.l10n.beneficiariesNiciunBeneficiarSalvatInca : context.l10n.beneficiariesNiciunRezultatGasit,
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
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
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
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
                        color: (bankInfo?.primaryColor ?? context.colors.brand).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'B',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: bankInfo?.primaryColor ?? context.colors.brand,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(iban, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary, fontWeight: FontWeight.w500)),
                        if (bankName.isNotEmpty)
                          Text(bankName, style: GoogleFonts.inter(fontSize: 10, color: context.colors.brand, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textMuted),
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
