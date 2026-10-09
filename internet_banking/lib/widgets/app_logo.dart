import 'package:flutter/material.dart';

/// INTBank logo; switches to the all-white artwork on dark backgrounds.
class AppLogo extends StatelessWidget
{
  const AppLogo({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context)
  {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'INTBank',
      image: true,
      child: Image.asset(
        isDark ? 'assets/images/logo_full_white.png' : 'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}
