import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../data/models/card_model.dart';
import '../../../widgets/simple_app_bar.dart';

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
  bool _onlinePayments = true;
  bool _contactless = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isBlocked = widget.card.isBlocked;
    _spendingLimit = widget.card.spendingLimit > 0 ? widget.card.spendingLimit : 5000.0;
  }

  Future<void> _toggleFreeze(bool value) async {
    HapticFeedbackHelper.selection();
    setState(() => _saving = true);
    final endpoint = value ? 'freeze' : 'unfreeze';
    try {
      final response = await _client.put(
        '/users/${widget.userId}/cards/${widget.card.id}/$endpoint',
      );
      if (response.statusCode == 200) {
        setState(() => _isBlocked = value);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Cardul a fost blocat temporar' : 'Cardul a fost deblocat cu succes',
              style: GoogleFonts.inter(),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(lightForestGreenColor),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la modificarea stării cardului: $e', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
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
        data: {'spendingLimit': _spendingLimit},
      );
      if (response.statusCode == 200) {
        HapticFeedbackHelper.success();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Noua limită (${_spendingLimit.toStringAsFixed(0)} RON) a fost salvată cu succes!', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(lightForestGreenColor),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la salvarea limitei: $e', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: SimpleAppBar(
        title: 'Setări Card',
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
                      : [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
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
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isBlocked ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(_isBlocked ? Icons.lock_rounded : Icons.check_circle_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _isBlocked ? 'BLOCAT' : 'ACTIV',
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
                        'EXP: ${widget.card.expiryDate}',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('SECURITATE CARD', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: SwitchListTile(
                value: _isBlocked,
                onChanged: _saving ? null : _toggleFreeze,
                activeColor: Colors.red[700],
                title: Text('Blocare temporară card', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                subtitle: Text('Dezactivează plățile și retragerile ATM instant.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline_rounded, color: Colors.red[700], size: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('LIMITE TRANZACȚII', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Limită zilnică de cheltuieli', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                      Text('${_spendingLimit.toStringAsFixed(0)} RON', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(lightForestGreenColor))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _spendingLimit,
                    min: 500,
                    max: 20000,
                    divisions: 39,
                    activeColor: const Color(lightForestGreenColor),
                    inactiveColor: Colors.grey[200],
                    onChanged: (val) {
                      setState(() => _spendingLimit = val);
                    },
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveLimits,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(lightForestGreenColor),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Salvează noua limită', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Online & Contactless Switches
            Text('OPȚIUNI PLĂȚI', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _onlinePayments,
                    onChanged: (val) {
                      HapticFeedbackHelper.selection();
                      setState(() => _onlinePayments = val);
                    },
                    activeColor: const Color(lightForestGreenColor),
                    title: Text('Plăți online (e-Commerce)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                    subtitle: Text('Permite tranzacții securizate pe internet.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(lightForestGreenColor).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.language_rounded, color: Color(lightForestGreenColor), size: 20),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _contactless,
                    onChanged: (val) {
                      HapticFeedbackHelper.selection();
                      setState(() => _contactless = val);
                    },
                    activeColor: const Color(lightForestGreenColor),
                    title: Text('Plăți contactless POS', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                    subtitle: Text('Plăți rapide fără contact la magazine.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(lightForestGreenColor).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.contactless_outlined, color: Color(lightForestGreenColor), size: 20),
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
