// lib/levels/game_screen_lvl_4.dart
// Level 4 — Solid Square — Level4Manager

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_5.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl4 extends StatefulWidget {
  const GameScreenLvl4({super.key});
  @override
  State<GameScreenLvl4> createState() => _State();
}

class _State extends State<GameScreenLvl4> with BentLevelStateMixin<GameScreenLvl4> {
  @override int get levelNumber => 4;
  @override int get rows => Level4Manager.rows;
  @override int get cols => Level4Manager.cols;
  @override int get arrowCount => 40;
  @override List<BentArrowData> Function() get buildArrowsFn => Level4Manager.build;
  @override Widget Function() get nextLevelBuilder =>
      () => const GameScreenLvl5();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level4Manager.cols,
      arrowCount: 40,
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
