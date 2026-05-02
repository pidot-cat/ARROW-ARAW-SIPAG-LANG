// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/game_screen.dart
// Core gameplay screen for the legacy single-level entry point.
// Renders the arrow grid using [GameProvider] state and handles tap input to
// redirect arrows.  Victory and Game Over overlays are shown as Stack children
// rather than full-screen navigation pushes to avoid rebuild flicker.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/game_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Game Screen — the classic (non-level-base) game screen used by GameProvider.
// Renders the game grid, top-bar HUD, animated timer bar, settings overlay,
// GameOver overlay, and Victory overlay.
//
// This screen reads its state entirely from GameProvider via Consumer<>.
// Audio is managed locally via the AudioService singleton.
//
// NOTE: The newer level-based game flow (Levels 1–10) uses LevelBase instead.
//       This screen is kept for the /game route (legacy entry point).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/arrow_model.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/victory_overlay.dart';
import '../widgets/life_indicator.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();

  // Controller for a generic pulse animation (reserved for future effects)
  late AnimationController _pulseController;

  // Whether the slide-down settings panel is currently visible
  bool _showSettingsOverlay = false;

  // Controllers and animations for the settings panel slide + fade
  late AnimationController _settingsController;
  late Animation<Offset> _settingsSlide;
  late Animation<double> _settingsFade;

  @override
  void initState() {
    super.initState();

    // Pulse animation — 800ms loop, used for any HUD pulsing effects
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Settings panel slide-in from top — 260ms ease
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    // Panel slides from above the screen (Offset(0,-1)) to its resting position
    _settingsSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _settingsController, curve: Curves.easeInOut),
    );

    // Panel fades in alongside the slide
    _settingsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _settingsController, curve: Curves.easeInOut),
    );

    // Start game music after the first frame is rendered so the
    // audio service isn't called before the widget tree is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioService.playGameMusic();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  /// Toggles the settings overlay panel open or closed.
  void _toggleSettingsOverlay() {
    setState(() => _showSettingsOverlay = !_showSettingsOverlay);
    if (_showSettingsOverlay) {
      _settingsController.forward();
    } else {
      _settingsController.reverse();
    }
  }

  /// Returns a human-readable difficulty label based on the current level.
  String _getDifficultyText(int level) {
    if (level <= 2) return 'Easy';
    if (level <= 4) return 'Normal';
    if (level <= 6) return 'Hard';
    if (level <= 8) return 'Expert';
    return 'Master';
  }

  /// Returns the colour associated with a given difficulty tier.
  Color _getDifficultyColor(int level) {
    if (level <= 2) return Colors.greenAccent;
    if (level <= 4) return Colors.yellowAccent;
    if (level <= 6) return Colors.orangeAccent;
    if (level <= 8) return Colors.redAccent;
    return AppColors.purple;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // PopScope prevents the system back button from immediately exiting;
    // instead it shows a confirmation dialog so progress isn't lost by accident.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Leave Game?',
                style: TextStyle(color: Colors.white)),
            content: const Text('Your progress in this level will be lost.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay', style: TextStyle(color: Colors.cyan)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          _audioService.stopGameMusic();
          Navigator.pop(context);
        }
      },
      child: Consumer<GameProvider>(
        builder: (context, game, child) {
          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: Container(
              // Subtle background image overlay at 15% opacity
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppConstants.background),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // ── Main game layout ──────────────────────────────────
                    Column(
                      children: [
                        _buildTopBar(context, game, size),
                        _buildTimerBar(game, size),
                        Expanded(
                          child: Center(
                            child: _buildGameGrid(game, size),
                          ),
                        ),
                        _buildBottomHint(size),
                      ],
                    ),

                    // ── Settings overlay (slide-down panel + scrim) ───────
                    if (_showSettingsOverlay) ...[
                      // Tap-to-dismiss scrim behind the panel
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _toggleSettingsOverlay,
                          child: FadeTransition(
                            opacity: _settingsFade,
                            child:
                                Container(color: Colors.black.withAlpha(120)),
                          ),
                        ),
                      ),
                      // The settings panel itself, slides in from the top
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SlideTransition(
                          position: _settingsSlide,
                          child: _buildSettingsPanel(size),
                        ),
                      ),
                    ],

                    // ── Game Over overlay ─────────────────────────────────
                    if (game.isGameOver)
                      GameOverOverlay(
                        onRetry: () {
                          _audioService.playGameMusic();
                          game.initLevel(game.currentLevel);
                        },
                        onBack: () {
                          _audioService.stopGameMusic();
                          Navigator.pop(context);
                        },
                      ),

                    // ── Victory overlay ───────────────────────────────────
                    if (game.isLevelWon)
                      VictoryOverlay(
                        isLastLevel: game.currentLevel >= 10,
                        onNext: () {
                          _audioService.playGameMusic();
                          game.nextLevel();
                        },
                        onBack: () {
                          _audioService.stopGameMusic();
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HUD: Top bar ───────────────────────────────────────────────────────────

  /// Builds the top HUD row: back button | level info + lives | settings button.
  Widget _buildTopBar(BuildContext context, GameProvider game, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.03, vertical: 8),
      child: Row(
        children: [
          // Back button — shows leave-game confirmation dialog before popping
          _buildIconBtn(
            icon: Icons.arrow_back_ios_new,
            onTap: () async {
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: const Text('Leave Game?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'Your progress in this level will be lost.',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Stay',
                          style: TextStyle(color: Colors.cyan)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Leave',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (shouldLeave == true && context.mounted) {
                _audioService.stopGameMusic();
                Navigator.pop(context);
              }
            },
            size: size,
          ),

          // Centre column: level number + difficulty badge + life hearts
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LEVEL ${game.currentLevel}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Colour-coded difficulty badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(game.currentLevel)
                            .withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getDifficultyColor(game.currentLevel),
                            width: 1),
                      ),
                      child: Text(
                        _getDifficultyText(game.currentLevel),
                        style: TextStyle(
                          color: _getDifficultyColor(game.currentLevel),
                          fontSize: size.width * 0.025,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Heart life indicators
                LifeIndicator(currentLives: game.lives),
              ],
            ),
          ),

          // Settings button — opens the slide-down audio settings panel
          _buildIconBtn(
            icon: Icons.settings,
            onTap: _toggleSettingsOverlay,
            size: size,
            highlighted: _showSettingsOverlay,
          ),
        ],
      ),
    );
  }

  // ── Settings panel ─────────────────────────────────────────────────────────

  /// Builds the slide-down settings panel with music and SFX toggles.
  Widget _buildSettingsPanel(Size size) {
    return Container(
      margin: EdgeInsets.fromLTRB(size.width * 0.06, 8, size.width * 0.06, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(140),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SETTINGS',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.8)),
              GestureDetector(
                onTap: _toggleSettingsOverlay,
                child: Icon(Icons.close,
                    color: Colors.white.withAlpha(160), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Music toggle — toggleMusic() is async (pause/resume, not stop/restart)
          _buildAnimatedToggle(
            label: 'Music',
            icon: Icons.music_note_rounded,
            value: _audioService.isMusicOn,
            onChanged: (_) async {
              await _audioService.toggleMusic();
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          // SFX toggle
          _buildAnimatedToggle(
            label: 'Sound FX',
            icon: Icons.volume_up_rounded,
            value: _audioService.isSfxOn,
            onChanged: (_) => setState(() => _audioService.toggleSfx()),
          ),
        ],
      ),
    );
  }

  /// Builds an animated ON/OFF toggle row used inside the settings panel.
  ///
  /// The thumb slides from left to right and changes colour when toggled.
  /// [label]     — Text label next to the icon.
  /// [icon]      — Leading icon.
  /// [value]     — Current on/off state.
  /// [onChanged] — Callback invoked with the NEW value when tapped.
  Widget _buildAnimatedToggle({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const dur = Duration(milliseconds: 260);
    const curve = Curves.easeInOut;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: dur,
            curve: curve,
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: value
                  ? AppColors.cyan.withAlpha(180)
                  : Colors.white.withAlpha(40),
              border: Border.all(
                  color: value ? AppColors.cyan : Colors.white.withAlpha(60),
                  width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedAlign(
                  duration: dur,
                  curve: curve,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          value ? AppColors.cyan : Colors.white.withAlpha(200),
                      boxShadow: [
                        BoxShadow(
                            color: value
                                ? AppColors.cyan.withAlpha(130)
                                : Colors.black.withAlpha(60),
                            blurRadius: 4)
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: dur,
                        child: Text(
                          value ? 'ON' : 'OFF',
                          key: ValueKey(value),
                          style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: value
                                  ? Colors.black.withAlpha(180)
                                  : Colors.white.withAlpha(180)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a square icon button used for the back and settings buttons in the HUD.
  ///
  /// [icon]        — Icon to display.
  /// [onTap]       — Callback when tapped.
  /// [size]        — Screen size used for proportional sizing.
  /// [highlighted] — When true, applies a cyan accent (used for settings when open).
  Widget _buildIconBtn(
      {required IconData icon,
      required VoidCallback onTap,
      required Size size,
      bool highlighted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size.width * 0.1,
        height: size.width * 0.1,
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.cyan.withAlpha(40)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlighted
                  ? AppColors.cyan.withAlpha(180)
                  : Colors.white.withAlpha(40)),
        ),
        child: Icon(icon,
            color: highlighted ? AppColors.cyan : Colors.white,
            size: size.width * 0.055),
      ),
    );
  }

  // ── HUD: Timer bar ─────────────────────────────────────────────────────────

  /// Builds the countdown timer display: numeric seconds + colour-shifting
  /// progress bar that turns orange at 20s and red at 10s.
  Widget _buildTimerBar(GameProvider game, Size size) {
    // Timer colour changes with urgency: cyan → orange → red
    final double progress = game.timeLeft / 60.0;
    final Color timerColor = game.timeLeft > 20
        ? AppColors.cyan
        : game.timeLeft > 10
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, color: timerColor, size: size.width * 0.04),
              const SizedBox(width: 4),
              // Text size pulses up when time is critical (≤10s)
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                    color: timerColor,
                    fontSize: game.timeLeft <= 10
                        ? size.width * 0.06
                        : size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto'),
                child: Text('${game.timeLeft}s'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Animated progress bar — shrinks smoothly over 500ms
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Game grid ──────────────────────────────────────────────────────────────

  /// Builds the square game grid container and places all active arrow widgets.
  ///
  /// Cell size is derived from the screen width minus horizontal padding so
  /// the grid is always square and fills the available width.
  Widget _buildGameGrid(GameProvider game, Size size) {
    final double padding = size.width * 0.04;
    final double gridPixels = size.width - (padding * 2);
    final double cellSize = gridPixels / game.gridSize;

    return Container(
      width: gridPixels,
      height: gridPixels,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          // Only render arrows that haven't been removed (isRemoved == false)
          children: game.arrows
              .where((a) => !a.isRemoved)
              .map((arrow) => _buildArrowWidget(arrow, cellSize, size))
              .toList(),
        ),
      ),
    );
  }

  /// Wraps a single ArrowModel in an _AnimatedArrow widget, computing the
  /// off-screen escape target based on the arrow's direction.
  ///
  /// The escape target drives the fly-out animation when the arrow is tapped.
  Widget _buildArrowWidget(ArrowModel arrow, double cellSize, Size size) {
    Offset escapeTarget;
    switch (arrow.direction) {
      case ArrowDirection.up:
        escapeTarget = Offset(0, -(size.height));
        break;
      case ArrowDirection.down:
        escapeTarget = Offset(0, size.height);
        break;
      case ArrowDirection.left:
        escapeTarget = Offset(-size.width, 0);
        break;
      case ArrowDirection.right:
        escapeTarget = Offset(size.width, 0);
        break;
      case ArrowDirection.white:
        escapeTarget = Offset.zero;
        break;
    }

    return _AnimatedArrow(
      // Key encodes all segment coordinates + direction so Flutter can
      // correctly identify and animate this specific arrow
      key: ValueKey(arrow.segments.map((s) => '${s.x},${s.y}').join('|') +
          arrow.direction.toString()),
      arrow: arrow,
      cellSize: cellSize,
      escapeTarget: escapeTarget,
      onTap: () => context.read<GameProvider>().tapArrow(arrow),
    );
  }

  // ── Bottom hint ────────────────────────────────────────────────────────────

  /// Static hint text at the bottom of the screen reminding the player what to do.
  Widget _buildBottomHint(Size size) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'TAP ARROWS TO CLEAR THE PATH',
        style: TextStyle(
            fontSize: size.width * 0.032,
            color: Colors.white.withAlpha(80),
            letterSpacing: 1.5),
      ),
    );
  }
}

// ── _AnimatedArrow ─────────────────────────────────────────────────────────
// Stateful widget that handles the tap-scale animation and the fly-out
// escape animation for a single arrow on the game grid.

class _AnimatedArrow extends StatefulWidget {
  final ArrowModel arrow;
  final double cellSize;
  final Offset escapeTarget; // Off-screen destination when the arrow is cleared
  final VoidCallback onTap;

  const _AnimatedArrow(
      {super.key,
      required this.arrow,
      required this.cellSize,
      required this.escapeTarget,
      required this.onTap});

  @override
  State<_AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<_AnimatedArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Scale compresses the arrow slightly on tap-down for tactile feedback
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrow = widget.arrow;

    // Compute the bounding box of all segments so we know where to position
    // the Positioned widget and how large to make its canvas
    int minX = arrow.segments.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    int minY = arrow.segments.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    int maxX = arrow.segments.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    int maxY = arrow.segments.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    double width  = (maxX - minX + 1) * widget.cellSize;
    double height = (maxY - minY + 1) * widget.cellSize;
    double left   = minX * widget.cellSize;
    double top    = minY * widget.cellSize;

    // When the arrow is escaping (cleared), animate it flying off-screen
    if (arrow.isEscaping) {
      return TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: widget.escapeTarget),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
        builder: (context, offsetVal, child) {
          return Positioned(
            left: left + offsetVal.dx,
            top: top + offsetVal.dy,
            width: width,
            height: height,
            child: Opacity(
              // Fade out as it moves further from its origin
              opacity: (1.0 -
                      (offsetVal.distance / (widget.escapeTarget.distance + 1)))
                  .clamp(0.0, 1.0),
              child: _arrowBody(arrow, width, height, minX, minY),
            ),
          );
        },
      );
    }

    // Normal (non-escaping) state: tappable with scale-down feedback
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: _arrowBody(arrow, width, height, minX, minY),
        ),
      ),
    );
  }

  /// Delegates rendering to LongArrowPainter via a CustomPaint widget.
  Widget _arrowBody(
      ArrowModel arrow, double width, double height, int minX, int minY) {
    return CustomPaint(
      size: Size(width, height),
      painter: LongArrowPainter(
        segments: arrow.segments,
        direction: arrow.direction,
        color: arrow.color,
        cellSize: widget.cellSize,
        minX: minX,
        minY: minY,
        sizeFactor: arrow.size,
      ),
    );
  }
}

