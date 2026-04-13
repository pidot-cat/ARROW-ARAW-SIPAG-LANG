// lib/providers/game_provider.dart
// FIX Bug 2: Added stopLevel() — call this before Navigator.pop() to prevent
// the timer from firing playLoseSound() after the screen is gone.
// Each level screen's LevelStateMixin manages its OWN timer. GameProvider's
// timer is only used by the legacy GameScreen (kept for compatibility).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  GameStatsModel _stats = GameStatsModel();
  GameStatsModel get stats => _stats;

  Timer? _timer;
  final AudioService _audioService = AudioService();

  GameProvider() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    _stats = GameStatsModel(
      totalWins: prefs.getInt(AppConstants.keyTotalWins) ?? 0,
      totalLosses: prefs.getInt(AppConstants.keyTotalLosses) ?? 0,
      totalMatches: prefs.getInt(AppConstants.keyTotalMatches) ?? 0,
      totalDays: prefs.getInt(AppConstants.keyTotalDays) ?? 1,
    );
    notifyListeners();
    try {
      final remoteStats = await SupabaseService.fetchGameStats();
      if (remoteStats != null) {
        _stats = remoteStats;
        await _saveLocalStats();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing stats from Supabase: $e');
    }
  }

  Future<void> _saveStats() async {
    await _saveLocalStats();
    try {
      await SupabaseService.saveGameStats(_stats);
    } catch (e) {
      debugPrint('Error saving stats to Supabase: $e');
    }
  }

  Future<void> _saveLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyTotalWins, _stats.totalWins);
    await prefs.setInt(AppConstants.keyTotalLosses, _stats.totalLosses);
    await prefs.setInt(AppConstants.keyTotalMatches, _stats.totalMatches);
    await prefs.setInt(AppConstants.keyTotalDays, _stats.totalDays);
  }

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

  // ── FIX Bug 2: stopLevel — cancel timer cleanly before Navigator.pop ──────
  /// Call this whenever the player navigates away from a level (back button,
  /// quit dialog, etc.) to prevent the timer from firing lose-sound after pop.
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
    _stats.addLoss();
    _saveStats();
    _audioService.playLoseSound();
    notifyListeners();
  }

  void _checkWinCondition() {
    if (_arrows.every((a) => a.isRemoved)) {
      _timer?.cancel();
      _isLevelWon = true;
      _stats.addWin();
      _saveStats();
      _audioService.playWinSound();
      notifyListeners();
    }
  }

  /// Clears all stats locally and in Supabase. Called on account deletion.
  /// Saves zeroed stats so any re-registration sees clean history.
  Future<void> resetStats() async {
    _stats = GameStatsModel();
    await _saveLocalStats();
    // Also zero-out the remote record so re-registration starts fresh
    try {
      await SupabaseService.saveGameStats(_stats);
    } catch (e) {
      debugPrint('resetStats remote error (non-fatal): $e');
    }
    notifyListeners();
  }

  // Refreshes stats from Supabase (updates local cache too).
  Future<void> refreshStats() async => await _loadStats();

  void nextLevel() {
    if (_currentLevel < 10) initLevel(_currentLevel + 1);
  }

  void playErrorSound() => _audioService.playLoseSound();
  void playArrowSound() => _audioService.playArrowSound();
  void playWinSound() => _audioService.playWinSound();
  void playGameMusic() => _audioService.playGameMusic();
  void resumeMenuMusic() => _audioService.resumeMenuMusic();

  void recordLevelComplete(
      {required int level, required int time, required int lives}) {
    _stats.addWin();
    _saveStats();
    notifyListeners();
  }

  /// Called from BentLevelStateMixin.triggerGameOver to record a loss.
  void recordLevelLoss() {
    _stats.addLoss();
    _saveStats();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
