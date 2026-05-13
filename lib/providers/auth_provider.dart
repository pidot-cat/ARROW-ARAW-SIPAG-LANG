// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../services/supabase_service.dart';
import '../services/level_unlock_service.dart';

/// AuthProvider — Central authentication state manager.
///
/// FIX: Removed GameProvider dependency entirely.
/// The old code injected GameProvider via a constructor param AND a setter
/// (_gameProvider), which caused:
///   1. "undefined_setter '_gameProvider'" compile error in main.dart
///   2. "prefer_final_fields" lint warning in auth_provider.dart
///
/// GameProvider already has its own Supabase auth state listener
/// (_setupAuthStateListener) that auto-refreshes stats when the user
/// changes. AuthProvider does NOT need to call gameProvider.refreshStats()
/// — GameProvider handles that itself.
class AuthProvider with ChangeNotifier {
  String _username = '';
  bool _isLoggedIn = false;
  bool _isReady = false;

  String get username => _username;
  bool get isLoggedIn => _isLoggedIn;
  bool get isReady => _isReady;

  // FIX: Constructor takes NO arguments. No GameProvider injection.
  AuthProvider() {
    _loadAuthState();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOT-TIME AUTH CHECK
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString(AppConstants.keyUsername) ?? '';
      final user = SupabaseService.currentUser;

      if (user != null) {
        _isLoggedIn = true;
        _username = user.userMetadata?['username'] ?? _username;
        await prefs.setBool(AppConstants.keyIsLoggedIn, true);
        await prefs.setString(AppConstants.keyUsername, _username);
      } else {
        _isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
      }
    } catch (e) {
      debugPrint('[AuthProvider] _loadAuthState error: $e');
      _isLoggedIn = false;
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN UP
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> signUp(String email, String password, String username) async {
    try {
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }
      if (username.trim().length < 3) {
        return 'Username must be at least 3 characters.';
      }
      if (password.length < 8) {
        return 'Password must be at least 8 characters.';
      }

      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );

      if (response.user != null) {
        if (response.session != null) {
          await _handleLoginSuccess(response.user!, username);
          return null;
        } else {
          return 'OTP_REQUIRED';
        }
      }

      return 'Sign up failed — no user returned. Check your Supabase project settings.';
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] signUp AuthException: ${e.message}');
      return e.message;
    } catch (e, stack) {
      debugPrint('[AuthProvider] signUp unexpected error: $e');
      debugPrint(stack.toString());
      return 'Sign up error: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFY OTP
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> verifySignupOtp(
      String email, String token, String username) async {
    try {
      final response = await SupabaseService.verifyOtp(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      if (response.user != null && response.session != null) {
        await _handleLoginSuccess(response.user!, username);
        return null;
      }

      return 'Invalid or expired code. Please try again.';
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] verifySignupOtp AuthException: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('[AuthProvider] verifySignupOtp error: $e');
      return 'Failed to verify code: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESEND OTP
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> resendSignupOtp(String email) async {
    try {
      await SupabaseService.resendOtp(email: email, type: OtpType.signup);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to resend code: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> login(String email, String password) async {
    try {
      final response = await SupabaseService.signIn(email, password);

      if (response.user != null && response.session != null) {
        final username =
            response.user!.userMetadata?['username'] ?? email.split('@')[0];
        await _handleLoginSuccess(response.user!, username);
        return null;
      }
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] login AuthException: ${e.message}');
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'EMAIL_NOT_CONFIRMED';
      }
      return e.message;
    } catch (e) {
      debugPrint('[AuthProvider] login error: $e');
      final err = e.toString();
      if (err.contains('SocketException') ||
          err.contains('Failed host lookup') ||
          err.contains('ClientException')) {
        return 'No internet connection. Please check your network and try again.';
      }
      return 'Login failed. Please try again.';
    }

    return 'Login failed. Please check your credentials and try again.';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORGOT PASSWORD
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> sendPasswordReset(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return 'Please enter a valid email address.';
      }
      await SupabaseService.sendPasswordReset(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to send reset email: ${e.toString()}';
    }
  }

  Future<String?> verifyRecoveryOtp(String email, String token) async {
    try {
      final response = await SupabaseService.verifyOtp(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return (response.user != null && response.session != null)
          ? null
          : 'Invalid or expired code. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Verification failed: ${e.toString()}';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await SupabaseService.updatePassword(newPassword);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to update password: ${e.toString()}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGOUT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> logout() async {
    try {
      // FIX: Clear local data BEFORE signing out so GameProvider's auth
      // state listener sees a clean slate when it fires on signOut.
      await _clearAllUserData();
      await SupabaseService.signOut();
      await LevelUnlockService.instance.resetProgress();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUsername);
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);

      _username = '';
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] logout error: $e');
      // Still clear local state even if network fails
      _username = '';
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE ACCOUNT
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> deleteAccount(String password) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        return 'Not logged in.';
      }

      final email = user.email ?? '';
      if (email.isEmpty) {
        return 'Unable to verify account.';
      }

      final reAuth = await SupabaseService.signIn(email, password);
      if (reAuth.user == null) {
        return 'Incorrect password. Please try again.';
      }

      await SupabaseService.deleteAccount();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUsername);
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);
      _username = '';
      _isLoggedIn = false;
      notifyListeners();
      return null;
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

  Future<void> _clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyTotalWins, 0);
    await prefs.setInt(AppConstants.keyTotalLosses, 0);
    await prefs.setInt(AppConstants.keyTotalMatches, 0);
    await prefs.setInt(AppConstants.keyTotalDays, 1);
    debugPrint('[AuthProvider] All user data cleared from SharedPreferences');
  }

  Future<void> _handleLoginSuccess(User user, String username) async {
    // Step 1 — Wipe any previous account's cached stats from SharedPreferences.
    // GameProvider reads SharedPreferences as a fallback; zeroing it here
    // prevents the previous account's data from briefly appearing on screen.
    await _clearAllUserData();

    // Step 2 — Reset level progress cache so the correct user's levels load.
    await LevelUnlockService.instance.resetProgress();

    // Step 3 — Persist the new user's identity.
    _username = username;
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUsername, _username);
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);

    // NOTE: We do NOT call gameProvider.refreshStats() here anymore.
    // GameProvider._setupAuthStateListener() listens to Supabase's own
    // onAuthStateChange stream and calls refreshStats() automatically
    // when a new user signs in. This avoids the circular dependency
    // between AuthProvider and GameProvider.

    notifyListeners();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }
}