// ── LongArrowPainter ─────────────────────────────────────────────────────────
// CustomPainter that draws a multi-segment arrow as a thick rounded stroke
// plus an arrowhead triangle at the head segment.

class LongArrowPainter extends CustomPainter {
  final List<ArrowSegment> segments;
  final ArrowDirection direction;
  final Color color;
  final double cellSize;
  final int minX; // Bounding box minimum X — used to localise segment coords
  final int minY; // Bounding box minimum Y
  final double sizeFactor; // Scale multiplier from ArrowModel.size

  LongArrowPainter({
    required this.segments,
    required this.direction,
    required this.color,
    required this.cellSize,
    required this.minX,
    required this.minY,
    required this.sizeFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Stroke paint for the arrow body line
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.25 * sizeFactor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Connect all segment centres with a polyline path
    final path = Path();
    for (int i = 0; i < segments.length; i++) {
      double x = (segments[i].x - minX + 0.5) * cellSize;
      double y = (segments[i].y - minY + 0.5) * cellSize;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // ── Arrowhead ─────────────────────────────────────────────────────────
    // Drawn as a filled triangle at the last segment, rotated to match direction

    final headSegment = segments.last;
    double headX = (headSegment.x - minX + 0.5) * cellSize;
    double headY = (headSegment.y - minY + 0.5) * cellSize;

    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final headPath = Path();
    double headSize = cellSize * 0.4 * sizeFactor;

    // Triangle pointing upward by default; rotated below
    headPath.moveTo(0, -headSize / 2);
    headPath.lineTo(headSize / 2, headSize / 2);
    headPath.lineTo(-headSize / 2, headSize / 2);
    headPath.close();

    // Rotation angle (radians) per direction
    double angle = 0;
    switch (direction) {
      case ArrowDirection.up:    angle = 0;             break;
      case ArrowDirection.right: angle = 3.14159 / 2;  break;
      case ArrowDirection.down:  angle = 3.14159;       break;
      case ArrowDirection.left:  angle = -3.14159 / 2; break;
      case ArrowDirection.white: break; // no arrowhead
    }

    if (direction != ArrowDirection.white) {
      // Translate to head position, rotate, then draw
      canvas.save();
      canvas.translate(headX, headY);
      canvas.rotate(angle);
      canvas.drawPath(headPath, headPaint);
      canvas.restore();
    } else {
      // White (neutral) arrows render a circle instead of an arrowhead
      canvas.drawCircle(
          Offset(headX, headY), cellSize * 0.2 * sizeFactor, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
