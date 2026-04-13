// lib/levels/game_screen_lvl_1.dart
// Level 1 — 4×4 Solid Square — 12 Arrows

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_2.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl1 extends StatefulWidget {
  const GameScreenLvl1({super.key});
  @override
  State<GameScreenLvl1> createState() => _State();
}

class _State extends State<GameScreenLvl1> with BentLevelStateMixin<GameScreenLvl1> {
  @override int get levelNumber => 1;
  @override int get rows => Level1Manager.rows;
  @override int get cols => Level1Manager.cols;
  @override int get arrowCount => 10;
  @override List<BentArrowData> Function() get buildArrowsFn => Level1Manager.build;
  @override Widget Function() get nextLevelBuilder => () => const GameScreenLvl2();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level1Manager.cols,
      arrowCount: 10,
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
