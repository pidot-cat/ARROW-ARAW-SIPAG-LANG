// lib/widgets/connectivity_wrapper.dart

// PURPOSE:
//   A transparent wrapper widget that watches ConnectivityProvider and:
//     1. Shows a persistent "Please check your internet connection." SnackBar
//        whenever the device goes offline (matches the Splash Screen style).
//     2. Shows a "Back online" SnackBar when the connection is restored.
//     3. Renders a full-screen blocking overlay while offline, preventing
//        the user from interacting with any UI underneath.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  // Track the previous online state so we know when a *change* occurs
  bool? _previousOnline;

  @override
  Widget build(BuildContext context) {
    // Listen to the provider — this widget rebuilds on every status change
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    // Schedule SnackBar display after the current build frame completes.
    // Calling ScaffoldMessenger inside build() directly would throw:
    // "setState() or markNeedsBuild() called during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Only act when the status actually changes (not on first build)
      if (_previousOnline == null) {
        // First build — just record the initial state, show snackbar if offline
        if (!isOnline) {
          _showOfflineSnackBar();
        }
        _previousOnline = isOnline;
        return;
      }

      if (_previousOnline == isOnline) return; // No change — do nothing

      if (!isOnline) {
        _showOfflineSnackBar();
      } else {
        _showOnlineSnackBar();
      }
      _previousOnline = isOnline;
    });

    return Stack(
      children: [
        // The actual screen content
        widget.child,

        // Blocking overlay — covers entire screen when offline
        // AbsorbPointer swallows all touch events so buttons can't be tapped
        if (!isOnline)
          AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black.withAlpha(160),
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── SnackBar Helpers ───────────────────────────────────────────────────────

  /// Shows a persistent offline SnackBar matching the Splash Screen style.
  void _showOfflineSnackBar() {
    if (!mounted) return;
    // Dismiss any existing snackbar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please check your internet connection.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        // Long duration — dismissed programmatically when back online
        duration: Duration(days: 1),
      ),
    );
  }

  /// Dismisses the offline SnackBar and shows a brief "back online" message.
  void _showOnlineSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Internet connection restored.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
