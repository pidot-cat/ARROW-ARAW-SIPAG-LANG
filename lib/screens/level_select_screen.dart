// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/level_select_screen.dart
// Grid of level cards showing which stages are unlocked for the current user.
// Reads the highest unlocked level from [LevelUnlockService] and renders locked
// levels with a padlock icon so they cannot be tapped.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/level_select_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// CLEAN-LABELS: All shape-name labels (Heart, Circle, etc.) removed from
//   both locked and unlocked cards. Cards now show only: level number,
//   grid size, and difficulty badge — no shape text whatsoever.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/audio_service.dart';

import '../levels/game_screen_lvl_1.dart';
import '../levels/game_screen_lvl_2.dart';
import '../levels/game_screen_lvl_3.dart';
import '../levels/game_screen_lvl_4.dart';
import '../levels/game_screen_lvl_5.dart';
import '../levels/game_screen_lvl_6.dart';
import '../levels/game_screen_lvl_7.dart';
import '../levels/game_screen_lvl_8.dart';
import '../levels/game_screen_lvl_9.dart';
import '../levels/game_screen_lvl_10.dart';

import '../services/level_unlock_service.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _highestUnlocked = 1;
  int? _justUnlockedLevel;
  bool _loading = true;

  // ── Static metadata ───────────────────────────────────────────────────────

  // Grid size label for each level (shape names intentionally removed).
  static const List<String> _levelGrids = [
    '8×8', '10×10', '11×11', '12×12', '13×13',
    '14×14', '15×15', '16×16', '17×17', '18×18',
  ];

  // Accent colour for each level card.
  static const List<Color> _levelColors = [
    Color(0xFF1E88E5), Color(0xFF00C853), Color(0xFFFFD600), Color(0xFFFFD600),
    Color(0xFFFF6D00), Color(0xFFFF6D00), Color(0xFFD50000), Color(0xFFD50000),
    Color(0xFFAA00FF), Color(0xFFAA00FF),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUnlockState();
  }

  Future<void> _loadUnlockState() async {
    final level = await LevelUnlockService.instance.loadHighestUnlocked();
    if (!mounted) return;
    setState(() {
      _highestUnlocked = level;
      _loading = false;
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  Widget _levelScreen(int level) {
    switch (level) {
      case 1:  return const GameScreenLvl1();
      case 2:  return const GameScreenLvl2();
      case 3:  return const GameScreenLvl3();
      case 4:  return const GameScreenLvl4();
      case 5:  return const GameScreenLvl5();
      case 6:  return const GameScreenLvl6();
      case 7:  return const GameScreenLvl7();
      case 8:  return const GameScreenLvl8();
      case 9:  return const GameScreenLvl9();
      case 10: return const GameScreenLvl10();
      default: return const GameScreenLvl1();
    }
  }

  Future<void> _openLevel(int level) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _levelScreen(level)),
    );
    if (!mounted) return;
    final previous = _highestUnlocked;
    final updated = await LevelUnlockService.instance.loadHighestUnlocked();
    if (!mounted) return;
    setState(() {
      _highestUnlocked = updated;
      if (updated > previous) _justUnlockedLevel = updated;
    });
    if (_justUnlockedLevel != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justUnlockedLevel = null);
      });
    }
  }

  String _getDifficulty(int level) {
    if (level <= 2) return 'Easy';
    if (level <= 4) return 'Normal';
    if (level <= 6) return 'Hard';
    if (level <= 8) return 'Expert';
    return 'Master';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text(
          'SELECT LEVEL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A1628),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // Use resumeMenuMusic() instead of stopAll() so lobby music
            // transitions seamlessly. stopAll() cleared _currentMusic which
            // caused a brief silence before HomeScreen re-triggered playback.
            AudioService().resumeMenuMusic();
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withAlpha(30)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1628), Color(0xFF1A1A2E)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: size.width > 600 ? 4 : 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: 10,
                  itemBuilder: (ctx, i) => _buildCard(ctx, i + 1),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(BuildContext context, int level) {
    final color = _levelColors[level - 1];
    final unlocked = level <= _highestUnlocked;
    final justUnlocked = level == _justUnlockedLevel;

    if (!unlocked) return _lockedCard(level);

    Widget card = _unlockedCard(context, level, color, justUnlocked);

    if (justUnlocked) {
      card = card
          .animate()
          .scale(
            begin: const Offset(0.75, 0.75),
            end: const Offset(1.0, 1.0),
            duration: 700.ms,
            curve: Curves.elasticOut,
          )
          .shimmer(duration: 900.ms, color: color.withAlpha(200));
    }
    return card;
  }

  // CLEAN-LABELS: No shape name text. Shows only lock icon + level number.
  Widget _lockedCard(int level) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white24, size: 34),
          const SizedBox(height: 6),
          const Text('LVL',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          Text('$level',
              style: const TextStyle(
                  fontSize: 34,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                  height: 1.0)),
          // No shape label — clean grid
        ],
      ),
    );
  }

  // CLEAN-LABELS: No shape name text. Shows level number, grid size, difficulty.
  Widget _unlockedCard(
      BuildContext context, int level, Color color, bool highlighted) {
    return InkWell(
      onTap: () => _openLevel(level),
      borderRadius: BorderRadius.circular(18),
      splashColor: color.withAlpha(60),
      highlightColor: color.withAlpha(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? color.withAlpha(230) : color.withAlpha(160),
            width: highlighted ? 2.5 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(highlighted ? 160 : 80),
              blurRadius: highlighted ? 22 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('LVL',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(120),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            Text('$level',
                style: TextStyle(
                    fontSize: 38,
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                    shadows: [
                      Shadow(color: color.withAlpha(180), blurRadius: 12)
                    ])),
            const SizedBox(height: 4),
            // Grid size only — no shape name label
            Text(_levelGrids[level - 1],
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(140),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withAlpha(80), width: 1),
              ),
              child: Text(_getDifficulty(level),
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
