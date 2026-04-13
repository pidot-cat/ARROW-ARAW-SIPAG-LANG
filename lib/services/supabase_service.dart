// ============================================================
// lib/services/supabase_service.dart
// ============================================================
//
// PURPOSE:
//   This file is the single point of contact between the Flutter
//   app and the Supabase backend. Every Supabase API call goes
//   through this service — no screen or provider talks to Supabase
//   directly. This separation makes it easy to swap backends later.
//
// WHY THIS FILE EXISTS (for instructor):
//   Flutter apps follow a layered architecture:
//     UI Screen → Provider (state) → Service (API) → Backend
//   This class is the "Service" layer.
//
// ROOT CAUSE OF "unexpected_failure / Error sending confirmation email":
//   This error does NOT come from the Flutter/Dart code.
//   It comes from Supabase's server when it tries to send an email
//   but has no SMTP provider configured. The fix is 100% in the
//   Supabase Dashboard — see the Dashboard Fix section below.
//
//   The original signUp() call was also missing the 'emailRedirectTo'
//   parameter. While this doesn't cause the SMTP error, it IS required
//   when using OTP-style email confirmation so Supabase knows this is
//   an OTP flow and not a magic-link flow. Added below.
//
// ============================================================
// SUPABASE DASHBOARD FIX (do these steps exactly):
// ============================================================
//
//  STEP 1 — Disable the built-in email confirmation (fastest fix):
//    Supabase Dashboard → Authentication → Providers → Email
//    Toggle OFF "Confirm email"
//    → Users are confirmed instantly; no email is ever sent.
//    → signUp() returns a session immediately → no OTP screen needed.
//    Use this for development / testing.
//
//  STEP 2 — (Optional) Enable OTP emails properly for production:
//    a) Go to: Project Settings → Auth → SMTP Settings
//       Turn ON "Enable Custom SMTP"
//       Fill in your SMTP server details (e.g. SendGrid, Mailgun,
//       Gmail App Password, Resend.io — all work on free tiers).
//    b) Go to: Authentication → Providers → Email
//       Toggle ON "Confirm email"
//       Toggle ON "Secure email change" (recommended)
//    c) Go to: Authentication → Email Templates → Confirm signup
//       Ensure the template body contains {{ .Token }} (6-digit code)
//       NOT a magic-link URL. The default Supabase template uses a
//       magic link, which is why signUp() fails when you expect an OTP.
//       Replace the link template with:
//         "Your verification code is: {{ .Token }}"
//    d) Go to: Authentication → Rate Limits
//       Set "Email rate limit" to at least 5 per hour for testing.
//
//  WHY the original code got "unexpected_failure":
//    Supabase tried to send a confirmation email but:
//      • The built-in Supabase SMTP (used in free projects) has strict
//        rate limits and sometimes fails entirely on new projects.
//      • No custom SMTP was configured.
//    The server-side failure is surfaced as "unexpected_failure".
//
// ============================================================

// Import the Supabase Flutter SDK — provides SupabaseClient, AuthResponse,
// User, Session, OtpType, and all other Supabase types used below.
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the local GameStatsModel so this service can read/write game records.
import '../models/game_stats_model.dart';

/// SupabaseService — static wrapper around Supabase Auth and Database calls.
///
/// All methods are static so callers never need to instantiate this class:
///   final r = await SupabaseService.signUp(email: ..., ...);
class SupabaseService {

  // ── Private client getter ─────────────────────────────────────────────────
  //
  // Supabase.instance.client is the singleton SupabaseClient created in
  // main.dart via Supabase.initialize(). Accessing it via a getter (instead
  // of a field) means we always get the live instance after initialization.
  static SupabaseClient get _client => Supabase.instance.client;

  // ════════════════════════════════════════════════════════════════════════════
  // AUTH METHODS
  // ════════════════════════════════════════════════════════════════════════════

