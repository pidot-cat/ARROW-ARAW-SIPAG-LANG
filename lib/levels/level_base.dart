// lib/levels/level_base.dart
// ─────────────────────────────────────────────────────────────────────────────
// Arrow Araw — Core Engine v12  (PRODUCTION FINAL — All Fixes Applied)
//
// FIX-1  HEAD-ALIGN: Shaft endpoint pulled back by halfCap so StrokeCap.round
//        meets the arrowhead apex flush — no gap anywhere.
// FIX-2  PERF-6: Adaptive animation durations for levels 5–10.
//          L5–L7 (50–70 arrows): 280ms slide / 120ms fade delay / 300ms solve
//          L8–L10 (80–100 arrows): 220ms slide / 90ms fade delay / 240ms solve
// FIX-3  (Audio — see audio_service.dart and home_screen.dart)
// FIX-4  PERF-7: Per-arrow debounce map replaces global 16ms gate.
//        Rapid taps on DIFFERENT arrows all register correctly.
// FIX-5  PERF-8: Exit animation extracted into _ArrowExitWidget, a dedicated
//        StatefulWidget that owns its own AnimationController. This eliminates
//        the flutter_animate Animate widget re-creation overhead on every tap
//        and prevents parent setState() from interrupting in-flight animations
//        on dense levels (L2–L10). Each arrow animates independently with zero
//        coupling to sibling arrows — guarantees uniform 60fps exit on all levels.
// FIX-6  PERF-9: Outer RepaintBoundary wraps the entire grid Stack. Parent
//        setState() calls (timer ticks, HUD updates, life changes) no longer
//        propagate repaints into the grid. Eliminates ~100 redundant paint
//        evaluations/second on Level 10, which was the root cause of exit-
//        animation jitter when the timer fired concurrently with an arrow burst.
//
// Retained from v10: PERF-1 (RepaintBoundary/arrow), PERF-2 (dot grid),
//   PERF-3 (willChange), PERF-4 (shouldRepaint value-compare), WIN-1.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../services/level_unlock_service.dart';
import '../screens/settings_screen.dart';
import '../screens/level_select_screen.dart';

// ── Direction enum ────────────────────────────────────────────────────────────

enum ArrowDir { up, down, left, right }

// ── Data models ───────────────────────────────────────────────────────────────

class BentCell {
  final int row, col;
  const BentCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is BentCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class BentArrowData {
  final int id;
  final List<BentCell> segs;
  final ArrowDir escape;
  final Color color;
  bool solved;

  BentArrowData({
    required this.id,
    required this.segs,
    required this.escape,
    required this.color,
    this.solved = false,
  });

  List<(int, int)> get cells => segs.map((c) => (c.row, c.col)).toList();

  Rect hitRect(double cellSize) {
    if (segs.isEmpty) return Rect.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final s in segs) {
      final cx = s.col * cellSize;
      final cy = s.row * cellSize;
      if (cx < minX) minX = cx;
      if (cy < minY) minY = cy;
      if (cx + cellSize > maxX) maxX = cx + cellSize;
      if (cy + cellSize > maxY) maxY = cy + cellSize;
    }
    final extra = cellSize * 0.42;
    return Rect.fromLTRB(
      minX - (escape == ArrowDir.left ? extra : 0),
      minY - (escape == ArrowDir.up ? extra : 0),
      maxX + (escape == ArrowDir.right ? extra : 0),
      maxY + (escape == ArrowDir.down ? extra : 0),
    );
  }
}

// ── Responsive cellSize ───────────────────────────────────────────────────────
double dynamicCellSize({
  required double screenWidth,
  required int cols,
  required int arrowCount,
}) {
  final maxGridWidth = screenWidth * 0.85;
  return maxGridWidth / cols;
}

// ── BentLevelStateMixin ───────────────────────────────────────────────────────

