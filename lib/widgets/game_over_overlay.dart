// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/game_over_overlay.dart
// Semi-transparent overlay that covers the game grid when the player loses all
// lives.  Displays the 'Game Over' image and action buttons (Retry, Home).
//
// Rendered inside a Stack in each level screen so it appears above the grid
// without triggering a full navigation push.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';

class GameOverOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const GameOverOverlay({
    super.key,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(160),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AppConstants.gameOver,
                width: screenWidth * 0.7,
                height: screenHeight * 0.25,
                fit: BoxFit.contain,
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Game Over!',
                style: TextStyle(
                  fontSize: screenWidth * 0.08,
                  color: AppColors.red,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppColors.red.withAlpha(150),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'Try again to clear the path!',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.white.withAlpha(160),
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'RETRY',
                  style: TextStyle(
                    fontSize: screenWidth * 0.048,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.1,
                    vertical: screenHeight * 0.018,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.04),
                  ),
                  elevation: 8,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              TextButton.icon(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_ios_new,
                    color: Colors.white.withAlpha(180),
                    size: screenWidth * 0.04),
                label: Text(
                  'BACK',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}