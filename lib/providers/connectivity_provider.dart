// lib/providers/connectivity_provider.dart

// PURPOSE:
//   Global internet connectivity state manager for the entire app.
//   Uses connectivity_plus to listen to connection changes in real-time,
//   and dart:io InternetAddress.lookup() to confirm actual internet access
//   (not just whether Wi-Fi/mobile-data is enabled on the device).

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider with ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isOnline = true; // Optimistic default; corrected immediately in init
  bool _disposed = false; // Guards async callbacks after dispose()

  bool get isOnline => _isOnline;

  // ── Internals ──────────────────────────────────────────────────────────────
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // ── Constructor ────────────────────────────────────────────────────────────
  ConnectivityProvider() {
    _init();
  }

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Performs an immediate connectivity check on startup, then subscribes
  /// to the connectivity stream for real-time updates.
  Future<void> _init() async {
    // Check current status right away so the first screen has accurate data
    await _checkAndUpdate();

    // Subscribe to changes — fires whenever Wi-Fi / mobile-data toggles
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        // connectivity_plus v6 returns a list; check if any result is "connected"
        if (results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none)) {
          // Clearly no connectivity interface — skip the DNS check, go offline
          _updateStatus(false);
        } else {
          // An interface is available — do a real DNS lookup to confirm internet
          await _checkAndUpdate();
        }
      },
    );
  }

  // ── Connectivity check ─────────────────────────────────────────────────────

  /// Performs a real DNS lookup to confirm actual internet reachability.
  ///
  /// Checking the connectivity interface alone is insufficient — the device
  /// can be connected to a Wi-Fi router with no internet gateway, or be in
  /// captive-portal mode. A DNS lookup to a reliable host (google.com)
  /// confirms end-to-end internet access within a 5-second timeout.
  Future<void> _checkAndUpdate() async {
    final online = await _hasInternet();
    if (!_disposed) {
      _updateStatus(online);
    }
  }

  /// Returns true if a DNS lookup to google.com succeeds within 5 seconds.
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Updates [_isOnline] and notifies listeners only when the value actually
  /// changes — prevents redundant rebuilds when status stays the same.
  void _updateStatus(bool online) {
    if (_disposed) return;
    if (_isOnline == online) return; // No change — don't notify
    _isOnline = online;
    notifyListeners();
  }

  // ── Manual re-check ───────────────────────────────────────────────────────

  /// Allows a screen to manually trigger a connectivity re-check.
  /// Used by the offline-blocking overlay's "Retry" logic if needed.
  Future<void> recheck() async {
    await _checkAndUpdate();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
