import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/iban_bank_detector.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/form_text_field.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../theme/app_tokens.dart';
import '../transfer_form_validator.dart';
import '../widgets/saved_beneficiaries_bottom_sheet.dart';
import '../widgets/transfer_confirmation_bottom_sheet.dart';
import 'scheduled_transfers_screen.dart';
import 'transfer_receipt_screen.dart';
import '../../../l10n/l10n.dart';

class TransferScreen extends StatefulWidget {
  final int userId;
  final String userIban;
  final String currency;

  /// Balance of the source account, when known; used for the "available"
  /// hint and to catch amounts above it before submitting.
  final double? availableBalance;

  const TransferScreen({
    super.key,
    required this.userId,
    required this.userIban,
    this.currency = 'RON',
    this.availableBalance,
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

  final _ibanFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _reasonFocus = FocusNode();

  /// Inline errors appear after the first submit attempt, then update live.
  bool _submitted = false;

  Map<String, String> get _frequencyLabels => {
    'ONCE': context.l10n.transferData,
    'WEEKLY': context.l10n.commonSaptamanal,
    'MONTHLY': context.l10n.commonLunar,
  };

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _loading = false;
  bool _saveAsBeneficiary = false;
  bool _isScheduled = false;
  String _frequency = 'MONTHLY'; // ONCE, WEEKLY, MONTHLY
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));

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
    _ibanFocus.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    showErrorSnackBar(context, message);
  }

  double? get _amount {
    final parsed = parseRomanianNumber(_amountController.text);
    return parsed == null ? null : (parsed * 100).roundToDouble() / 100;
  }

  String? get _ibanError => _submitted
      ? TransferFormValidator.iban(_ibanController.text, ownIban: widget.userIban)
      : null;
  String? get _nameError =>
      _submitted ? TransferFormValidator.beneficiaryName(_nameController.text) : null;
  String? get _amountError => _submitted
      ? TransferFormValidator.amount(_amount,
          available: widget.availableBalance, currency: widget.currency)
      : null;
  String? get _reasonError =>
      _submitted ? TransferFormValidator.reason(_reasonController.text) : null;

  void _revalidate(String _) {
    if (_submitted) setState(() {});
  }

  String get _scheduleSummary =>
      context.l10n.transferDin(_frequencyLabels[_frequency] ?? _frequency, formatDate(_scheduledDate));

  Future<void> _submitTransfer() async {
    setState(() => _submitted = true);

    final firstInvalid = [
      (_ibanError, _ibanFocus),
      (_nameError, _nameFocus),
      (_amountError, _amountFocus),
      (_reasonError, _reasonFocus),
    ].where((f) => f.$1 != null).map((f) => f.$2).firstOrNull;
    if (firstInvalid != null) {
      HapticFeedbackHelper.error();
      firstInvalid.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();

    final iban = TransferFormValidator.normalizeIban(_ibanController.text);
    final name = _nameController.text.trim();
    final amount = _amount!;
    final reason = _reasonController.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferConfirmationBottomSheet(
        beneficiaryName: name.toUpperCase(),
        toIban: iban,
        fromIban: widget.userIban,
        amount: amount,
        currency: widget.currency,
        reason: reason[0].toUpperCase() + reason.substring(1),
        bankInfo: _detectedBank,
        isScheduled: _isScheduled,
        scheduleDetails: _isScheduled ? _scheduleSummary : null,
        onConfirm: () => _executeTransfer(
          iban: iban,
          name: name,
          amount: amount,
          reason: reason,
        ),
      ),
    );
  }

  /// Shows the receipt, then either resets the form or returns to the account.
  Future<void> _showReceipt(TransferReceipt receipt) async {
    final action = await Navigator.of(context).push<TransferReceiptAction>(
      MaterialPageRoute(builder: (_) => TransferReceiptScreen(receipt: receipt)),
    );
    if (!mounted) return;
    if (action == TransferReceiptAction.newTransfer) {
      _cleanForm();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _executeTransfer({
    required String iban,
    required String name,
    required double amount,
    required String reason,
  }) async {
    setState(() => _loading = true);

    try {
      if (_isScheduled) {
        final formattedDate = formatApiDate(_scheduledDate);
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
          await _showReceipt(TransferReceipt(
            amount: amount,
            currency: widget.currency,
            beneficiaryName: name.toUpperCase(),
            toIban: iban,
            fromIban: widget.userIban,
            reason: reason,
            createdAt: DateTime.now(),
            bankName: _detectedBank?.name,
            scheduleSummary: _scheduleSummary,
          ));
        } else {
          _showError(AppL10n.current.transferEroareProgramareaPlatii);
        }
      } else {
        // Instant standard transfer with unique client-side idempotency key
        final idempotencyKey = 'tx-cli-${widget.userId}-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
        final response = await _dioClient.post(
          '/users/${widget.userId}/transfer',
          options: Options(headers: {
            'Idempotency-Key': idempotencyKey,
          }),
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
            HapticFeedbackHelper.success();
            if (_saveAsBeneficiary) {
              _saveBeneficiary(name, iban);
            }
            await _showReceipt(TransferReceipt(
              amount: amount,
              currency: widget.currency,
              beneficiaryName: name.toUpperCase(),
              toIban: iban,
              fromIban: widget.userIban,
              reason: reason[0].toUpperCase() + reason.substring(1),
              createdAt: DateTime.now(),
              bankName: _detectedBank?.name,
              trackingId: data['trackingId']?.toString(),
              status: data['status']?.toString(),
            ));
          } else {
            _showError(data['error'] ?? AppL10n.current.transferEroareTransfer);
          }
        } else {
          _showError(AppL10n.current.transferEroareEfectuareaTransferului);
        }
      }
    } catch (e) {
      _showError(friendlyErrorMessage(e, fallback: AppL10n.current.transferTransferulPututFiEfectuat));
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
      _submitted = false;
    });
  }

  void _openBeneficiaries() {
    SavedBeneficiariesBottomSheet.show(
      context,
      userId: widget.userId,
      onSelect: (name, iban) {
        _nameController.text = name;
        _ibanController.text = formatIban(iban);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SimpleAppBar(
        title: context.l10n.commonTransferBancar,
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
                PageTitle(
                  title: context.l10n.commonTransferNou,
                  subtitle: context.l10n.transferCompleteazaDateleEfectuaTransferul,
                ),
                const SizedBox(height: 20),
                _buildSourceAccount(),
                const SizedBox(height: 20),

                // Beneficiary Shortcut Header
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.transferDestinatar,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary, letterSpacing: 0.5),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScheduledTransfersScreen(userId: widget.userId),
                            ),
                          ),
                          icon: Icon(Icons.calendar_month_outlined, size: 15, color: context.colors.brand),
                          label: Text(
                            context.l10n.transferProgramate,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.brand),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _openBeneficiaries,
                          icon: Icon(Icons.contacts_rounded, size: 15, color: context.colors.brand),
                          label: Text(
                            context.l10n.transferAgenda,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.brand),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                FormTextField(
                  controller: _ibanController,
                  label: context.l10n.transferIbanDestinatar,
                  icon: Icons.account_balance_outlined,
                  hint: 'RO49 AAAA 1B31 0075 9384 0000',
                  // 34 characters plus the grouping spaces.
                  maxLength: 42,
                  focusNode: _ibanFocus,
                  errorText: _ibanError,
                  onChanged: _revalidate,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _nameFocus.requestFocus(),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    IBANInputFormatter(),
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
                  label: context.l10n.transferNumeBeneficiar,
                  icon: Icons.person_outline,
                  hint: context.l10n.transferPopescuIon,
                  keyboardType: TextInputType.name,
                  focusNode: _nameFocus,
                  errorText: _nameError,
                  onChanged: _revalidate,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _amountFocus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  maxLength: TransferFormValidator.maxNameLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\s.'-]", unicode: true)),
                  ],
                ),
                const SizedBox(height: 16),

                FormTextField(
                  controller: _amountController,
                  label: context.l10n.transferSuma(widget.currency),
                  icon: Icons.payments_outlined,
                  hint: '100,00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  focusNode: _amountFocus,
                  errorText: _amountError,
                  onChanged: _revalidate,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _reasonFocus.requestFocus(),
                  inputFormatters: [
                    RomanianAmountInputFormatter(),
                  ],
                ),
                if (widget.availableBalance != null && _amountError == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 6),
                    child: Text(
                      context.l10n.transferDisponibil(formatMoney(widget.availableBalance!, widget.currency)),
                      style: context.text.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),

                FormTextField(
                  controller: _reasonController,
                  label: context.l10n.transferMotivTransfer,
                  icon: Icons.description_outlined,
                  hint: context.l10n.transferPlataFacturaRambursareEtc,
                  keyboardType: TextInputType.text,
                  maxLength: TransferFormValidator.maxReasonLength,
                  focusNode: _reasonFocus,
                  errorText: _reasonError,
                  onChanged: _revalidate,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitTransfer(),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _saveAsBeneficiary,
                  onChanged: (val) => setState(() => _saveAsBeneficiary = val ?? false),
                  title: Text(
                    context.l10n.transferSalveazaDestinatarulAgendaPlati,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
                  ),
                  activeColor: context.colors.brand,
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.surfaceMuted),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(Icons.schedule_rounded, color: context.colors.brand),
                      title: Text(
                        context.l10n.transferProgramarePlataRecurenta,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                      ),
                      initiallyExpanded: _isScheduled,
                      onExpansionChanged: (val) => setState(() => _isScheduled = val),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.transferFrecventaExecutie, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildFrequencyChip(context.l10n.transferData, 'ONCE'),
                                  const SizedBox(width: 8),
                                  _buildFrequencyChip(context.l10n.commonSaptamanal, 'WEEKLY'),
                                  const SizedBox(width: 8),
                                  _buildFrequencyChip(context.l10n.commonLunar, 'MONTHLY'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.transferDataExecutiei(formatDate(_scheduledDate)),
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
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
                                    child: Text(context.l10n.transferSchimbaData, style: GoogleFonts.inter(color: context.colors.brand, fontWeight: FontWeight.w600)),
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

                AppButton(
                  label: _isScheduled ? context.l10n.transferProgrameazaTransferul : context.l10n.transferTransferaAcum,
                  onPressed: _submitTransfer,
                  isLoading: _loading,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceAccount() {
    final c = context.colors;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: c.brand),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.commonContul, style: context.text.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    widget.userIban.isEmpty ? '—' : formatIban(widget.userIban),
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (widget.availableBalance != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.l10n.transferDisponibil2, style: context.text.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(widget.availableBalance!, widget.currency),
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
          ],
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
      selectedColor: context.colors.brand,
      backgroundColor: context.colors.surface,
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? context.colors.onBrand : context.colors.textPrimary,
      ),
    );
  }
}
