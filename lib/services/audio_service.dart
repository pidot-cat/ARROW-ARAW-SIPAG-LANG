// lib/services/audio_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Arrow Araw — AudioService v9  (PRODUCTION FINAL — Fix 5 Applied)
//
// FIX-3b v3 TOGGLE RESUME: toggleMusic() now uses plain resume() when toggling
//         ON. The previous v2 implementation called seek(Duration.zero) before
//         resume(), which restarted the track from second zero — the exact
//         behaviour the bug report flagged. Removing seek() means the player
//         resumes from the position it was paused at, delivering true seamless
//         continuation. A catchError() fallback restarts the correct track if the
//         OS killed the player session while it was paused.
//
// FIX-3c v2 LIFECYCLE: didChangeAppLifecycleState now pauses on 'inactive' state
//         in addition to paused/detached/hidden — covers notification shade and
//         incoming call overlay. Resume path adds .catchError() fallback: if the
//         OS killed the AudioPlayer session while backgrounded, it force-restarts
//         the correct track instead of silently failing.
//
// WIN-DEBOUNCE  playWinSound() guarded by _winSoundPlayed; reset by
//               resetWinSoundGuard() from restart() / initLevelState().
// LOBBY-MUSIC   playMenuMusic() early-return guard (no-op on second call).
//               resumeMenuMusic() force-restarts regardless of guard.
// FIX-A         startIdleResumeTimer() — 2s idle → resume game music.
// FIX-C         SFX players are separate from _musicPlayer.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class AudioService with WidgetsBindingObserver {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // ── Players ────────────────────────────────────────────────────────────────
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _wrongPlayer = AudioPlayer();

  // ── Settings ───────────────────────────────────────────────────────────────
  bool _isMusicOn = true;
  bool _isSfxOn = true;
  bool get isMusicOn => _isMusicOn;
  bool get isSfxOn => _isSfxOn;

  // ── State: '' | 'menu' | 'game' | 'win' | 'lose' ─────────────────────────
  String _currentMusic = '';

  // WIN-DEBOUNCE
  bool _winSoundPlayed = false;
  void resetWinSoundGuard() => _winSoundPlayed = false;

  // ── Idle resume timer (FIX-A) ─────────────────────────────────────────────
  Timer? _idleTimer;

  void startIdleResumeTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 2), _resumeIfGame);
  }

  void cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> _resumeIfGame() async {
    if (_currentMusic != 'game' || !_isMusicOn) return;
    await _musicPlayer.resume();
  }

  // ── AppLifecycle observer (FIX-3c v2) ─────────────────────────────────────
  bool _observerAttached = false;

  void attachLifecycleObserver() {
    if (_observerAttached) return;
    _observerAttached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // FIX-3c v2: PAUSE on ALL non-foreground states including 'inactive'
      // (notification shade, incoming call overlay, app switcher). This stops
      // music leaking through OS interruptions while keeping _currentMusic
      // intact so the correct track resumes when the user returns.
      _musicPlayer.pause();
      _sfxPlayer.stop();
      _wrongPlayer.stop();
      cancelIdleTimer();
    }
    if (state == AppLifecycleState.resumed && _isMusicOn) {
      // FIX-3c v2: Try resume() first. On some Android devices the OS kills
      // the AudioPlayer session while backgrounded. If resume() throws
      // (stopped/disposed player), fall back to a full restart of whichever
      // track was active before backgrounding — preserving music continuity.
      if (_currentMusic == 'menu' || _currentMusic == 'game') {
        _musicPlayer.resume().catchError((_) {
          final track = _currentMusic;
          _currentMusic = ''; // clear guard to allow restart
          if (track == 'menu') {
            playMenuMusic();
          } else if (track == 'game') {
            playGameMusic();
          }
        });
      }
    }
  }

  // ── Toggle controls (FIX-3b v3) ───────────────────────────────────────────────
  Future<void> toggleMusic() async {
    _isMusicOn = !_isMusicOn;
    if (!_isMusicOn) {
      await _musicPlayer.pause();
    } else {
      if (_currentMusic == 'menu') {
        // FIX-3b v3: Call resume() directly — no seek(). The previous v2
        // implementation called seek(Duration.zero) before resume(), which
        // restarted the lobby track from second zero on every toggle-ON.
        // Plain resume() returns to the exact position the track was paused at,
        // delivering true seamless continuation of the loop. If the player was
        // stopped (OS killed the session), catchError restarts it from scratch.
        _musicPlayer.resume().catchError((_) {
          _currentMusic = '';
          playMenuMusic();
        });
      } else if (_currentMusic == 'game') {
        // Game music: player was only paused — resume is safe.
        await _musicPlayer.resume();
      } else {
        // No track was active (e.g. toggled off before any music started).
        // Default to lobby music so the user hears something immediately.
        _currentMusic = '';
        await playMenuMusic();
      }
    }
  }

  void toggleSfx() => _isSfxOn = !_isSfxOn;

  // ── Music playback ─────────────────────────────────────────────────────────

  Future<void> playMenuMusic() async {
    if (_currentMusic == 'menu') return; // early-return guard (no-op)
    _currentMusic = 'menu';
    await _musicPlayer.stop();
    if (!_isMusicOn) return;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.play(AssetSource('audio/Lobby-Music.mp3'));
  }

  Future<void> playGameMusic() async {
    if (_currentMusic == 'game') return;
    _currentMusic = 'game';
    await _musicPlayer.stop();
    if (!_isMusicOn) return;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.play(AssetSource('audio/Ingame-Music.mp3'));
  }

  /// Force lobby music to restart even if already playing.
  /// Call when returning to HomeScreen from a game session.
  Future<void> resumeMenuMusic() async {
    _currentMusic = ''; // clear guard so playMenuMusic re-starts
    await playMenuMusic();
  }

  // ── SFX — separate players; never touch _musicPlayer ─────────────────────

  Future<void> playArrowSound() async {
    if (!_isSfxOn) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('audio/Arrow-Sound.mp3'));
  }

  Future<void> playWrongSound() async {
    if (!_isSfxOn) return;
    await _wrongPlayer.stop();
    await _wrongPlayer.play(AssetSource('audio/Wrong Move-Sound.mp3'));
  }

  Future<void> playWinSound() async {
    if (_winSoundPlayed) return;
    _winSoundPlayed = true;
    _currentMusic = 'win';
    cancelIdleTimer();
    await _musicPlayer.stop();
    if (!_isSfxOn) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('audio/Win-Sound.mp3'));
  }

  Future<void> playGameOverSound() async {
    _currentMusic = 'lose';
    cancelIdleTimer();
    await _musicPlayer.stop();
    if (!_isSfxOn) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('audio/Lose-Sound.mp3'));
  }

  // ── Utility ────────────────────────────────────────────────────────────────
  Future<void> stopAll() async {
    cancelIdleTimer();
    await _musicPlayer.stop();
    await _sfxPlayer.stop();
    await _wrongPlayer.stop();
    _currentMusic = '';
  }

  // ── Legacy shims ───────────────────────────────────────────────────────────
  Future<void> playLoseSound() async => playGameOverSound();
  Future<void> stopGameMusic() async {
    await _musicPlayer.stop();
    await Future.delayed(const Duration(milliseconds: 150));
    await resumeMenuMusic();
  }
}
