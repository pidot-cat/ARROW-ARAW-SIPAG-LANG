// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/records_screen.dart
// Displays the player's cumulative statistics (wins, losses, win-rate, days
// played) loaded from Supabase via [SupabaseService.getGameStats()].
// Uses a FutureBuilder so the screen renders a shimmer/loading state while the
// async fetch is in progress.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/records_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Records Screen — displays the player's lifetime game statistics fetched
// from GameProvider: wins, losses, total matches, days active, and win rate.
//
// Uses Consumer<GameProvider> so the stats update reactively whenever the
// provider calls notifyListeners() (e.g. after completing a level).
// refreshStats() is called once in initState() to force a fresh Supabase
// pull the moment the screen opens.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/background_wrapper.dart';
import '../providers/game_provider.dart';
import '../utils/app_colors.dart';
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.03),
                  Image.asset(AppConstants.logoWithBg, width: 140, height: 140),
                  const SizedBox(height: 10),
                  const Text(
                    'Records',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                  SizedBox(height: size.height * 0.02),

                  // ── Compact stat rows (each capped at 60dp tall) ──────────
                  _compactStat('Wins',    '${stats.totalWins}',    Colors.greenAccent,  Icons.emoji_events_rounded),
                  const SizedBox(height: 8),
                  _compactStat('Losses',  '${stats.totalLosses}',  Colors.redAccent,    Icons.close_rounded),
                  const SizedBox(height: 8),
                  _compactStat('Matches', '${stats.totalMatches}', Colors.cyanAccent,   Icons.sports_esports_rounded),
                  const SizedBox(height: 8),
                  _compactStat('Days Active', '${stats.totalDays}', Colors.orangeAccent, Icons.calendar_today_rounded),
                  const SizedBox(height: 12),

                  // ── Win Rate — gradient accent card ───────────────────────
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 60),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.cyan.withAlpha(60),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.bar_chart_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Win Rate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                        // Win rate formatted to one decimal place
                        Text(
                          '${winRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds a compact stat row constrained to a maximum height of 60dp.
  ///
  /// [label] — Human-readable stat name (e.g. "Wins").
  /// [value] — Numeric value to display on the right (e.g. "42").
  /// [color] — Accent colour for the icon badge and value text.
  /// [icon]  — Material icon shown in the leading badge.
  Widget _compactStat(String label, String value, Color color, IconData icon) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 60),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(70), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withAlpha(40),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Coloured icon badge
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            // Stat value — larger and accented for quick scanning
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
