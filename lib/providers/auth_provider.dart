// ============================================================
// lib/providers/auth_provider.dart
// ============================================================
//
// PURPOSE:
//   AuthProvider is the "brain" of authentication in this app.
//   It sits between the UI screens and SupabaseService, managing:
//     • What the current auth state is (logged in / logged out)
//     • Who the current user is (their username)
//     • Performing all sign-up, login, logout, and password operations
//     • Persisting login state to SharedPreferences for offline resilience
//
// DESIGN PATTERN — ChangeNotifier:
//   This class extends ChangeNotifier (from Flutter's provider package).
//   When auth state changes (login/logout), notifyListeners() is called,
//   which triggers any widget listening via Provider.of<AuthProvider>()
//   or context.watch<AuthProvider>() to rebuild automatically.
//
// NULL CONVENTION (important for understanding the code):
//   Every public method returns:
//     null   → Operation succeeded (caller should navigate / update UI)
//     String → A human-readable error message to show to the user
//   This pattern avoids throwing exceptions into the UI layer.
//
// WHY THIS FILE WAS CHANGED (for instructor):
//   The original 'unexpected_failure' error was caused by the Supabase
//   Dashboard having "Confirm email" ON but no working SMTP configured.
//   However the provider also had a second issue: all non-AuthException
//   errors were swallowed by a generic catch block that returned a fixed
//   "unexpected_failure" string — hiding the REAL error from the developer.
//
//   This version:
//     1. Prints the real exception to the debug console (debugPrint).
//     2. Returns the actual error text to the UI so it is visible on screen.
//     3. Correctly interprets the 'OTP_REQUIRED' signal so the signup screen
//        knows to reveal the 6-digit code input field.
//
// ============================================================

// dart:async is needed for the Timer used in the OTP resend countdown.
// (Note: the Timer lives in SignUpScreen; this file doesn't use it directly,
//  but it's shown here for completeness of the import documentation.)

// flutter/material.dart — needed for ChangeNotifier, debugPrint.
import 'package:flutter/material.dart';

// shared_preferences — lightweight key-value storage that survives app restarts.
// Used to remember whether the user was logged in after the app is closed.
import 'package:shared_preferences/shared_preferences.dart';

// supabase_flutter — gives us the AuthException type and User class.
// We import it here so we can catch AuthException separately from generic errors.
import 'package:supabase_flutter/supabase_flutter.dart';

// AppConstants — holds SharedPreferences key names so we don't use raw strings.
import '../utils/constants.dart';

// SupabaseService — our backend wrapper; every Supabase call goes through it.
import '../services/supabase_service.dart';

// LevelUnlockService — reset local level-progress cache on logout/new-user.
import '../services/level_unlock_service.dart';

/// AuthProvider — Central authentication state manager.
///
/// Widgets listen to this provider to know if the user is logged in,
/// who they are, and whether the boot-time auth check has completed.
class AuthProvider with ChangeNotifier {

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC STATE FIELDS
  // ══════════════════════════════════════════════════════════════════════════

  // The logged-in user's display name (e.g. "Maria").
  // Empty string when logged out.
  String _username = '';

  // True when the user has an active Supabase session.
  // Widgets guard navigation with this flag (e.g. SplashScreen → /home or /login).
  bool _isLoggedIn = false;

  // False until _loadAuthState() completes. The SplashScreen waits for this
  // to become true before deciding where to navigate. Prevents the app from
  // flashing the login screen for a user who is already authenticated.
  bool _isReady = false;

