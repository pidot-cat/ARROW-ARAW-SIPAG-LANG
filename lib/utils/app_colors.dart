// lib/utils/app_colors.dart
// Central color palette and gradient definitions for the entire app.
//
// PURPOSE:
//   Keeping all colors in one place makes it easy to:
//     • maintain visual consistency across every screen
//     • swap the theme in one file without hunting through widgets
//
// USAGE:
//   import '../utils/app_colors.dart';
//   color: AppColors.cyan          // a named color constant
//   gradient: AppColors.secondaryGradient  // the silver-grey input-field gradient

import 'package:flutter/material.dart';

class AppColors {
  // ── Primary gradient — deep blue → dark grey ─────────────────────────────
  // Used by buttons (GradientButton) and the main app background accent.
  static const Color primaryDark = Color(0xFF271E9A); // deep indigo-blue
  static const Color primaryGrey = Color(0xFF212125); // near-black grey
  static const Color primary     = Color(0xFF271E9A); // alias for primaryDark

  // ── Secondary gradient — silver grey ─────────────────────────────────────
  // Used by ALL input fields (GradientInputField) so Email, Password, and
  // Confirm Password share the SAME visual treatment — fixing the
  // "blue password boxes" bug reported in the sign-up screen.
  static const Color secondaryLight = Color(0xFFA2A2A3); // light silver
  static const Color secondaryDark  = Color(0xFF3D3D3D); // dark charcoal

  // ── App background and surface tones ─────────────────────────────────────
  static const Color backgroundDark = Color(0xFF1A1A1D);
  static const Color surface        = Color(0xFF2C2C2E);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textWhite = Colors.white;
  static const Color textGrey  = Color(0xFFB0B0B0); // hint text, icons

  // ── Arrow tile colors — vibrant palette used on the game grid ─────────────
  static const Color cyan   = Color(0xFF00E5FF);
  static const Color orange = Color(0xFFFF6D00);
  static const Color green  = Color(0xFF00FF41);
  static const Color purple = Color(0xFFD500F9);
  static const Color red    = Color(0xFFFF1744);
  static const Color yellow = Color(0xFFFFEA00);
  static const Color pink   = Color(0xFFFF4081);
  static const Color white  = Colors.white;

  // List form — iterated by the game engine to assign tile colors
  static const List<Color> arrowColors = [
    cyan, orange, green, purple, red, yellow, pink, white,
  ];

  // Named aliases used by individual level screens for readability
  static const Color arrowRed    = red;
  static const Color arrowOrange = orange;
  static const Color arrowYellow = yellow;
  static const Color arrowGreen  = green;
  static const Color arrowCyan   = cyan;
  static const Color arrowBlue   = Color(0xFF2979FF);
  static const Color arrowPurple = purple;
  static const Color arrowPink   = pink;
  static const Color arrowWhite  = white;

  // ── UI element colors ─────────────────────────────────────────────────────
  static const Color darkNavy     = Color(0xFF0D1B2A); // dialog backgrounds
  static const Color heartRed     = Color(0xFFFF1744);
  static const Color heartBlack   = Color(0xFF2C2C2C);
  static const Color obstacleGrey = Color(0xFF4A4A4A);

  // ── Helper: replace deprecated withOpacity() ─────────────────────────────
  // withOpacity() is deprecated in Flutter ≥3.x; withAlpha() is the
  // recommended replacement.  This static helper makes call sites readable:
  //   AppColors.alpha(AppColors.secondaryLight, 0.9)
  static Color alpha(Color color, double opacity) =>
      color.withAlpha((opacity * 255).toInt());

  // ── Gradient definitions ─────────────────────────────────────────────────

  // primaryGradient — deep blue → dark grey, used for buttons and accents
  static LinearGradient primaryGradient = const LinearGradient(
    colors: [primaryDark, primaryGrey],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // secondaryGradient — silver grey, used for ALL text input fields.
  // Applying this gradient to GradientInputField ensures that the Password
  // and Confirm Password fields look identical to the Email field.
  static LinearGradient secondaryGradient = LinearGradient(
    colors: [
      alpha(secondaryLight, 0.9), // slightly transparent light silver
      alpha(secondaryDark,  0.9), // slightly transparent dark charcoal
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
