// lib/providers/game_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/arrow_model.dart';
import '../models/game_stats_model.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class GameProvider with ChangeNotifier {
  int _currentLevel = 1;
  int get currentLevel => _currentLevel;

  final List<ArrowModel> _arrows = [];
  List<ArrowModel> get arrows => _arrows;

  final int _gridSize = 5;
  int get gridSize => _gridSize;

  final String _shapeName = '';
  String get shapeName => _shapeName;

  int _lives = AppConstants.initialLives;
  int get lives => _lives;

  int _timeLeft = 60;
  int get timeLeft => _timeLeft;

  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;

  bool _isLevelWon = false;
  bool get isLevelWon => _isLevelWon;

  bool _statsLoading = false;
  bool get statsLoading => _statsLoading;
  Future<void>? _loadStatsFuture;

  GameStatsModel _stats = GameStatsModel();
  GameStatsModel get stats => _stats;

  Timer? _timer;
  final AudioService _audioService = AudioService();

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH STATE LISTENER — Auto-refresh on account switch
  // ══════════════════════════════════════════════════════════════════════════

  StreamSubscription<AuthState>? _authStateSubscription;
  String? _lastKnownUserId;

  GameProvider() {
    _loadStats();
    _setupAuthStateListener();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATS LOADING — always fetches from Supabase first (source of truth)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadStats({bool force = false}) async {
    if (!force && _loadStatsFuture != null) {
      return _loadStatsFuture!;
    }
    _loadStatsFuture = _doLoadStats();
    try {
      await _loadStatsFuture;
    } finally {
      _loadStatsFuture = null;
    }
  }

  Future<void> _doLoadStats() async {
    // FIX: Always start from zeros — never show a previous account's data.
    _statsLoading = true;
    _stats = GameStatsModel();
    notifyListeners();

    try {
      // SOURCE OF TRUTH: fetch from Supabase using the current user's UID.
      // SupabaseService.fetchGameStats() queries WHERE user_id = auth.uid(),
      // so it is impossible to get another user's row.
      final remoteStats = await SupabaseService.fetchGameStats();
      if (remoteStats != null) {
        // Returning user — use their real cloud stats.
        _stats = remoteStats;
        await _saveLocalStats();
      }
      // New user — remoteStats is null (no DB row yet). Zeros remain. Correct.
    } catch (e) {
      // Network unavailable — fall back to local cache as last resort.
      // This cache was zeroed on login (_clearAllUserData in AuthProvider),
      // so if the user just logged in, this returns 0s, not stale data.
      debugPrint('[GameProvider] Error syncing stats from Supabase: $e');
      final prefs = await SharedPreferences.getInstance();
      _stats = GameStatsModel(
        totalWins: prefs.getInt(AppConstants.keyTotalWins) ?? 0,
        totalLosses: prefs.getInt(AppConstants.keyTotalLosses) ?? 0,
        totalMatches: prefs.getInt(AppConstants.keyTotalMatches) ?? 0,
        totalDays: prefs.getInt(AppConstants.keyTotalDays) ?? 1,
      );
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH STATE LISTENER
  // ══════════════════════════════════════════════════════════════════════════

  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();
    _lastKnownUserId = SupabaseService.currentUser?.id;

    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        final event = authState.event;
        final currentUserId = authState.session?.user.id;

        debugPrint('[GameProvider] Auth event: $event, userId: $currentUserId');

        // Only react to actual user changes, not token refreshes or
        // initial session restorations (which fire on app boot even if
        // the same user is already logged in).
        if (event == AuthChangeEvent.signedIn) {
          if (_lastKnownUserId != currentUserId) {
            debugPrint(
                '[GameProvider] New sign-in detected: $_lastKnownUserId → $currentUserId');
            _lastKnownUserId = currentUserId;
            refreshStats();
          }
          // Same user re-authenticated (e.g. token refresh) — do nothing.
        } else if (event == AuthChangeEvent.signedOut) {
          debugPrint('[GameProvider] Sign-out detected, clearing stats.');
          _lastKnownUserId = null;
          clearStats();
        }
        // Ignore: tokenRefreshed, userUpdated, passwordRecovery, etc.
      },
      onError: (error) {
        debugPrint('[GameProvider] Auth state listener error: $error');
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE STATS — uses upsert so each user has exactly one row
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveStats() async {
    if (_statsLoading) {
      await _loadStats();
    }
    await _saveLocalStats();
    try {
      // FIX: SupabaseService.saveGameStats uses .upsert(onConflict: 'user_id')
      // so if this user already has a row, it is UPDATED not duplicated.
      // If they don't have a row yet, a new one is INSERTED.
      // This is the core fix that prevents records from resetting on account switch.
      await SupabaseService.saveGameStats(_stats);
    } catch (e) {
      debugPrint('[GameProvider] Error saving stats to Supabase: $e');
    }
  }

  Future<void> _saveLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyTotalWins, _stats.totalWins);
    await prefs.setInt(AppConstants.keyTotalLosses, _stats.totalLosses);
    await prefs.setInt(AppConstants.keyTotalMatches, _stats.totalMatches);
    await prefs.setInt(AppConstants.keyTotalDays, _stats.totalDays);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAME LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  void initLevel(int level) {
    _timer?.cancel();
    _currentLevel = level;
    _lives = AppConstants.initialLives;
    _timeLeft = 60;
    _isGameOver = false;
    _isLevelWon = false;
    _startTimer();
    notifyListeners();
  }

  void stopLevel() {
    _timer?.cancel();
    _timer = null;
    _isGameOver = false;
    _isLevelWon = false;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver || _isLevelWon) {
        timer.cancel();
        return;
      }
      if (_timeLeft > 0) {
        _timeLeft--;
        notifyListeners();
      } else {
        _handleTimerGameOver();
      }
    });
  }

  void _handleTimerGameOver() {
    _timer?.cancel();
    _isGameOver = true;
    // NOTE: addLoss() is called here ONLY — do not call recordLevelLoss() too
    _stats.addLoss();
    _saveStats();
    _audioService.playLoseSound();
    notifyListeners();
  }

  void tapArrow(ArrowModel arrow) {
    if (_isGameOver || _isLevelWon || arrow.isEscaping || arrow.isRemoved) {
      return;
    }
    if (_canEscape(arrow)) {
      _audioService.playArrowSound();
      arrow.isEscaping = true;
      notifyListeners();
      Future.delayed(AppConstants.arrowMoveDuration, () {
        arrow.isRemoved = true;
        arrow.isEscaping = false;
        _checkWinCondition();
        notifyListeners();
      });
    } else {
      _lives--;
      if (_lives <= 0) _handleLivesGameOver();
      notifyListeners();
    }
  }

  bool _canEscape(ArrowModel arrow) {
    for (final other in _arrows) {
      if (identical(other, arrow) || other.isRemoved || other.isEscaping) {
        continue;
      }
      for (final otherSegment in other.segments) {
        for (final segment in arrow.segments) {
          switch (arrow.direction) {
            case ArrowDirection.up:
              if (otherSegment.x == segment.x && otherSegment.y < segment.y) {
                return false;
              }
              break;
            case ArrowDirection.down:
              if (otherSegment.x == segment.x && otherSegment.y > segment.y) {
                return false;
              }
              break;
            case ArrowDirection.left:
              if (otherSegment.y == segment.y && otherSegment.x < segment.x) {
                return false;
              }
              break;
            case ArrowDirection.right:
              if (otherSegment.y == segment.y && otherSegment.x > segment.x) {
                return false;
              }
              break;
            case ArrowDirection.white:
              return true;
          }
        }
      }
    }
    return true;
  }

  void _handleLivesGameOver() {
    _timer?.cancel();
    _isGameOver = true;
    // NOTE: addLoss() is called here ONLY — do not call recordLevelLoss() too
    _stats.addLoss();
    _saveStats();
    _audioService.playLoseSound();
    notifyListeners();
  }

  void _checkWinCondition() {
    if (_arrows.every((a) => a.isRemoved)) {
      _timer?.cancel();
      _isLevelWon = true;
      // NOTE: addWin() is called here ONLY — do not call recordLevelComplete() too
      _stats.addWin();
      _saveStats();
      _audioService.playWinSound();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC STAT HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> resetStats() async {
    _stats = GameStatsModel();
    await _saveLocalStats();
    try {
      await SupabaseService.saveGameStats(_stats);
    } catch (e) {
      debugPrint('[GameProvider] resetStats remote error (non-fatal): $e');
    }
    notifyListeners();
  }

  /// Clears in-memory stats to zeros immediately.
  /// Called when the user logs out so Records screen shows 0s, not stale data.
  void clearStats() {
    _stats = GameStatsModel();
    notifyListeners();
  }

  /// Clears stats then fetches fresh data from Supabase for the current user.
  Future<void> refreshStats() async {
    clearStats();
    await _loadStats(force: true);
  }

  void nextLevel() {
    if (_currentLevel < 10) initLevel(_currentLevel + 1);
  }

  void playErrorSound() => _audioService.playLoseSound();
  void playArrowSound() => _audioService.playArrowSound();
  void playWinSound() => _audioService.playWinSound();
  void playGameMusic() => _audioService.playGameMusic();
  void resumeMenuMusic() => _audioService.resumeMenuMusic();

  // IMPORTANT: Do NOT call these from victory/game-over overlays if the
  // internal handlers (_checkWinCondition, _handleLivesGameOver, _handleTimerGameOver)
  // already ran — those already call addWin/addLoss. These methods exist only
  // for screens that bypass the internal game loop entirely.
  void recordLevelComplete(
      {required int level, required int time, required int lives}) {
    // Only count if not already counted by _checkWinCondition
    if (!_isLevelWon) {
      _stats.addWin();
      _saveStats();
      notifyListeners();
    }
  }

  void recordLevelLoss() {
    // Only count if not already counted by _handleLivesGameOver/_handleTimerGameOver
    if (!_isGameOver) {
      _stats.addLoss();
      _saveStats();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
