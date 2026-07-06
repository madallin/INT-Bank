import 'package:flutter/material.dart';

import '../config/app_config.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalDots, (index) {
        final isFilled = index < length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? const Color(lightForestGreenColor)
                : Colors.grey[300],
          ),
        );
      }),
    );
  }
}