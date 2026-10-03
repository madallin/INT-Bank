import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Decorative brand-gradient circle with an icon, used on onboarding screens.
class CircularIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const CircularIconBadge({
    super.key,
    required this.icon,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroStart, c.heroEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: c.brand.withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.48, color: Colors.white),
      ),
    );
  }
}