  // Public getters — expose private state as read-only to the outside world.
  String get username   => _username;
  bool   get isLoggedIn => _isLoggedIn;
  bool   get isReady    => _isReady;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  // Called once when the Provider creates this object (usually at app startup).
  // Immediately kicks off the async auth check so the rest of the app doesn't
  // have to wait for it explicitly.
  AuthProvider() {
    _loadAuthState();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOT-TIME AUTH CHECK
  // ══════════════════════════════════════════════════════════════════════════

  /// Checks whether Supabase already has a valid session from a previous launch.
  ///
  /// Two sources of truth:
  ///   1. SupabaseService.currentUser — live Supabase session stored in memory
  ///   2. SharedPreferences — persisted login flag for offline use
  ///
  /// This method runs exactly once at startup. When it finishes, it sets
  /// _isReady = true and calls notifyListeners(), which unblocks SplashScreen.
  Future<void> _loadAuthState() async {
    try {
      // Open the SharedPreferences store (async disk read).
      final prefs = await SharedPreferences.getInstance();

      // Restore the username we cached during the last successful login.
      // Falls back to empty string if no cached value exists.
      _username = prefs.getString(AppConstants.keyUsername) ?? '';

      // Check if Supabase has an active in-memory session.
      // This is fast — it does NOT make a network request.
      final user = SupabaseService.currentUser;

      if (user != null) {
        // A live Supabase session exists — user is confirmed authenticated.
        _isLoggedIn = true;

        // Prefer the metadata username (authoritative) over the cached one.
        _username = user.userMetadata?['username'] ?? _username;

        // Keep SharedPreferences in sync so the offline path is always current.
        await prefs.setBool(AppConstants.keyIsLoggedIn, true);
        await prefs.setString(AppConstants.keyUsername, _username);
      } else {
        // No live session — fall back to whatever was persisted last time.
        // This handles the case where the app is opened offline after a
        // previous successful login.
        _isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
      }
    } catch (e) {
      // If anything goes wrong (corrupted prefs, disk error), default to
      // logged-out so the user can log in again safely.
      debugPrint('[AuthProvider] _loadAuthState error: $e');
      _isLoggedIn = false;
    } finally {
      // 'finally' always runs, even if the try block threw an exception.
      // Mark the provider as ready and notify all listening widgets.
      _isReady = true;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN UP — Step 1: Create account & request OTP
  // ══════════════════════════════════════════════════════════════════════════

  /// Registers a new account in Supabase and requests a 6-digit OTP email.
  ///
  /// Returns:
  ///   null            → "Confirm email" is OFF in Supabase Dashboard.
  ///                     User is logged in immediately. Caller navigates to /home.
  ///   'OTP_REQUIRED'  → "Confirm email" is ON. Supabase sent a 6-digit code.
  ///                     Caller should reveal the OTP input field.
  ///   String (error)  → Something went wrong. Show this text to the user.
  ///
  /// HOW THE "unexpected_failure" WAS EXPOSED AND FIXED:
  ///   Before this fix, the catch block returned a generic string, hiding the
  ///   real error. Now it returns e.toString() so the actual Supabase message
  ///   ("Error sending confirmation email") appears on screen. This told us
  ///   the problem was the Supabase SMTP config, not the Dart code.
  Future<String?> signUp(
      String email, String password, String username) async {
    try {
      // ── Client-side validation ─────────────────────────────────────────────
      // These checks run locally — no network request needed.
      // Failing fast here avoids burning through Supabase's rate limits.
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }
      if (username.trim().length < 3) {
        return 'Username must be at least 3 characters.';
      }
      if (password.length < 8) {
        return 'Password must be at least 8 characters.';
      }

      // ── Call Supabase via the service layer ────────────────────────────────
      // SupabaseService.signUp() passes emailRedirectTo so Supabase knows
      // this is an OTP flow (not a magic-link flow). This is a key part of
      // the fix — without emailRedirectTo, Supabase uses the wrong email
      // template and can fail with "unexpected_failure".
      final response = await SupabaseService.signUp(
        email:    email,
        password: password,
        username: username,
      );

      // ── Interpret the Supabase response ────────────────────────────────────
      //
      // Supabase's signUp() always returns an AuthResponse.
      // The combination of .user and .session tells us the outcome:
      //
      //   user != null && session != null → "Confirm email" is OFF
      //                                    → User authenticated instantly
      //
      //   user != null && session == null → "Confirm email" is ON
      //                                    → Email sent, waiting for OTP
      //
      //   user == null                    → Something unexpected happened
      if (response.user != null) {
        if (response.session != null) {
          // "Confirm email" is OFF in the Supabase Dashboard.
          // A full session was created — log the user in right now.
          await _handleLoginSuccess(response.user!, username);
          return null; // null = success → caller navigates to /home
        } else {
          // "Confirm email" is ON.
          // Supabase sent a 6-digit OTP to the email address.
          // Return the sentinel string so SignUpScreen reveals the code field.
          return 'OTP_REQUIRED';
        }
      }

      // Supabase returned HTTP 200 but .user is null — misconfigured project.
      // This can happen if Auth is disabled in the project settings.
      return 'Sign up failed — no user returned. '
          'Check your Supabase project settings.';

    } on AuthException catch (e) {
      // AuthException is thrown by the Supabase SDK for known auth errors,
      // e.g. "User already registered", "Password too short", etc.
      // e.message is a human-readable string we can show directly.
      debugPrint('[AuthProvider] signUp AuthException: ${e.message}');
      return e.message;

    } catch (e, stack) {
      // KEY FIX — this catch block previously returned a hardcoded
      // 'Unexpected Failure' string, hiding the real error from the developer.
      //
      // Now it:
      //   1. Prints the full error and stack trace to the debug console
      //      so you can see it in Android Studio / VS Code output.
      //   2. Returns the actual error text so it appears in the UI SnackBar.
      //
      // Common causes of errors landing here:
      //   • "Error sending confirmation email" → Supabase SMTP not configured
      //     → FIX: Disable "Confirm email" in Dashboard, or add custom SMTP
      //   • SocketException → No internet connection on the device
      //   • Invalid URL / anon key → Wrong values in main.dart Supabase.initialize()
      //   • Project paused → Free-tier Supabase projects pause after 1 week idle
      debugPrint('[AuthProvider] signUp unexpected error: $e');
      debugPrint(stack.toString());

      // Show the actual error text in the UI during development.
      // This is what revealed "Error sending confirmation email" as the root cause.
      return 'Sign up error: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN UP — Step 2: Verify the 6-digit OTP
  // ══════════════════════════════════════════════════════════════════════════

  /// Confirms the user's email by verifying the OTP code they received.
  ///
  /// This is only called when "Confirm email" is ON in Supabase Dashboard.
  /// On success, Supabase returns a full session and the user is logged in.
  ///
  /// The type parameter MUST be OtpType.signup here.
  /// Using OtpType.recovery (the forgot-password type) would always fail,
  /// even if the code is correct — Supabase issues different tokens per type.
  Future<String?> verifySignupOtp(
      String email, String token, String username) async {
    try {
      // Call SupabaseService which calls client.auth.verifyOTP()
      final response = await SupabaseService.verifyOtp(
        email: email,
        token: token,
        type:  OtpType.signup, // CRITICAL: must match the OTP type that was sent
      );

      if (response.user != null && response.session != null) {
        // Both user and session present → account confirmed, fully authenticated
        await _handleLoginSuccess(response.user!, username);
        return null; // null = success → caller navigates to /home
      }

      // Missing user or session after verifyOTP — code was wrong or expired.
      return 'Invalid or expired code. Please try again.';

    } on AuthException catch (e) {
      // Common AuthExceptions here:
      //   "Token has expired or is invalid" — code is wrong or >10 minutes old
      //   "OTP type mismatch"              — wrong OtpType passed (see above)
      debugPrint('[AuthProvider] verifySignupOtp AuthException: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('[AuthProvider] verifySignupOtp error: $e');
      return 'Failed to verify code: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN UP — Resend OTP
  // ══════════════════════════════════════════════════════════════════════════

  /// Asks Supabase to email a fresh OTP to the same address.
  ///
  /// Called when the user taps "Resend" after the 60-second countdown ends.
  /// The SignUpScreen's timer prevents spam by locking the button for 60s.
  ///
  /// Supabase rate-limits resend requests (5/hour on free tier).
  /// An AuthException is thrown if the limit is exceeded.
  Future<String?> resendSignupOtp(String email) async {
    try {
      // Delegate to the service which calls client.auth.resend()
      await SupabaseService.resendOtp(email: email, type: OtpType.signup);
      return null; // null = success → SignUpScreen restarts the 60s countdown
    } on AuthException catch (e) {
      return e.message; // e.g. "Rate limit exceeded"
    } catch (e) {
      return 'Failed to resend code: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ══════════════════════════════════════════════════════════════════════════

  /// Authenticates an existing user with email and password.
  ///
  /// Special return values:
  ///   null                   → Success — caller navigates to /home
  ///   'EMAIL_NOT_CONFIRMED'  → User registered but never verified OTP.
  ///                            LoginScreen shows a targeted error message.
  ///   String (other error)   → Show to user in a SnackBar.
  Future<String?> login(String email, String password) async {
    try {
      // signInWithPassword() validates credentials against Supabase Auth DB.
      // On success: returns AuthResponse with .user and .session both set.
      // On failure: throws AuthException (e.g. "Invalid login credentials").
      final response = await SupabaseService.signIn(email, password);

      if (response.user != null && response.session != null) {
        // Successful login — extract the username from user metadata.
        // Falls back to the part of the email before '@' if none stored.
        final username =
            response.user!.userMetadata?['username'] ?? email.split('@')[0];
        await _handleLoginSuccess(response.user!, username);
        return null; // Success → caller navigates to /home
      }
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] login AuthException: ${e.message}');

      // Special case: user registered but didn't verify OTP.
      // We surface a specific token so LoginScreen can show a helpful message
      // like "Please check your email for a verification code."
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'EMAIL_NOT_CONFIRMED';
      }
      return e.message; // e.g. "Invalid login credentials"
    } catch (e) {
      debugPrint('[AuthProvider] login error: $e');
      return 'Login failed: ${e.toString()}';
    }

    // Fallback if user or session were null without throwing
    return 'Login failed. Please check your credentials and try again.';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORGOT PASSWORD (3-step OTP recovery flow)
  // ══════════════════════════════════════════════════════════════════════════

  /// Step 1 — Request a password-reset OTP.
  ///
  /// Calls Supabase resetPasswordForEmail() which emails a 6-digit code.
  ///
  /// DASHBOARD SETTING:
  ///   Authentication → Email Templates → "Reset Password"
  ///   The template body must contain {{ .Token }} (the 6-digit code),
  ///   NOT the default magic-link URL. If it still uses a URL, the user
  ///   receives a link instead of a code and this flow won't work.
  Future<String?> sendPasswordReset(String email) async {
    try {
      if (!_isValidEmail(email)) return 'Please enter a valid email address.';
      // Supabase silently succeeds even for unregistered emails (security best
      // practice — prevents email enumeration attacks).
      await SupabaseService.sendPasswordReset(email);
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to send reset email: ${e.toString()}';
    }
  }

  /// Step 2 — Verify the recovery OTP.
  ///
  /// CRITICAL: Uses OtpType.recovery, NOT OtpType.signup.
  /// Supabase issues different token types for different flows.
  /// Mixing them up causes "invalid token" errors even with the right code.
  ///
  /// On success, Supabase creates a "recovery session" that allows Step 3
  /// (updatePassword) to run without the user's current password.
  Future<String?> verifyRecoveryOtp(String email, String token) async {
    try {
      final response = await SupabaseService.verifyOtp(
        email: email,
        token: token,
        type:  OtpType.recovery, // Different from OtpType.signup on purpose
      );
      // Both must be present: user confirms identity, session grants update access
      return (response.user != null && response.session != null)
          ? null // Success
          : 'Invalid or expired code. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Verification failed: ${e.toString()}';
    }
  }

  /// Step 3 — Save the new password.
  ///
  /// Requires the recovery session from Step 2.
  /// If the session expired (e.g. took too long), this will throw AuthException.
  Future<String?> updatePassword(String newPassword) async {
    try {
      await SupabaseService.updatePassword(newPassword);
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to update password: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGOUT
  // ══════════════════════════════════════════════════════════════════════════

  /// Signs out the user from Supabase and clears all locally persisted state.
  ///
  /// After this:
  ///   • SupabaseService.currentUser returns null
  ///   • SharedPreferences no longer contains username or login flag
  ///   • _isLoggedIn = false → any guarded route redirects to /login
  ///   • notifyListeners() → Navigator guard rebuilds and redirects
  Future<void> logout() async {
    try {
      // Invalidate the Supabase JWT token on the server.
      await SupabaseService.signOut();

      // Hard Reset: clear local level-progress cache so the next account
      // that logs in on this device always starts from Level 1.
      await LevelUnlockService.instance.resetProgress();

      // Clear the persisted login data from the device's local storage.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUsername);
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);

      // Reset in-memory state.
      _username   = '';
      _isLoggedIn = false;

      // Tell all listening widgets to rebuild (e.g. HomeScreen, SplashScreen).
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] logout error: $e');
      // Even if Supabase signOut fails (no internet), clear local state anyway
      // so the user isn't stuck in a logged-in state on their device.
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE ACCOUNT
  // ══════════════════════════════════════════════════════════════════════════

  /// Permanently deletes the account after re-verifying the user's password.
  ///
  /// Re-authentication step prevents accidental or unauthorized deletions.
  /// After deletion the user is signed out and state is cleared locally.
  Future<String?> deleteAccount(String password) async {
    try {
      // Get the currently logged-in user
      final user = SupabaseService.currentUser;
      if (user == null) return 'Not logged in.';

      final email = user.email ?? '';
      if (email.isEmpty) return 'Unable to verify account.';

      // Re-authenticate: confirm the person deleting knows the password.
      // This is a security gate — prevents other people deleting accounts.
      final reAuth = await SupabaseService.signIn(email, password);
      if (reAuth.user == null) return 'Incorrect password. Please try again.';

      // Delete game data rows and then the auth account (via RPC delete_user).
      await SupabaseService.deleteAccount();

      // Clear local storage and in-memory state, then notify listeners.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUsername);
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);
      _username   = '';
      _isLoggedIn = false;
      notifyListeners();
      return null; // null = success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('[AuthProvider] deleteAccount error: $e');
      return 'Failed to delete account: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Stores auth data both in memory and in SharedPreferences, then notifies
  /// all listening widgets that the state has changed.
  ///
  /// Called by every successful auth operation: signUp, verifySignupOtp, login.
  ///
  /// ACCOUNT ISOLATION: resetProgress() clears the local SharedPreferences
  /// level-unlock cache. On first load, LevelUnlockService.loadHighestUnlocked()
  /// will then query Supabase for THIS user's real progress — guaranteeing that
  /// no data bleeds over from a previously logged-in tester account.
  Future<void> _handleLoginSuccess(User user, String username) async {
    // Clear the local level-unlock cache so this user's Supabase row is
    // authoritative (prevents inheriting progress from the previous session).
    await LevelUnlockService.instance.resetProgress();

    final prefs = await SharedPreferences.getInstance();
    _username   = username;
    _isLoggedIn = true;
    // Persist to disk so the user stays logged in across app restarts.
    await prefs.setString(AppConstants.keyUsername, _username);
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
    // Rebuild all widgets that depend on isLoggedIn or username.
    notifyListeners();
  }

  /// Validates an email address format using a standard RegEx pattern.
  ///
  /// Used before making any network call so we fail fast on obvious typos.
  /// The regex checks for: local@domain.tld (at least 2-char TLD).
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }
}
