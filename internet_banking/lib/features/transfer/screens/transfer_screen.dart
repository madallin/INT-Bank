import 'scheduled_transfers_screen.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../widgets/action_button.dart';
import '../../../widgets/form_text_field.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';
import '../widgets/saved_beneficiaries_bottom_sheet.dart';

class TransferScreen extends StatefulWidget {
  final int userId;
  final String userIban;

  const TransferScreen({
    super.key,
    required this.userId,
    required this.userIban,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with TickerProviderStateMixin {
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final DioClient _dioClient = DioClient();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _loading = false;
  bool _saveAsBeneficiary = false;
  bool _isScheduled = false;
  String _frequency = 'MONTHLY'; // ONCE, WEEKLY, MONTHLY
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));

  String _deviceId = 'dev-device';

  RomanianBankInfo? _detectedBank;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _initDeviceId();

    _ibanController.addListener(() {
      final bank = IbanBankDetector.detectBank(_ibanController.text);
      if (bank != _detectedBank) {
        setState(() => _detectedBank = bank);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ibanController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _formatIBAN(String input) {
    String clean = input.replaceAll(' ', '').toUpperCase();
    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += clean[i];
    }
    return formatted;
  }

  String _formatAmount(String input) {
    String clean = input.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return '';
    String reversed = clean.split('').reversed.join('');
    String formatted = '';
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) formatted += '.';
      formatted += reversed[i];
    }
    return formatted.split('').reversed.join('');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.inter(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.inter(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(lightForestGreenColor),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initDeviceId() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      _deviceId = (await info.androidInfo).id;
    } else if (Platform.isIOS) {
      _deviceId = (await info.iosInfo).identifierForVendor ?? 'ios-device';
    }
  }



  Future<void> _submitTransfer() async {
    final iban = _ibanController.text.replaceAll(' ', '');
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.replaceAll('.', ''));
    final reason = _reasonController.text.trim();

    if (iban.isEmpty || iban.length < 16) {
      return _showError('IBAN invalid');
    }
    if (name.length < 7 || name.length > 128) {
      return _showError('Numele trebuie să aibă 7-128 caractere');
    }
    if (!name.contains(' ')) {
      return _showError('Trebuie minim un nume și un prenume');
    }
    if (reason.length < 3) return _showError('Motiv prea scurt');
    if (amount == null || amount <= 0) return _showError('Sumă invalidă');
    if (iban.toUpperCase() == widget.userIban.replaceAll(' ', '').toUpperCase()) {
      return _showError('Nu poți trimite bani în propriul cont');
    }

    setState(() => _loading = true);

    try {
      if (_isScheduled) {
        final formattedDate = '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}';
        final resp = await _dioClient.post(
          '/users/${widget.userId}/scheduled-transfers',
          data: {
            'toIban': iban,
            'beneficiaryName': name.toUpperCase(),
            'amount': amount,
            'reason': reason,
            'frequency': _frequency,
            'nextRunDate': formattedDate,
          },
        );

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          _showSuccess('Plata programată a fost setată cu succes!');
          _cleanForm();
        } else {
          _showError('Eroare la programarea plății');
        }
      } else {
        // Instant standard transfer
        final response = await _dioClient.post(
          '/users/${widget.userId}/transfer',
          data: {
            'iban': iban,
            if (widget.userIban.isNotEmpty) 'fromIban': widget.userIban,
            'beneficiaryName': name.toUpperCase(),
            'amount': amount,
            'reason': reason[0].toUpperCase() + reason.substring(1),
          },
        );

        if (response.statusCode == 200) {
          final data = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : jsonDecode(response.data.toString());
          if (data['success'] == true) {
            _showSuccess('Transfer efectuat cu succes!');
            if (_saveAsBeneficiary) {
              _saveBeneficiary(name, iban);
            }
            _cleanForm();
          } else {
            _showError(data['error'] ?? 'Eroare la transfer');
          }
        } else {
          _showError('Eroare la efectuarea transferului');
        }
      }
    } catch (e) {
      _showError('Eroare de conexiune: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBeneficiary(String name, String iban) async {
    try {
      await _dioClient.post(
        '/users/${widget.userId}/beneficiaries',
        data: {
          'name': name.toUpperCase(),
          'iban': iban,
          'bankName': _detectedBank?.name,
        },
      );
    } catch (_) {}
  }

  void _cleanForm() {
    _ibanController.clear();
    _nameController.clear();
    _amountController.clear();
    _reasonController.clear();
    setState(() {
      _saveAsBeneficiary = false;
      _isScheduled = false;
    });
  }

  void _openBeneficiaries() {
    SavedBeneficiariesBottomSheet.show(
      context,
      userId: widget.userId,
      onSelect: (name, iban) {
        _nameController.text = name;
        _ibanController.text = _formatIBAN(iban);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SimpleAppBar(
        title: 'Transfer bancar',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageTitle(
                  title: 'Transfer nou',
                  subtitle: 'Completeaza datele pentru a efectua transferul',
                ),
                const SizedBox(height: 24),

                // Beneficiary Shortcut Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DESTINATAR',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScheduledTransfersScreen(userId: widget.userId),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_month_outlined, size: 15, color: Color(lightForestGreenColor)),
                          label: Text(
                            'Programate',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(lightForestGreenColor)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _openBeneficiaries,
                          icon: const Icon(Icons.contacts_rounded, size: 15, color: Color(lightForestGreenColor)),
                          label: Text(
                            'Agendă',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(lightForestGreenColor)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                FormTextField(
                  controller: _ibanController,
                  label: 'IBAN destinatar',
                  icon: Icons.account_balance_outlined,
                  hint: 'RO49 AAAA 1B31 0075 9384 0000',
                  maxLength: 34,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final formatted = _formatIBAN(newValue.text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                ),

                // Bank Auto-Detection Badge
                if (_detectedBank != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _detectedBank!.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _detectedBank!.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_rounded, size: 14, color: _detectedBank!.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          _detectedBank!.name,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _detectedBank!.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                FormTextField(
                  controller: _nameController,
                  label: 'Nume beneficiar',
                  icon: Icons.person_outline,
                  hint: 'Popescu Ion',
                  keyboardType: TextInputType.name,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s-]')),
                  ],
                ),
                const SizedBox(height: 16),

                FormTextField(
                  controller: _amountController,
                  label: 'Suma (RON)',
                  icon: Icons.payments_outlined,
                  hint: '100',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final formatted = _formatAmount(newValue.text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                FormTextField(
                  controller: _reasonController,
                  label: 'Motiv transfer',
                  icon: Icons.description_outlined,
                  hint: 'Plată factură, Rambursare etc.',
                  keyboardType: TextInputType.text,
                  maxLength: 140,
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _saveAsBeneficiary,
                  onChanged: (val) => setState(() => _saveAsBeneficiary = val ?? false),
                  title: Text(
                    'Salvează destinatarul în agenda de plăți',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(darkGreyColor)),
                  ),
                  activeColor: const Color(lightForestGreenColor),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2ECE6)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(Icons.schedule_rounded, color: Color(lightForestGreenColor)),
                      title: Text(
                        'Programare plată / Recurență',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                      ),
                      initiallyExpanded: _isScheduled,
                      onExpansionChanged: (val) => setState(() => _isScheduled = val),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Frecvență execuție', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildFrequencyChip('O dată', 'ONCE'),
                                  const SizedBox(width: 8),
                                  _buildFrequencyChip('Săptămânal', 'WEEKLY'),
                                  const SizedBox(width: 8),
                                  _buildFrequencyChip('Lunar', 'MONTHLY'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Data execuției: ${_scheduledDate.day}.${_scheduledDate.month}.${_scheduledDate.year}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _scheduledDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) setState(() => _scheduledDate = picked);
                                    },
                                    child: Text('Schimbă data', style: GoogleFonts.inter(color: const Color(lightForestGreenColor), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ActionButton(
                  label: _isScheduled ? 'Programează transferul' : 'Transferă acum',
                  onTap: _loading ? null : _submitTransfer,
                  isLoading: _loading,
                  isExpanded: false,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(String label, String value) {
    final selected = _frequency == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _frequency = value),
      selectedColor: const Color(lightForestGreenColor),
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : const Color(darkGreyColor),
      ),
    );
  }
}
