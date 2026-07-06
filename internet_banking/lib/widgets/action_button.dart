import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';

enum ActionButtonVariant { primary, secondary }

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ActionButtonVariant variant;
  final bool isLoading;
  final bool isExpanded;

  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = ActionButtonVariant.primary,
    this.isLoading = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == ActionButtonVariant.primary;
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 50,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: [
                  const Color(lightForestGreenColor),
                  const Color(lightForestGreenColor).withOpacity(0.8),
                ],
              )
            : null,
        color: isPrimary ? null : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(lightForestGreenColor).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? Colors.white : const Color(darkGreyColor),
                    ),
                  ),
          ),
        ),
      ),
    );

    if (!isExpanded) return button;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: button,
      ),
    );
  }
}