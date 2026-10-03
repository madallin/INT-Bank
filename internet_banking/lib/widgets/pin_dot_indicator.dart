import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

/// Filled/empty dots showing how many PIN digits have been entered.
class PinDotIndicator extends StatelessWidget {
  final int length;
  final int totalDots;

  const PinDotIndicator({
    super.key,
    required this.length,
    this.totalDots = 6,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: context.l10n.commonCifreIntroduse(length, totalDots),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalDots, (index) {
          final isFilled = index < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? c.brand : c.border,
            ),
          );
        }),
      ),
    );
  }
}
