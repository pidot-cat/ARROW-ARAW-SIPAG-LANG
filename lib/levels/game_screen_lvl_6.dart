// lib/levels/game_screen_lvl_6.dart
// Level 6 — Solid Square — Level6Manager

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_7.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl6 extends StatefulWidget {
  const GameScreenLvl6({super.key});
  @override
  State<GameScreenLvl6> createState() => _State();
}

class _State extends State<GameScreenLvl6> with BentLevelStateMixin<GameScreenLvl6> {
  @override int get levelNumber => 6;
  @override int get rows => Level6Manager.rows;
  @override int get cols => Level6Manager.cols;
  @override int get arrowCount => 60;
  @override List<BentArrowData> Function() get buildArrowsFn => Level6Manager.build;
  @override Widget Function() get nextLevelBuilder =>
      () => const GameScreenLvl7();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level6Manager.cols,
      arrowCount: 60,
    );
    final shape = _allCells(rows, cols);
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(children: [
        SafeArea(child: Column(children: [
          buildHUD(),
          const SizedBox(height: 4),
          Expanded(child: Center(child: buildGrid(cellSize, shape))),
        ])),
        if (gameOver) GameOverOverlay(onRetry: restart, onBack: quit),
        if (victory) VictoryOverlay(isLastLevel: false, onNext: goNextLevel, onBack: quit),
      ]),
    );
  }
}
