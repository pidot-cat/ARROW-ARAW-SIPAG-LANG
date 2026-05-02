// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/gradient_button.dart
// Reusable full-width call-to-action button with a gradient fill and drop shadow.
//
// Accepts two gradient variants via the [isPrimary] flag:
//   true  (default) — AppColors.primaryGradient  (blue/cyan family)
//   false           — AppColors.secondaryGradient (alternate accent)
//
// The button uses Material + InkWell instead of ElevatedButton so the ink
// ripple respects the rounded border without clipping artifacts.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double height;
  final bool isPrimary;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height = 55,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient:
            isPrimary ? AppColors.primaryGradient : AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? AppColors.primaryDark : AppColors.secondaryDark)
                .withAlpha((0.5 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
