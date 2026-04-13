// lib/services/level_unlock_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Manages saving and loading the highest unlocked level.
// Dual-storage: SharedPreferences (local, instant) + Supabase (remote, persistent
// across devices / after logout).  The higher of the two values always wins so
// offline progress is never lost.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Key used in SharedPreferences to store the local highest-unlocked level.
const String _kHighestLevel = 'highest_unlocked_level';

/// Supabase table where per-user level progress is stored.
const String _kTable = 'level_progress';

class LevelUnlockService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  LevelUnlockService._();
  static final LevelUnlockService instance = LevelUnlockService._();

  // ── Supabase client shortcut ───────────────────────────────────────────────
  /// Returns the active Supabase client.
  static SupabaseClient get _client => Supabase.instance.client;

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Returns the highest unlocked level (1–10).
  /// Reads both local and remote values and returns the greater one so that
  /// progress survived offline play is never overwritten.
  Future<int> loadHighestUnlocked() async {
    // Read local value first (fast, no network required)
    final prefs = await SharedPreferences.getInstance();
    final localLevel = prefs.getInt(_kHighestLevel) ?? 1;

    // Try to read the remote value; fall back to local if network is unavailable
    int remoteLevel = 1;
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final row = await _client
            .from(_kTable)
            .select('highest_unlocked_level')
            .eq('user_id', user.id)
            .maybeSingle();
        if (row != null) {
          remoteLevel = (row['highest_unlocked_level'] as int?) ?? 1;
        }
      }
    } catch (e) {
      // Network or Supabase error — use local value only
      debugPrint('[LevelUnlockService] loadHighestUnlocked remote error: $e');
    }

    // The greater value wins (progress may have come from another device)
    final best = localLevel > remoteLevel ? localLevel : remoteLevel;

    // Sync local cache with the best value
    await prefs.setInt(_kHighestLevel, best);
    return best;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Unlocks levels up to [level] (1-indexed).
  /// Writes to SharedPreferences immediately and then syncs to Supabase.
  Future<void> unlockLevel(int level) async {
    // Clamp to valid range 1–10
    final clamped = level.clamp(1, 10);

    // Only advance if [clamped] is higher than what we currently have
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kHighestLevel) ?? 1;
    if (clamped <= current) return; // already unlocked — nothing to do

    // Write locally first so UI can update without waiting for the network
    await prefs.setInt(_kHighestLevel, clamped);

    // Push to Supabase
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from(_kTable).upsert(
          {
            'user_id': user.id,
            'highest_unlocked_level': clamped,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      }
    } catch (e) {
      // Non-fatal — local prefs already updated, will sync next time
      debugPrint('[LevelUnlockService] unlockLevel remote error: $e');
    }
  }

  // ── Master unlock — called when all 10 levels are cleared ────────────────

  /// Unlocks all 10 levels permanently so the user can replay freely.
  Future<void> unlockAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHighestLevel, 10);
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from(_kTable).upsert(
          {
            'user_id': user.id,
            'highest_unlocked_level': 10,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      }
    } catch (e) {
      debugPrint('[LevelUnlockService] unlockAll remote error: $e');
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Resets local level-progress cache to Level 1.
  ///
  /// Called in three scenarios:
  ///   1. Account deletion — wipes local data before the remote row is removed.
  ///   2. Logout           — ensures the next user that logs in on this device
  ///                         doesn't inherit the previous session's unlocks.
  ///   3. Login / Sign-up  — forces a fresh Supabase fetch so THIS user's real
  ///                         remote progress is authoritative (prevents bleed
  ///                         from a prior tester account stored in SharedPrefs).
  ///
  /// Remote cleanup (rows in `level_progress`) is handled separately by
  /// SupabaseService.deleteAccount() for the deletion case.
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHighestLevel, 1);
  }
}
