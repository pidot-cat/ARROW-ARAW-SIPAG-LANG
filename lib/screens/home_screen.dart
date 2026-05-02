// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/home_screen.dart
// Main hub screen shown after login. Provides navigation entry points to Play,
// Records, Settings, Contact, and About sections.
// Reads [AuthProvider] to display the current username and handle sign-out.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// FIX-3a LOBBY MUSIC ON LAUNCH:
//   • initState() calls resumeMenuMusic() (not playMenuMusic()) so that
//     lobby music starts on FIRST launch as well as on return from a game.
//     resumeMenuMusic() clears the early-return guard before playing, so it
//     always restarts the track regardless of prior state.
//   • WidgetsBindingObserver is REMOVED from HomeScreen. The AudioService
//     singleton already registers its own observer via attachLifecycleObserver()
//     and handles foreground/background transitions globally. Having a second
//     observer here caused it to call playMenuMusic() unconditionally on resume
//     even while an in-game screen was in the foreground, overriding game music.
//
// FIX-3d LEVEL SELECT RETURN: Navigator.push to LevelSelectScreen now has a
//   .then() callback that calls resumeMenuMusic() when the user returns via
//   the system back button. Without this, HomeScreen.initState() does not
//   re-fire on return (the screen was never disposed), so the lobby music
//   would remain silent after backing out of the level select grid.
//
// [FIX NAV] PopScope(canPop: false) — system back button disabled on Home.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../widgets/background_wrapper.dart';
import '../widgets/gradient_button.dart';
import '../utils/constants.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    // FIX-3a: resumeMenuMusic() clears the early-return guard before playing,
    // ensuring lobby music starts on first launch AND on return from a level.
    // Using playMenuMusic() would silently no-op if _currentMusic was already
    // 'menu' (e.g. from a previous navigation), missing the first-launch case.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioService.resumeMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    // [FIX NAV] canPop: false prevents system back from returning to Login
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BackgroundWrapper(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppConstants.logoWithBg,
                    width: size.width * 0.5,
                    height: size.width * 0.5,
                  ),
                  SizedBox(height: size.height * 0.022),
                  Text(
                    'Arrow Araw Sipag Lang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size.width * 0.07,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome, ${authProvider.username}!',
                    style: TextStyle(
                      color: Colors.white.withAlpha(128),
                      fontSize: size.width * 0.045,
                    ),
                  ),
                  SizedBox(height: size.height * 0.07),
                  GradientButton(
                    text: 'PLAY',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LevelSelectScreen(),
                        ),
                      ).then((_) {
                        // FIX-3d: initState() does not re-fire when returning
                        // to an already-mounted screen via system back. Explicitly
                        // resume lobby music here so it plays seamlessly after the
                        // user backs out of the Level Select screen.
                        if (mounted) _audioService.resumeMenuMusic();
                      });
                    },
                  ),
                  SizedBox(height: size.height * 0.022),
                  GradientButton(
                    text: 'RECORDS',
                    onPressed: () => Navigator.pushNamed(context, '/records'),
                  ),
                  SizedBox(height: size.height * 0.022),
                  GradientButton(
                    text: 'SETTINGS',
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