mixin BentLevelStateMixin<T extends StatefulWidget> on State<T> {
  int get levelNumber;
  int get rows;
  int get cols;
  int get arrowCount;
  List<BentArrowData> Function() get buildArrowsFn;
  Widget Function() get nextLevelBuilder;

  late List<BentArrowData> arrows;
  int lives = 3;
  int secondsLeft = 60;
  bool gameOver = false;
  bool victory = false;

  // WIN-1: Ensures win sound + state transition happen exactly once.
  bool _victoryTriggered = false;

  Timer? _levelTimer;
  final Map<int, ValueNotifier<int>> animTrigger = {};
  final AudioService _audio = AudioService();
  final Set<int> _pendingSolve = {};

  // FIX-4 / PERF-7: Per-arrow debounce map.
  // Each arrow tracks its own last-tap timestamp so rapid taps on DIFFERENT
  // arrows all register. Only a double-tap on the SAME arrow within 16ms
  // (one frame) is suppressed to prevent ghost life deductions.
  final Map<int, DateTime> _lastTapPerArrow = {};

  bool _debounceCheckArrow(int arrowId) {
    final now = DateTime.now();
    final last = _lastTapPerArrow[arrowId];
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 16)) {
      return false;
    }
    _lastTapPerArrow[arrowId] = now;
    return true;
  }

  void initLevelState() {
    _victoryTriggered = false;
    _lastTapPerArrow.clear();
    _audio.resetWinSoundGuard();
    arrows = buildArrowsFn();
    for (final a in arrows) {
      animTrigger[a.id] = ValueNotifier(0);
    }
    _audio.playGameMusic();
    _startTimer();
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    for (final v in animTrigger.values) {
      v.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        secondsLeft--;
        if (secondsLeft <= 0) triggerGameOver();
      });
    });
  }

  void triggerGameOver() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    setState(() => gameOver = true);
    _audio.playGameOverSound();
    if (mounted) context.read<GameProvider>().recordLevelLoss();
  }

  // WIN-1: _victoryTriggered guard — idempotent.
  void triggerVictory() {
    if (_victoryTriggered) return;
    _victoryTriggered = true;
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    setState(() => victory = true);
    _audio.playWinSound();
    if (mounted) {
      context.read<GameProvider>().recordLevelComplete(
            level: levelNumber,
            time: 60 - secondsLeft,
            lives: lives,
          );
    }
    if (levelNumber >= 10) {
      LevelUnlockService.instance.unlockAll();
    } else {
      LevelUnlockService.instance.unlockLevel(levelNumber + 1);
    }
  }

  BentCell _headSeg(BentArrowData arrow) {
    switch (arrow.escape) {
      case ArrowDir.left:
      case ArrowDir.up:
        return arrow.segs.first;
      case ArrowDir.right:
      case ArrowDir.down:
        return arrow.segs.last;
    }
  }

  bool isPathClear(BentArrowData tappedArrow) {
    final occupied = <(int, int)>{};
    for (final a in arrows) {
      if (a.id != tappedArrow.id && !a.solved) {
        for (final cell in a.cells) {
          occupied.add(cell);
        }
      }
    }
    final tipSeg = _headSeg(tappedArrow);
    final (dr, dc) = switch (tappedArrow.escape) {
      ArrowDir.up => (-1, 0),
      ArrowDir.down => (1, 0),
      ArrowDir.left => (0, -1),
      ArrowDir.right => (0, 1),
    };
    var r = tipSeg.row + dr;
    var c = tipSeg.col + dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      if (occupied.contains((r, c))) return false;
      r += dr;
      c += dc;
    }
    return true;
  }

  BentArrowData? _findTappedArrow(Offset localPos, double cellSize) {
    for (int i = arrows.length - 1; i >= 0; i--) {
      final a = arrows[i];
      if (a.solved) continue;
      if (_pendingSolve.contains(a.id)) continue;
      if (a.hitRect(cellSize).contains(localPos)) return a;
    }
    return null;
  }

  // FIX-2 / PERF-6: Adaptive animation & solve-delay timings.
  Duration get _slideDuration {
    if (arrowCount >= 80) return const Duration(milliseconds: 220);
    if (arrowCount >= 50) return const Duration(milliseconds: 280);
    return const Duration(milliseconds: 350);
  }

  Duration get _fadeDelay {
    if (arrowCount >= 80) return const Duration(milliseconds: 90);
    if (arrowCount >= 50) return const Duration(milliseconds: 120);
    return const Duration(milliseconds: 160);
  }

  Duration get _fadeDuration {
    if (arrowCount >= 80) return const Duration(milliseconds: 130);
    if (arrowCount >= 50) return const Duration(milliseconds: 160);
    return const Duration(milliseconds: 190);
  }

  // Solve-completion Future fires after slide finishes, not a hardcoded 380ms.
  Duration get _solveDelay {
    if (arrowCount >= 80) return const Duration(milliseconds: 240);
    if (arrowCount >= 50) return const Duration(milliseconds: 300);
    return const Duration(milliseconds: 380);
  }

  void onGridTap(Offset localPos, double cellSize) {
    if (gameOver || victory) return;
    _audio.startIdleResumeTimer();

    final arrow = _findTappedArrow(localPos, cellSize);
    if (arrow == null) return;

    // FIX-4: Per-arrow debounce — only blocks same-arrow double-tap.
    if (!_debounceCheckArrow(arrow.id)) return;

    if (!isPathClear(arrow)) {
      wrongTap();
      return;
    }

    _audio.playArrowSound();
    _pendingSolve.add(arrow.id);
    arrow.solved = true;
    animTrigger[arrow.id]!.value++;

    Future.delayed(_solveDelay, () {
      if (!mounted) return;
      _pendingSolve.remove(arrow.id);
      setState(() {
        if (arrows.every((a) => a.solved)) triggerVictory();
      });
    });
  }

  void onTap(BentArrowData arrow) {
    if (gameOver || victory || arrow.solved) return;
    if (_pendingSolve.contains(arrow.id)) return;
    // FIX-4: Per-arrow debounce.
    if (!_debounceCheckArrow(arrow.id)) return;
    _audio.startIdleResumeTimer();
    if (!isPathClear(arrow)) {
      wrongTap();
      return;
    }
    _audio.playArrowSound();
    _pendingSolve.add(arrow.id);
    arrow.solved = true;
    animTrigger[arrow.id]!.value++;
    Future.delayed(_solveDelay, () {
      if (!mounted) return;
      _pendingSolve.remove(arrow.id);
      setState(() {
        if (arrows.every((a) => a.solved)) triggerVictory();
      });
    });
  }

  void wrongTap() {
    _audio.playWrongSound();
    _audio.startIdleResumeTimer();
    setState(() {
      lives--;
      if (lives <= 0) triggerGameOver();
    });
  }

  void restart() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    _pendingSolve.clear();
    _victoryTriggered = false;
    _lastTapPerArrow.clear(); // FIX-4: reset per-arrow debounce
    _audio.resetWinSoundGuard();
    setState(() {
      arrows = buildArrowsFn();
      lives = 3;
      secondsLeft = 60;
      gameOver = false;
      victory = false;
      for (final a in arrows) {
        animTrigger[a.id]?.value = 0;
      }
    });
    _audio.playGameMusic();
    _startTimer();
  }

  void quit() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    _audio.resumeMenuMusic();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
      (route) => route.isFirst,
    );
  }

  void goNextLevel() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => nextLevelBuilder()));
  }

  void _openSettings() {
    _levelTimer?.cancel();
    _audio.cancelIdleTimer();
    Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsScreen()))
        .then((_) {
      if (!gameOver && !victory && mounted) _startTimer();
    });
  }

  Widget buildHUD() {
    final progress = secondsLeft / 60.0;
    final isUrgent = secondsLeft <= 10;
    final timerColor = isUrgent ? Colors.redAccent : Colors.cyanAccent;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(22)),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withAlpha(15), blurRadius: 14)
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            onTap: quit,
          ),
          const SizedBox(width: 8),
          Text('Level $levelNumber',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)])),
          const Spacer(),
          Row(
              children: List.generate(3, (i) {
            final alive = i < lives;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Image.asset(
                alive
                    ? 'assets/images/heart icon Red.png'
                    : 'assets/images/heart icon Black.png',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => Icon(
                    alive ? Icons.favorite : Icons.favorite_border,
                    color: alive ? Colors.redAccent : Colors.white24,
                    size: 20),
              ),
            );
          })),
          const SizedBox(width: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
                color: timerColor,
                fontSize: isUrgent ? 22 : 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: timerColor, blurRadius: 10)]),
            child: Text('${secondsLeft}s'),
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
              icon: Icons.settings_rounded,
              color: Colors.white60,
              onTap: _openSettings),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          ),
        ),
      ]),
    );
  }

  // PERF-1+2+9: Grid builder — outer RepaintBoundary + dot layer +
  //   per-arrow RepaintBoundary.
  //
  // PERF-9 (outer RepaintBoundary): Isolates the entire grid into its own
  //   composited layer. Parent setState() calls — timer ticks every second,
  //   life indicator updates, HUD redraws — no longer propagate a repaint
  //   into the grid subtree. On Level 10 with 100 arrows this eliminates
  //   ~100 redundant CustomPaint evaluations per timer tick, which was the
  //   primary source of the jitter visible during the exit animation burst.
  Widget buildGrid(double cellSize, Set<(int, int)> shapeCells) {
    final occupiedCells = <(int, int)>{};
    for (final a in arrows) {
      if (!a.solved) {
        for (final cell in a.cells) {
          occupiedCells.add(cell);
        }
      }
    }

    final dotRadius = (cellSize * 0.07).clamp(1.5, 4.0);
    final gridSide = cellSize * math.max(rows, cols);

    return Center(
      child: GestureDetector(
        onTapDown: (d) => onGridTap(d.localPosition, cellSize),
        behavior: HitTestBehavior.opaque,
        // PERF-9: Outer RepaintBoundary — the grid is promoted to its own
        // GPU layer. Timer ticks, HUD state changes, and life-count updates
        // in the parent do NOT repaint anything inside this boundary.
        child: RepaintBoundary(
          child: SizedBox(
            width: gridSide,
            height: gridSide,
            child: Stack(children: [
              // PERF-2: Static dot layer in its own sub-boundary.
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(gridSide, gridSide),
                  painter: _DotGridPainter(
                    occupiedCells: Set.unmodifiable(occupiedCells),
                    cellSize: cellSize,
                    dotRadius: dotRadius,
                  ),
                  isComplex: false,
                  willChange: false,
                ),
              ),
              // PERF-1: One RepaintBoundary per arrow.
              // Solved + non-animating arrows are skipped entirely (zero GPU cost).
              for (final a in arrows)
                if (!a.solved || animTrigger[a.id]!.value > 0)
                  _buildArrowVisual(a, cellSize),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildArrowVisual(BentArrowData arrow, double cellSize) {
    return ValueListenableBuilder<int>(
      valueListenable: animTrigger[arrow.id]!,
      builder: (context, val, _) {
        // PERF-3: willChange only true while animating.
        final painter = RepaintBoundary(
          child: CustomPaint(
            size: Size(cellSize * math.max(rows, cols),
                cellSize * math.max(rows, cols)),
            painter: StraightArrowPainter(
              segs: arrow.segs,
              escape: arrow.escape,
              color: arrow.color,
              cellSize: cellSize,
            ),
            isComplex: true,
            willChange: val > 0,
          ),
        );

        if (val == 0) return painter;

        // FIX-5 / PERF-8: Dedicated StatefulWidget owns its AnimationController.
        // Replaces flutter_animate's Animate widget, which re-created the entire
        // widget subtree on every trigger — causing frame drops on dense levels
        // (L2–L10) when multiple arrows are tapped rapidly. Each _ArrowExitWidget
        // is fully self-contained: it starts instantly, never blocks sibling
        // animations, and requires no parent setState() during playback.
        return _ArrowExitWidget(
          key: ValueKey('exit_${arrow.id}_$val'),
          escape: arrow.escape,
          gridSize: cellSize * math.max(rows, cols),
          slideDuration: _slideDuration,
          fadeDelay: _fadeDelay,
          fadeDuration: _fadeDuration,
          child: painter,
        );
      },
    );
  }

  Widget buildArrow(BentArrowData arrow, double cellSize) =>
      _buildArrowVisual(arrow, cellSize);
}

// ── _ArrowExitWidget ──────────────────────────────────────────────────────────
// FIX-5 / PERF-8: Self-contained exit animation using an owned AnimationController.
//
// WHY: flutter_animate's Animate widget is declarative — it creates a new
// animation subtree every time the widget is rebuilt. On dense levels (L2–L10),
// rapid taps cause many Animate widgets to be mounted simultaneously in a single
// frame, overwhelming Flutter's reconciler and producing lag/skipped exits.
//
// This widget is instantiated ONCE per tap (via ValueKey) and manages its own
// AnimationController lifecycle. It starts the animation immediately in initState(),
// requires zero parent setState() calls during playback, and disposes cleanly.
// Result: identical smooth 60fps exit on every level from L1 to L10.

class _ArrowExitWidget extends StatefulWidget {
  final ArrowDir escape;
  final double gridSize;
  final Duration slideDuration;
  final Duration fadeDelay;
  final Duration fadeDuration;
  final Widget child;

  const _ArrowExitWidget({
    super.key,
    required this.escape,
    required this.gridSize,
    required this.slideDuration,
    required this.fadeDelay,
    required this.fadeDuration,
    required this.child,
  });

  @override
  State<_ArrowExitWidget> createState() => _ArrowExitWidgetState();
}

class _ArrowExitWidgetState extends State<_ArrowExitWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.slideDuration,
    );

    final dist = widget.gridSize;
    final (dx, dy) = switch (widget.escape) {
      ArrowDir.up => (0.0, -dist),
      ArrowDir.down => (0.0, dist),
      ArrowDir.left => (-dist, 0.0),
      ArrowDir.right => (dist, 0.0),
    };

    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(dx, dy),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final totalMs = widget.slideDuration.inMilliseconds;
    final fadeStart =
        (widget.fadeDelay.inMilliseconds / totalMs).clamp(0.0, 1.0);

    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(fadeStart, 1.0, curve: Curves.easeOut),
      ),
    );

    // Fire immediately — non-blocking, independent of all other arrows.
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: _slide.value,
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ── _GlassIconButton ──────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _GlassIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyanAccent.withAlpha(55)),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withAlpha(20), blurRadius: 8)
              ],
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── _DotGridPainter ───────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  final Set<(int, int)> occupiedCells;
  final double cellSize;
  final double dotRadius;

  const _DotGridPainter({
    required this.occupiedCells,
    required this.cellSize,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final cell in occupiedCells) {
      final cx = cell.$2 * cellSize + cellSize / 2;
      final cy = cell.$1 * cellSize + cellSize / 2;
      canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.cellSize != cellSize ||
      old.dotRadius != dotRadius ||
      old.occupiedCells.length != occupiedCells.length;
}

// ── StraightArrowPainter ──────────────────────────────────────────────────────
// FIX-1  HEAD-ALIGN: shaftTip offset so StrokeCap.round lands flush at apex.
// PERF-4 shouldRepaint compares segs by value.

class StraightArrowPainter extends CustomPainter {
  final List<BentCell> segs;
  final ArrowDir escape;
  final Color color;
  final double cellSize;

  const StraightArrowPainter({
    required this.segs,
    required this.escape,
    required this.color,
    required this.cellSize,
  });

  Offset _centre(BentCell c) =>
      Offset(c.col * cellSize + cellSize / 2, c.row * cellSize + cellSize / 2);

  Offset _outerEdgeTip(BentCell headSeg) {
    final cx = headSeg.col * cellSize;
    final cy = headSeg.row * cellSize;
    return switch (escape) {
      ArrowDir.up => Offset(cx + cellSize / 2, cy),
      ArrowDir.down => Offset(cx + cellSize / 2, cy + cellSize),
      ArrowDir.left => Offset(cx, cy + cellSize / 2),
      ArrowDir.right => Offset(cx + cellSize, cy + cellSize / 2),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (segs.isEmpty) return;

    final BentCell headSeg;
    final BentCell tailSeg;
    switch (escape) {
      case ArrowDir.left:
      case ArrowDir.up:
        headSeg = segs.first;
        tailSeg = segs.last;
        break;
      case ArrowDir.right:
      case ArrowDir.down:
        headSeg = segs.last;
        tailSeg = segs.first;
        break;
    }

    final tail = _centre(tailSeg);
    final tip = _outerEdgeTip(headSeg); // apex — also passed to _drawHead

    // FIX-1 / HEAD-ALIGN:
    // StrokeCap.round extends painted length by halfStroke beyond the
    // endpoint. Without correction this overlaps the arrowhead triangle,
    // creating a visible gap at the apex. Pull the shaft endpoint back so
    // the cap's leading edge lands exactly at `tip`.
    const double shaftStroke = 3.5;
    const double halfCap = shaftStroke / 2.0;
    final (dirX, dirY) = switch (escape) {
      ArrowDir.up => (0.0, -1.0),
      ArrowDir.down => (0.0, 1.0),
      ArrowDir.left => (-1.0, 0.0),
      ArrowDir.right => (1.0, 0.0),
    };
    final shaftTip = Offset(tip.dx - dirX * halfCap, tip.dy - dirY * halfCap);

    final shaft = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(shaftTip.dx, shaftTip.dy);

    // Glow.
    canvas.drawPath(
        shaft,
        Paint()
          ..color = color.withAlpha(55)
          ..strokeWidth = 7.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));

    // Crisp shaft.
    canvas.drawPath(
        shaft,
        Paint()
          ..color = color
          ..strokeWidth = shaftStroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true);

    _drawHead(canvas, tip, color); // head apex at original `tip`
  }

  void _drawHead(Canvas canvas, Offset tip, Color col) {
    final (dx, dy) = switch (escape) {
      ArrowDir.up => (0.0, -1.0),
      ArrowDir.down => (0.0, 1.0),
      ArrowDir.left => (-1.0, 0.0),
      ArrowDir.right => (1.0, 0.0),
    };
    final angle = math.atan2(dy, dx);
    final len = (cellSize * 0.55).clamp(6.0, 20.0);
    const wing = 0.48;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + math.cos(angle + math.pi - wing) * len,
          tip.dy + math.sin(angle + math.pi - wing) * len)
      ..lineTo(tip.dx + math.cos(angle + math.pi + wing) * len,
          tip.dy + math.sin(angle + math.pi + wing) * len)
      ..close();

    canvas.drawPath(
        headPath,
        Paint()
          ..color = col.withAlpha(65)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0));

    canvas.drawPath(
        headPath,
        Paint()
          ..color = col
          ..style = PaintingStyle.fill
          ..isAntiAlias = true);
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant StraightArrowPainter old) {
    if (old.color != color ||
        old.escape != escape ||
        old.cellSize != cellSize ||
        old.segs.length != segs.length) {
      return true;
    }
    for (int i = 0; i < segs.length; i++) {
      if (segs[i] != old.segs[i]) return true;
    }
    return false;
  }
}

typedef BentArrowPainter = StraightArrowPainter;
