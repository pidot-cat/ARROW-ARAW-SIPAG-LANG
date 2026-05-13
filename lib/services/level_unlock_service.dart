// lib/services/level_unlock_service.dart

// Manages saving and loading the highest unlocked level.
// Dual-storage: SharedPreferences (local, instant) + Supabase (remote, persistent
// across devices / after logout).  The higher of the two values always wins so
// offline progress is never lost.

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
    // ── BUG FIX: Account Isolation for Level Progress ────────────────────────
    // Old behaviour: local (SharedPreferences) and remote (Supabase) values
    // were compared and the HIGHER one was used. This caused a newly registered
    // account on the same device to inherit the previous account's unlock
    // progress — because:
    //   a) The old account's SharedPreferences cache was NOT wiped per-user.
    //   b) If the old account had a Supabase row with level > 1, that remote
    //      value would "win" and overwrite the new user's correct starting
    //      value of 1.
    //
    // New behaviour — Supabase is the ONLY source of truth (same pattern as
    // GameProvider._loadStats fix):
    //   1. Fetch the current user's OWN row from Supabase.
    //   2. If the row exists → use that value (returning user, correct progress).
    //   3. If no row exists  → return 1 (brand-new user, Level 1 only unlocked).
    //   4. If network fails  → fall back to local cache (offline resilience).
    // The "higher value wins" logic is REMOVED — it was the root cause of
    // progress bleeding between accounts on the same device.

    final prefs = await SharedPreferences.getInstance();

    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final row = await _client
            .from(_kTable)
            .select('highest_unlocked_level')
            .eq('user_id', user.id)
            .maybeSingle();

        if (row != null) {
          // Returning user — use their real Supabase value
          final remoteLevel = (row['highest_unlocked_level'] as int?) ?? 1;
          // Sync local cache to match Supabase (so offline play is consistent)
          await prefs.setInt(_kHighestLevel, remoteLevel);
          return remoteLevel;
        } else {
          // Brand-new user — no Supabase row yet.
          // Initialise the row with Level 1 so future loads are consistent.
          await _client.from(_kTable).upsert(
            {
              'user_id': user.id,
              'highest_unlocked_level': 1,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id',
          );
          // Reset local cache to 1 as well — critical so no old account value leaks
          await prefs.setInt(_kHighestLevel, 1);
          return 1;
        }
      }
    } catch (e) {
      // Network unavailable — fall back to local cache as last resort
      debugPrint('[LevelUnlockService] loadHighestUnlocked remote error: $e');
    }

    // Offline fallback: use local cache (defaults to 1 for new users)
    return prefs.getInt(_kHighestLevel) ?? 1;
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
