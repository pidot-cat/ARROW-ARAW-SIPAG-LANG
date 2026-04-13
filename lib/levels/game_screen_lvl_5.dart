// lib/levels/game_screen_lvl_5.dart
// Level 5 — Solid Square — Level5Manager

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_6.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl5 extends StatefulWidget {
  const GameScreenLvl5({super.key});
  @override
  State<GameScreenLvl5> createState() => _State();
}

class _State extends State<GameScreenLvl5> with BentLevelStateMixin<GameScreenLvl5> {
  @override int get levelNumber => 5;
  @override int get rows => Level5Manager.rows;
  @override int get cols => Level5Manager.cols;
  @override int get arrowCount => 50;
  @override List<BentArrowData> Function() get buildArrowsFn => Level5Manager.build;
  @override Widget Function() get nextLevelBuilder =>
      () => const GameScreenLvl6();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level5Manager.cols,
      arrowCount: 50,
    );
    final shape = _allCells(rows, cols);
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(children: [
        SafeArea(child: Column(children: [
          buildHUD(),
          const SizedBox(height: 4),
          Text('Solid Square · $rows×$cols · ${50} Arrows',
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
