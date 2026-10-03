import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../l10n/l10n.dart';

/// Segmented progress bar for multi-step flows (0-based [currentStep]).
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: context.l10n.commonPasul(currentStep + 1, totalSteps),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
        child: Row(
          children: List.generate(totalSteps, (index) {
            final isActive = index <= currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isActive ? c.brand : c.border,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
