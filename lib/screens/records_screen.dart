// lib/screens/records_screen.dart

// Displays the player's cumulative statistics (wins, losses, win-rate, days
// played) loaded from Supabase via [SupabaseService.getGameStats()].

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/background_wrapper.dart';
import '../providers/game_provider.dart';
import '../utils/constants.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh stats from Supabase on screen open.
    // addPostFrameCallback ensures the context is fully mounted before
    // reading the provider — avoids calling read() during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().refreshStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BackgroundWrapper(
        showBackButton: true,
        child: Consumer<GameProvider>(
          // Rebuild only this subtree when GameProvider notifies listeners
          builder: (context, gp, _) {
            final stats = gp.stats;

            // Calculate win rate as a percentage; guard against division by zero
            final winRate = stats.totalMatches > 0
                ? (stats.totalWins / stats.totalMatches * 100)
                : 0.0;
            final winRateFraction = winRate / 100.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.05),

                    // ── Logo ──────────────────────────────────────────────────
                    Image.asset(AppConstants.logoWithBg,
                        width: 110, height: 110),
                    const SizedBox(height: 8),

                    // ── Title ─────────────────────────────────────────────────
                    const Text(
                      'Records',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                    SizedBox(height: size.height * 0.03),

                    // ── 2-column grid for the first 4 metrics ─────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.35,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _glassCard(
                          label: 'Wins',
                          subLabel: 'Stats',
                          value: '${stats.totalWins}',
                          icon: Icons.emoji_events_rounded,
                          iconBgColor: const Color(0xFF1E7D34),
                        ),
                        _glassCard(
                          label: 'Losses',
                          subLabel: 'Stats',
                          value: '${stats.totalLosses}',
                          icon: Icons.close_rounded,
                          iconBgColor: const Color(0xFF9B1C1C),
                        ),
                        _glassCard(
                          label: 'Matches',
                          subLabel: 'Stats',
                          value: '${stats.totalMatches}',
                          icon: Icons.sports_esports_rounded,
                          iconBgColor: const Color(0xFF1A4E8A),
                        ),
                        _glassCard(
                          label: 'Days Active',
                          subLabel: 'Stats',
                          value: '${stats.totalDays}',
                          icon: Icons.calendar_today_rounded,
                          iconBgColor: const Color(0xFF944E00),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Win Rate — full-width card with progress bar ───────────
                    _winRateCard(
                      winRate: winRate,
                      winRateFraction: winRateFraction,
                    ),

                    SizedBox(height: size.height * 0.04),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Glassmorphism metric card used in the 2-column grid.
  ///
  /// [label]       — Metric name shown in bold white (e.g. "Wins").
  /// [subLabel]    — Muted grey sub-label under the title (e.g. "Stats").
  /// [value]       — Numeric value displayed in large bold white text.
  /// [icon]        — Material icon inside the coloured icon container.
  /// [iconBgColor] — Solid background colour for the icon container.
  Widget _glassCard({
    required String label,
    required String subLabel,
    required String value,
    required IconData icon,
    required Color iconBgColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withAlpha(26),
                Colors.white.withAlpha(10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withAlpha(35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon container (top-left)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),

              // Label + sub-label + value
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-width Win Rate card with glassmorphism styling and a progress bar.
  ///
  /// [winRate]         — Percentage value as a double (e.g. 25.0).
  /// [winRateFraction] — Progress fraction 0.0–1.0 for the LinearProgressIndicator.
  Widget _winRateCard({
    required double winRate,
    required double winRateFraction,
  }) {
    const Color barColor = Color(0xFF3D5AFE); // indigo accent
    const Color iconBg = Color(0xFF1A237E); // deep indigo container

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withAlpha(28),
                Colors.white.withAlpha(10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withAlpha(35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + label/sub-label + value
              Row(
                children: [
                  // Icon container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Label + sub-label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Win Rate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Stats',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Value — win rate percentage
                  Text(
                    '${winRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar track
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: winRateFraction.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withAlpha(30),
                  valueColor: const AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
