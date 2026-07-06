import 'package:flutter/material.dart';

import '../config/app_config.dart';

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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(lightForestGreenColor),
            Color(darkForestGreenColor),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(lightForestGreenColor).withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: Colors.white,
      ),
    );
  }
}