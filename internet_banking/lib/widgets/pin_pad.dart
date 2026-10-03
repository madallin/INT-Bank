import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/haptic_feedback_helper.dart';
import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

/// Numeric keypad shared by PIN entry and SMS-code verification.
///
/// Also accepts digits and Backspace from a hardware keyboard.
class PinPad extends StatelessWidget
{
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.enabled = true,
    this.bottomLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// While false (e.g. during verification) keys ignore input.
  final bool enabled;

  /// Optional key in the empty bottom-left slot (e.g. biometric unlock).
  final Widget? bottomLeft;
  final EdgeInsets padding;

  static const double keySize = 64;

  KeyEventResult _onKey(FocusNode node, KeyEvent event)
  {
    if(!enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if(key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete)
    {
      onDelete();
      return KeyEventResult.handled;
    }
    final char = event.character;
    if(char != null && RegExp(r'^\d$').hasMatch(char))
    {
      onDigit(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context)
  {
    Widget digit(String d) => _PinKey(
          semanticLabel: context.l10n.commonCifra(d),
          enabled: enabled,
          onTap: () {
            HapticFeedbackHelper.buttonTap();
            onDigit(d);
          },
          child: Text(
            d,
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        );

    Widget row(List<Widget> keys) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys,
        );

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for(final r in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']]) ...[
                row(r.map(digit).toList()),
                const SizedBox(height: AppSpacing.sm),
              ],
              row([
                SizedBox(
                  width: keySize,
                  height: keySize,
                  child: bottomLeft,
                ),
                digit('0'),
                _PinKey(
                  semanticLabel: context.l10n.commonStergeUltimaCifra,
                  enabled: enabled,
                  onTap: () {
                    HapticFeedbackHelper.selection();
                    onDelete();
                  },
                  child: Icon(Icons.backspace_outlined, color: context.colors.textPrimary),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget
{
  const _PinKey({
    required this.semanticLabel,
    required this.onTap,
    required this.enabled,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: PinPad.keySize,
        height: PinPad.keySize,
        child: Material(
          color: c.surface,
          shape: CircleBorder(side: BorderSide(color: c.border, width: 1.5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
