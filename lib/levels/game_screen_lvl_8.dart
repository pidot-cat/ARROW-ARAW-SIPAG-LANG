// lib/levels/game_screen_lvl_8.dart
// Level 8 — Solid Square — Level8Manager

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_9.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl8 extends StatefulWidget {
  const GameScreenLvl8({super.key});
  @override
  State<GameScreenLvl8> createState() => _State();
}

class _State extends State<GameScreenLvl8> with BentLevelStateMixin<GameScreenLvl8> {
  @override int get levelNumber => 8;
  @override int get rows => Level8Manager.rows;
  @override int get cols => Level8Manager.cols;
  @override int get arrowCount => 80;
  @override List<BentArrowData> Function() get buildArrowsFn => Level8Manager.build;
  @override Widget Function() get nextLevelBuilder =>
      () => const GameScreenLvl9();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level8Manager.cols,
      arrowCount: 80,
    );
    final shape = _allCells(rows, cols);
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(children: [
        SafeArea(child: Column(children: [
          buildHUD(),
          const SizedBox(height: 4),
          Text('Solid Square · $rows×$cols · ${80} Arrows',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Expanded(child: Center(child: buildGrid(cellSize, shape))),
        ])),
        if (gameOver) GameOverOverlay(onRetry: restart, onBack: quit),
        if (victory) VictoryOverlay(isLastLevel: false, onNext: goNextLevel, onBack: quit),
      ]),
    );
  }
}