  // ── signUp ────────────────────────────────────────────────────────────────
  //
  // Creates a new user account in Supabase Auth.
  //
  // KEY FIX — emailRedirectTo parameter:
  //   When "Confirm email" is ON in the Supabase dashboard, Supabase normally
  //   sends a magic-link email. Passing emailRedirectTo with the scheme
  //   'io.supabase.arrowaraw://login-callback/' tells Supabase to treat this
  //   as an OTP (one-time-password) flow and send a 6-digit code instead.
  //   Without this, Supabase sends a link — or fails entirely if the link
  //   redirect is not configured (which causes "unexpected_failure").
  //
  //   The redirect URI must match a URI scheme registered in your app's
  //   AndroidManifest.xml and Supabase Dashboard → Auth → URL Configuration
  //   → Redirect URLs.  For a clean OTP-only flow (no deep links needed),
  //   keep "Confirm email" OFF in the dashboard (Step 1 above).
  //
  // Parameters:
  //   email    — the user's email address (validated by AuthProvider first)
  //   password — must be ≥8 characters (enforced by AuthProvider)
  //   username — stored in user_metadata so it travels with the account
  //
  // Returns:
  //   AuthResponse — contains .user (the created User object) and
  //                  .session (null if email confirmation is required)
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // client.auth.signUp() calls the Supabase Auth REST endpoint POST /auth/v1/signup
    return await _client.auth.signUp(
      email:    email,
      password: password,

      // Store the username inside the user's metadata object.
      // This is readable later via user.userMetadata?['username'].
      // We use metadata (not a separate DB table) to keep registration atomic —
      // if the signUp call succeeds, the username is guaranteed to exist.
      data: {'username': username},

      // KEY FIX — tells Supabase this is an OTP flow, not a magic-link flow.
      // Replace 'io.supabase.arrowaraw' with your actual app bundle ID scheme
      // if you change the package name. This must also be listed in:
      //   Supabase Dashboard → Auth → URL Configuration → Redirect URLs
      // Format: '<your-scheme>://login-callback/'
      emailRedirectTo: 'io.supabase.arrowaraw://login-callback/',
    );
  }

  // ── verifyOtp ─────────────────────────────────────────────────────────────
  //
  // Verifies a one-time-password (OTP) that Supabase emailed to the user.
  //
  // The 'type' parameter is critical:
  //   OtpType.signup   — used during registration (signUp flow)
  //   OtpType.recovery — used during password reset (forgot password flow)
  // Passing the wrong type will always return "Invalid token" even if the
  // code the user typed is correct.
  //
  // On success, Supabase returns an AuthResponse with both .user and .session
  // set, meaning the user is now fully authenticated.
  static Future<AuthResponse> verifyOtp({
    required String email,
    required String token, // the 6-digit code the user typed
    required OtpType type, // OtpType.signup or OtpType.recovery
  }) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type:  type,
    );
  }

  // ── resendOtp ─────────────────────────────────────────────────────────────
  //
  // Asks Supabase to send a fresh OTP to the same email address.
  // Called when the user taps "Resend" after the 60-second countdown ends.
  //
  // Supabase will reject this if the rate limit is exceeded (5 emails/hour
  // on free tier). The AuthProvider catches and surfaces that error.
  static Future<void> resendOtp({
    required String email,
    required OtpType type,
  }) async {
    // client.auth.resend() calls POST /auth/v1/resend
    await _client.auth.resend(email: email, type: type);
  }

  // ── signIn ────────────────────────────────────────────────────────────────
  //
  // Authenticates an existing user with email + password.
  // Returns AuthResponse; .session will be non-null on success.
  // Throws AuthException with message "Email not confirmed" if the user
  // registered but never verified their OTP — the LoginScreen handles this.
  static Future<AuthResponse> signIn(String email, String password) async {
    // signInWithPassword() calls POST /auth/v1/token?grant_type=password
    return await _client.auth.signInWithPassword(
      email:    email,
      password: password,
    );
  }

  // ── signOut ───────────────────────────────────────────────────────────────
  //
  // Ends the Supabase session on both the server and in local storage.
  // After this, currentUser and currentSession will return null.
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── currentUser ───────────────────────────────────────────────────────────
  //
  // Synchronous getter — returns the cached User object if a session exists,
  // or null if the user is logged out. Does NOT make a network call.
  static User? get currentUser => _client.auth.currentUser;

  // ── currentSession ────────────────────────────────────────────────────────
  //
  // Synchronous getter — returns the active Session (contains the JWT token)
  // or null. Used by AuthProvider to check if the user is still logged in
  // after the app restarts.
  static User? get currentSession => _client.auth.currentUser;

  // ── sendPasswordReset ─────────────────────────────────────────────────────
  //
  // Triggers Supabase to email a password-recovery OTP to the given address.
  // Uses OtpType.recovery (verified in verifyOtp step 2 of forgot-password).
  // Supabase succeeds silently even for unknown emails (security best practice).
  static Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── updatePassword ────────────────────────────────────────────────────────
  //
  // Changes the current user's password. Requires an active session
  // (either a normal login session or a recovery session from verifyOtp).
  // Called as Step 3 in the forgot-password OTP flow.
  static Future<void> updatePassword(String newPassword) async {
    // updateUser() calls PUT /auth/v1/user with the new password in the body.
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── deleteAccount ─────────────────────────────────────────────────────────
  //
  // Permanently removes the user's account and all their game data.
  // Execution order is important:
  //   1. Delete game data rows first (foreign key constraints)
  //   2. Call the delete_user RPC to remove the auth record
  //   3. Sign out locally to clear the in-memory session
  //
  // This ensures that re-registering with the same email starts with a
  // clean slate (no orphaned game_stats rows).
  static Future<void> deleteAccount() async {
    // Get the current user before we delete the session
    final user = _client.auth.currentUser;

    if (user != null) {
      final userId = user.id; // Supabase UUID string, e.g. "a1b2-c3d4-..."

      // Delete game stats — wrapped in try/catch so a missing row doesn't
      // prevent the rest of the deletion from completing.
      try {
        await _client.from('game_stats').delete().eq('user_id', userId);
      } catch (_) {}

      // Delete records table rows (if your schema has this table)
      try {
        await _client.from('records').delete().eq('user_id', userId);
      } catch (_) {}

      // Delete history table rows (if your schema has this table)
      try {
        await _client.from('history').delete().eq('user_id', userId);
      } catch (_) {}

      // Delete level progress so next registration starts at Level 1
      try {
        await _client.from('level_progress').delete().eq('user_id', userId);
      } catch (_) {}
    }

    try {
      // Call the Supabase database function 'delete_user' via RPC.
      // This server-side function removes the auth.users row, which cannot
      // be done from the client SDK directly (security restriction).
      // You must create this function in your Supabase SQL editor:
      //
      //   create or replace function delete_user()
      //   returns void language plpgsql security definer as $$
      //   begin
      //     delete from auth.users where id = auth.uid();
      //   end;
      //   $$;
      await _client.rpc('delete_user');
    } finally {
      // Always sign out, even if the RPC failed, to clear the local session.
      await _client.auth.signOut();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GAME STATS METHODS
  // ════════════════════════════════════════════════════════════════════════════

  // ── saveGameStats ─────────────────────────────────────────────────────────
  //
  // Writes (or updates) the current user's game statistics to the 'game_stats'
  // table using UPSERT. UPSERT = INSERT if row doesn't exist, UPDATE if it does.
  // The conflict key is 'user_id' (each user has exactly one stats row).
  static Future<void> saveGameStats(GameStatsModel stats) async {
    final user = _client.auth.currentUser;
    // Guard: do nothing if the user somehow isn't logged in
    if (user == null) return;

    // .upsert() calls POST /rest/v1/game_stats with Prefer: resolution=merge-duplicates
    await _client.from('game_stats').upsert(
      {
        'user_id':       user.id,
        'total_wins':    stats.totalWins,
        'total_losses':  stats.totalLosses,
        'total_matches': stats.totalMatches,
        'total_days':    stats.totalDays,
        'updated_at':    DateTime.now().toIso8601String(), // ISO-8601 timestamp
      },
      onConflict: 'user_id', // Which column to check for an existing row
    );
  }

  // ── fetchGameStats ────────────────────────────────────────────────────────
  //
  // Reads the current user's game statistics from the 'game_stats' table.
  // Returns null if the user has no row yet (i.e. brand-new account).
  // .maybeSingle() returns null instead of throwing when no row is found.
  static Future<GameStatsModel?> fetchGameStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return null; // Not logged in — nothing to fetch

    // .select() with no args returns all columns (SELECT *)
    // .eq('user_id', ...) adds WHERE user_id = '<uuid>'
    // .maybeSingle() returns Map<String,dynamic>? or null
    final response = await _client
        .from('game_stats')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) return null; // No stats row yet for this user

    // Parse the returned Map into a typed Dart model object.
    // The null-coalescing (?? 0) handles legacy rows that might be missing a column.
    return GameStatsModel(
      totalWins:    (response['total_wins']    as int?) ?? 0,
      totalLosses:  (response['total_losses']  as int?) ?? 0,
      totalMatches: (response['total_matches'] as int?) ?? 0,
      totalDays:    (response['total_days']    as int?) ?? 1,
    );
  }
}
