import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/models/card_model.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../../l10n/l10n.dart';

class CardSettingsScreen extends StatefulWidget {
  final int userId;
  final CardModel card;

  const CardSettingsScreen({
    super.key,
    required this.userId,
    required this.card,
  });

  @override
  State<CardSettingsScreen> createState() => _CardSettingsScreenState();
}

class _CardSettingsScreenState extends State<CardSettingsScreen> {
  final DioClient _client = DioClient();
  late bool _isBlocked;
  late double _spendingLimit;
  late bool _onlinePayments;
  late bool _contactless;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isBlocked = widget.card.isBlocked;
    _spendingLimit = widget.card.spendingLimit > 0 ? widget.card.spendingLimit : 5000.0;
    _onlinePayments = widget.card.onlinePayments;
    _contactless = widget.card.contactless;
  }

  Future<void> _toggleFreeze(bool value) async {
    HapticFeedbackHelper.selection();
    // Blocking stops every card payment, so ask first; unblocking does not.
    if (value) {
      final confirmed = await showConfirmDialog(
        context,
        title: context.l10n.cardSettingsBlocheziTemporarCardul,
        message:
            context.l10n.cardSettingsPlatileCardulRetragerileAtm(widget.card.last4),
        confirmLabel: context.l10n.cardSettingsBlocheaza,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _saving = true);
    final endpoint = value ? 'freeze' : 'unfreeze';
    try {
      final response = await _client.put(
        '/users/${widget.userId}/cards/${widget.card.id}/$endpoint',
      );
      if (response.statusCode == 200) {
        // The server reports the card's persisted state; trust it over the request.
        final data = response.data;
        final blocked = data is Map && data['isBlocked'] is bool ? data['isBlocked'] as bool : value;
        setState(() => _isBlocked = blocked);
        if (!mounted) return;
        showSuccessSnackBar(context, value ? context.l10n.cardSettingsCardulFostBlocatTemporar : context.l10n.cardSettingsCardulFostDeblocatSucces);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, friendlyErrorMessage(e, fallback: context.l10n.cardSettingsStareaCarduluiPututFi));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLimits() async {
    HapticFeedbackHelper.selection();
    setState(() => _saving = true);
    try {
      final response = await _client.put(
        '/users/${widget.userId}/cards/${widget.card.id}/limits',
        data: {
          'spendingLimit': _spendingLimit,
          'onlinePayments': _onlinePayments,
          'contactless': _contactless,
        },
      );
      if (response.statusCode == 200) {
        HapticFeedbackHelper.success();
        if (!mounted) return;
        showSuccessSnackBar(context, context.l10n.cardSettingsNouaLimitaFostSalvata(formatMoney(_spendingLimit, 'RON', decimals: 0)));
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, friendlyErrorMessage(e, fallback: context.l10n.cardSettingsLimitaPututFiSalvata));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updatePaymentOption({bool? online, bool? contactless}) async {
    HapticFeedbackHelper.selection();
    final newOnline = online ?? _onlinePayments;
    final newContactless = contactless ?? _contactless;
    final previousOnline = _onlinePayments;
    final previousContactless = _contactless;
    setState(() {
      _onlinePayments = newOnline;
      _contactless = newContactless;
    });
    try {
      await _client.put(
        '/users/${widget.userId}/cards/${widget.card.id}/limits',
        data: {
          'spendingLimit': _spendingLimit,
          'onlinePayments': newOnline,
          'contactless': newContactless,
        },
      );
      HapticFeedbackHelper.buttonTap();
      if (!mounted) return;
      showAppSnackBar(context, context.l10n.cardSettingsOptiunilePlataAuFost,
          tone: SnackBarTone.success, duration: const Duration(seconds: 2));
    } catch (e) {
      if (!mounted) return;
      // Don't leave a switch showing a setting the bank did not save.
      setState(() {
        _onlinePayments = previousOnline;
        _contactless = previousContactless;
      });
      showErrorSnackBar(context, friendlyErrorMessage(e, fallback: context.l10n.cardSettingsOptiunileAuPututFi));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: SimpleAppBar(
        title: context.l10n.cardSettingsSetariCard,
        onBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Preview Mini Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isBlocked
                      ? [const Color(0xFF4A5568), const Color(0xFF2D3748)]
                      : [context.colors.heroStart, context.colors.heroEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INTBank Debit',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isBlocked ? context.colors.danger.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(_isBlocked ? Icons.lock_rounded : Icons.check_circle_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _isBlocked ? context.l10n.cardSettingsBlocat : context.l10n.cardSettingsActiv,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '•••• •••• •••• ${widget.card.cardNumber.length >= 4 ? widget.card.cardNumber.substring(widget.card.cardNumber.length - 4) : "****"}',
                    style: GoogleFonts.spaceMono(fontSize: 18, color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.card.cardHolder.toUpperCase(),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        context.l10n.cardSettingsExp(widget.card.expiryDate),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(context.l10n.cardSettingsSecuritateCard, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: SwitchListTile(
                value: _isBlocked,
                onChanged: _saving ? null : _toggleFreeze,
                activeColor: context.colors.danger,
                title: Text(context.l10n.cardSettingsBlocareTemporaraCard, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                subtitle: Text(context.l10n.cardSettingsDezactiveazaPlatileRetragerileAtm, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted)),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: context.colors.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline_rounded, color: context.colors.danger, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(context.l10n.cardSettingsLimiteTranzactii, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(context.l10n.cardSettingsLimitaZilnicaCheltuieli, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary))),
                      const SizedBox(width: 8),
                      Text(formatMoney(_spendingLimit, 'RON', decimals: 0), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.brand)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _spendingLimit,
                    min: 500,
                    max: 20000,
                    divisions: 39,
                    activeColor: context.colors.brand,
                    inactiveColor: context.colors.border,
                    onChanged: (val) {
                      setState(() => _spendingLimit = val);
                    },
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveLimits,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      foregroundColor: context.colors.onBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: _saving
                        ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: context.colors.onBrand, strokeWidth: 2))
                        : Text(context.l10n.cardSettingsSalveazaNouaLimita, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Online & Contactless Switches
            Text(context.l10n.cardSettingsOptiuniPlati, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _onlinePayments,
                    onChanged: (val) => _updatePaymentOption(online: val),
                    activeColor: context.colors.brand,
                    title: Text(context.l10n.cardSettingsPlatiOnlineECommerce, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                    subtitle: Text(context.l10n.cardSettingsPermiteTranzactiiSecurizateInternet, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted)),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: context.colors.brand.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.language_rounded, color: context.colors.brand, size: 20),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _contactless,
                    onChanged: (val) => _updatePaymentOption(contactless: val),
                    activeColor: context.colors.brand,
                    title: Text(context.l10n.cardSettingsPlatiContactlessPos, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                    subtitle: Text(context.l10n.cardSettingsPlatiRapideFaraContact, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted)),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: context.colors.brand.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.contactless_outlined, color: context.colors.brand, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
