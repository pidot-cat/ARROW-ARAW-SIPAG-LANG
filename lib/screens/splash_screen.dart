// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/splash_screen.dart
// Animated launch screen shown for [AppConstants.splashDuration] on cold start.
// Checks the Supabase session and SharedPreferences to determine whether the
// user is already authenticated, then routes to HomeScreen or LoginScreen.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/splash_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Splash Screen — launch screen with mandatory internet connectivity check.
//
// Navigation rules:
//   • Online + logged-in      → /home  (skip login entirely)
//   • Online + not logged-in  → /login
//   • Offline (any state)     → stay on splash with a persistent SnackBar
//                               and poll every 3 s until connection returns
//
// The app blocks ALL navigation while offline — even previously authenticated
// users cannot proceed. This ensures Supabase session validation always
// has a working connection.
//
// Animation: logo fades in (Curves.easeIn) and scales up (Curves.elasticOut)
// over 2 seconds, giving a polished first impression.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Guard to avoid showing the SnackBar more than once while polling
  bool _snackBarShown = false;

  @override
  void initState() {
    super.initState();

    // 2-second animation controller drives both fade and scale
    _controller = AnimationController(
        duration: const Duration(seconds: 2), vsync: this);

    // Simple ease-in fade from transparent to fully opaque
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Elastic scale-up from 50% to 100% for a "pop" entrance effect
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
    _init(); // Begin connectivity check and routing logic
  }

  // ── Internet check ─────────────────────────────────────────────────────────

  /// Performs a real DNS lookup to google.com with a 5-second timeout.
  ///
  /// Using InternetAddress.lookup() is more reliable than checking
  /// connectivity status alone — it confirms actual internet reachability,
  /// not just whether Wi-Fi/mobile data is enabled.
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Main entry flow ────────────────────────────────────────────────────────

  /// Called once from initState. Waits for the splash animation to complete,
  /// then checks connectivity before deciding where to navigate.
  Future<void> _init() async {
    // Let the logo animation play out before routing
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final online = await _hasInternet();
    if (!mounted) return;

    if (!online) {
      // No internet — show SnackBar and start polling
      _showNoInternetSnackBar();
      _retryWhenOnline();
      return;
    }

    // Online — wait for AuthProvider to finish its boot-time session check
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isReady) await _waitForAuthReady(auth);
    if (!mounted) return;

    // Route based on login state
    if (auth.isLoggedIn) {
      _goHome();
    } else {
      _goLogin();
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Offline handling ───────────────────────────────────────────────────────

  /// Shows a persistent (days-long duration) SnackBar while the app waits
  /// for connectivity. Dismissed programmatically in _retryWhenOnline().
  void _showNoInternetSnackBar() {
    if (!mounted || _snackBarShown) return;
    _snackBarShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please check your internet connection.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(days: 1), // Stays up until dismissed programmatically
      ),
    );
  }

  /// Polls every 3 seconds until internet is restored, then dismisses the
  /// SnackBar and resumes normal navigation.
  void _retryWhenOnline() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final online = await _hasInternet();
      if (!mounted) return;

      if (!online) {
        _retryWhenOnline(); // Not online yet — schedule another check
        return;
      }

      // Back online — dismiss the SnackBar and proceed
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _snackBarShown = false;

      // Re-check auth state (may have changed while offline)
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isReady) await _waitForAuthReady(auth);
      if (!mounted) return;

      if (auth.isLoggedIn) {
        _goHome();
      } else {
        _goLogin();
      }
    });
  }

  // ── Auth readiness wait ────────────────────────────────────────────────────

  /// Suspends execution until AuthProvider.isReady becomes true.
  ///
  /// AuthProvider._loadAuthState() runs asynchronously in the constructor.
  /// This helper avoids polling by attaching a listener that completes a
  /// Completer as soon as isReady flips to true.
  Future<void> _waitForAuthReady(AuthProvider auth) async {
    final completer = Completer<void>();
    void listener() {
      if (auth.isReady) {
        auth.removeListener(listener);
        completer.complete();
      }
    }
    auth.addListener(listener);
    return completer.future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1D),
      body: Container(
        // Semi-transparent background image for visual context during load
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppConstants.background),
            fit: BoxFit.cover,
            opacity: 0.4,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo — scales and fades in via the animation above
                Image.asset(
                  AppConstants.logoWithBg,
                  width: size.width * 0.55,
                  height: size.width * 0.55,
                ),
                SizedBox(height: size.height * 0.06),
                // Loading spinner shown while connectivity/auth checks run
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.cyan),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
