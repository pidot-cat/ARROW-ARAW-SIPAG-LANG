// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/life_indicator.dart
// Displays the player's remaining lives as a horizontal row of heart icons.
//
// Renders [maxLives] hearts side-by-side; hearts at index < [currentLives]
// use the red (active) asset, and the remaining hearts use the black (lost)
// asset.  The widget is stateless — the parent rebuilds it whenever
// [currentLives] changes via a ChangeNotifier or setState call.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LifeIndicator extends StatelessWidget {
  final int currentLives;
  final int maxLives;

  const LifeIndicator({
    super.key,
    required this.currentLives,
    this.maxLives = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (index) {
        bool isActive = index < currentLives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Image.asset(
            isActive ? AppConstants.heartRed : AppConstants.heartBlack,
            width: 32,
            height: 32,
          ),
        );
      }),
    );
  }
}
