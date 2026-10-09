import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/pin_dot_indicator.dart';
import '../../../widgets/pin_pad.dart';

/// A payment the bank asked the customer to confirm with their PIN (`SCA_REQUIRED`).
///
/// The details come from the server's challenge, so the customer approves exactly
/// what the bank will execute.
class ScaChallenge {
  const ScaChallenge({
    required this.challengeId,
    required this.amount,
    required this.currency,
    required this.toIban,
  });

  final String challengeId;
  final double amount;
  final String currency;
  final String toIban;

  /// Parses a `428 SCA_REQUIRED` response body; null for anything else.
  static ScaChallenge? fromResponse(Object? data) {
    if (data is! Map ||
        data['code'] != 'SCA_REQUIRED' ||
        data['challengeId'] is! String) {
      return null;
    }
    return ScaChallenge(
      challengeId: data['challengeId'] as String,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'RON',
      toIban: data['toIban']?.toString() ?? '',
    );
  }
}

/// Submits the PIN. Returns an error to show while keeping the sheet open
/// (e.g. wrong PIN), or null to close it.
typedef ScaPinSubmit = Future<String?> Function(String pin);

/// Asks for the PIN to authorize [challenge]. Resolves when the sheet closes.
Future<void> showScaPinSheet(
  BuildContext context, {
  required ScaChallenge challenge,
  required String beneficiaryName,
  required ScaPinSubmit onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ScaPinSheet(
      challenge: challenge,
      beneficiaryName: beneficiaryName,
      onSubmit: onSubmit,
    ),
  );
}

class ScaPinSheet extends StatefulWidget {
  const ScaPinSheet({
    super.key,
    required this.challenge,
    required this.beneficiaryName,
    required this.onSubmit,
  });

  static const int pinLength = 6;

  final ScaChallenge challenge;
  final String beneficiaryName;
  final ScaPinSubmit onSubmit;

  @override
  State<ScaPinSheet> createState() => _ScaPinSheetState();
}

class _ScaPinSheetState extends State<ScaPinSheet> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _onDigit(String digit) async {
    if (_busy || _pin.length >= ScaPinSheet.pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length < ScaPinSheet.pinLength) return;

    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedbackHelper.error();
    setState(() {
      _busy = false;
      _pin = '';
      _error = error;
    });
  }

  void _onDelete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final challenge = widget.challenge;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Icon(Icons.verified_user_outlined, color: c.brand, size: 32),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.scaTitle,
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.scaSubtitle,
                style: context.text.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      formatMoney(challenge.amount, challenge.currency),
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.beneficiaryName,
                      style: context.text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      formatIban(challenge.toIban),
                      style: context.text.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: l10n.scaPinProgress(_pin.length, ScaPinSheet.pinLength),
                child: PinDotIndicator(
                  length: _pin.length,
                  totalDots: ScaPinSheet.pinLength,
                ),
              ),
              SizedBox(
                height: 40,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _error == null
                      ? null
                      : Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: context.text.bodyMedium?.copyWith(
                              color: c.danger,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
              PinPad(
                onDigit: _onDigit,
                onDelete: _onDelete,
                enabled: !_busy,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.scaCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
