// lib/levels/game_screen_lvl_9.dart
// Level 9 — Solid Square — Level9Manager

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'level_base.dart';
import 'level_manager.dart';
import 'game_screen_lvl_10.dart';

Set<(int, int)> _allCells(int rows, int cols) {
  final s = <(int, int)>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      s.add((r, c));
    }
  }
  return s;
}

class GameScreenLvl9 extends StatefulWidget {
  const GameScreenLvl9({super.key});
  @override
  State<GameScreenLvl9> createState() => _State();
}

class _State extends State<GameScreenLvl9> with BentLevelStateMixin<GameScreenLvl9> {
  @override int get levelNumber => 9;
  @override int get rows => Level9Manager.rows;
  @override int get cols => Level9Manager.cols;
  @override int get arrowCount => 90;
  @override List<BentArrowData> Function() get buildArrowsFn => Level9Manager.build;
  @override Widget Function() get nextLevelBuilder =>
      () => const GameScreenLvl10();

  @override
  void initState() { super.initState(); initLevelState(); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = dynamicCellSize(
      screenWidth: screenWidth,
      cols: Level9Manager.cols,
      arrowCount: 90,
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
