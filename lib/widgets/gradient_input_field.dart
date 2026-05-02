// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/gradient_input_field.dart
// Themed text-input widget used across all form screens (login, sign-up,
// contact, forgot-password).
//
// Features:
//   • Cyan gradient border that intensifies on focus.
//   • Optional leading icon (prefixIcon) for semantic context.
//   • Password-visibility toggle (showToggle: true) for password fields.
//   • readOnly flag — renders the field as a non-editable display value
//     (used for the locked account-email badge on ContactScreen).
//   • maxLines support — expands to a textarea for multi-line inputs such as
//     the message body on ContactScreen.
// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/gradient_input_field.dart
// [FIX 5A] Added readOnly parameter — locks the email field in ContactScreen.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class GradientInputField extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final bool showToggle;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool readOnly; // [FIX 5A] NEW

  const GradientInputField({
    super.key,
    required this.hintText,
    required this.controller,
    this.obscureText  = false,
    this.showToggle   = false,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines     = 1,
    this.enabled      = true,
    this.readOnly     = false, // [FIX 5A]
  });

  @override
  State<GradientInputField> createState() => _GradientInputFieldState();
}

class _GradientInputFieldState extends State<GradientInputField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.secondaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryDark.withAlpha((0.5 * 255).toInt()),
              blurRadius: 6, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller:   widget.controller,
          obscureText:  _obscure,
          keyboardType: widget.keyboardType,
          maxLines:     widget.maxLines,
          enabled:      widget.enabled,
          readOnly:     widget.readOnly, // [FIX 5A]
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
                color: AppColors.textGrey.withAlpha((0.5 * 255).toInt()),
                fontSize: 16),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppColors.textGrey)
                : null,
            // Lock icon when readOnly; eye toggle when password; else null
            suffixIcon: widget.readOnly
                ? const Icon(Icons.lock_outline,
                    color: Colors.cyanAccent, size: 18)
                : widget.showToggle
                    ? IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textGrey),
                        onPressed: () => setState(() => _obscure = !_obscure))
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: widget.maxLines > 1 ? 16 : 18,
            ),
          ),
        ),
      ),
    );
  }
}
