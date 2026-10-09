import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/helpers.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/pin_dot_indicator.dart';
import '../../../widgets/pin_pad.dart';
import '../../../widgets/simple_app_bar.dart';

enum _Step { current, choose, confirm }

/// Current PIN, new PIN, new PIN again. The bank checks the current PIN (and its lockout)
/// before it accepts the new one.
class ChangePinScreen extends StatefulWidget
{
  const ChangePinScreen({super.key, required this.userId});

  final int userId;

  static const pinLength = 6;

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
{
  _Step _step = _Step.current;
  String _current = '';
  String _new = '';
  String _entry = '';
  String _error = '';
  bool _saving = false;

  void _onDigit(String digit)
  {
    if(_saving || _entry.length >= ChangePinScreen.pinLength) return;
    setState(() { _entry += digit; _error = ''; });
    if(_entry.length == ChangePinScreen.pinLength) _completeStep();
  }

  void _onDelete()
  {
    if(_saving || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _completeStep()
  {
    final entry = _entry;
    switch(_step)
    {
      case _Step.current:
        setState(() { _current = entry; _entry = ''; _step = _Step.choose; });
      case _Step.choose:
        if(entry == _current)
        {
          _fail(context.l10n.changePinSameAsOld, restartAt: _Step.choose);
          return;
        }
        setState(() { _new = entry; _entry = ''; _step = _Step.confirm; });
      case _Step.confirm:
        if(entry != _new)
        {
          _fail(context.l10n.pinPinUrileCoincid, restartAt: _Step.choose);
          return;
        }
        _save();
    }
  }

  void _fail(String message, {required _Step restartAt})
  {
    HapticFeedbackHelper.error();
    setState(() {
      _error = message;
      _entry = '';
      _step = restartAt;
      if(restartAt == _Step.current) _current = '';
      _new = '';
    });
  }

  Future<void> _save() async
  {
    setState(() => _saving = true);
    try
    {
      await DioClient().put(
        '/users/${widget.userId}/set-pin',
        data: {'codPin': _new, 'currentPin': _current},
      );
      if(!mounted) return;
      HapticFeedbackHelper.success();
      showSuccessSnackBar(context, context.l10n.changePinDone);
      Navigator.of(context).pop(true);
    }
    on DioException catch(e)
    {
      if(!mounted) return;
      // A wrong current PIN (or a lockout) sends the customer back to the first step.
      final code = e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
      final wrongCurrent = code == 'SCA_PIN_INVALID' || code == 'SCA_LOCKED';
      _fail(
        friendlyErrorMessage(e, fallback: context.l10n.changePinFailed),
        restartAt: wrongCurrent ? _Step.current : _Step.choose,
      );
    }
    finally
    {
      if(mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    final (title, body) = switch(_step)
    {
      _Step.current => (l10n.changePinCurrentTitle, l10n.changePinCurrentBody),
      _Step.choose => (l10n.changePinNewTitle, l10n.changePinNewBody),
      _Step.confirm => (l10n.changePinConfirmTitle, l10n.changePinConfirmBody),
    };
    return Scaffold(
      backgroundColor: c.surface,
      appBar: SimpleAppBar(title: l10n.settingsChangePin),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.changePinStep(_step.index + 1),
                      style: context.text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: Text(
                        body,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PinDotIndicator(length: _entry.length, totalDots: ChangePinScreen.pinLength),
                    if(_error.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                        child: ErrorBanner(message: _error),
                      ),
                    ],
                    if(_saving) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const CircularProgressIndicator(),
                    ],
                    const Spacer(),
                    PinPad(onDigit: _onDigit, onDelete: _onDelete, enabled: !_saving),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
