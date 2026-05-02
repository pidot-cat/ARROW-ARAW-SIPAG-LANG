// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/login_screen.dart
// Authenticates an existing user via email and password using Supabase Auth.
// Delegates the sign-in call to [AuthProvider.signIn()] and navigates to
// HomeScreen on success, or displays an inline error message on failure.
// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/login_screen.dart
// Login screen — validates email/password then calls AuthProvider.login().
// UI FIX: Password field now uses GradientInputField with showToggle:true
//         so it has the same silver-grey background as the Email field.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/background_wrapper.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_input_field.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    // Stop ALL audio on Login screen — no ghost music during authentication
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioService.stopAll();
    });
  }

  // Controllers hold the text the user types
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false; // Shows spinner while waiting for Supabase

  @override
  void dispose() {
    // Always dispose controllers to free memory
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Login Handler ──────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Basic empty-field guard before hitting the network
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Input Email and Password', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // Call AuthProvider which wraps Supabase signInWithPassword()
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      // null = success → go to home
      Navigator.pushReplacementNamed(context, '/home');
    } else if (result == 'EMAIL_NOT_CONFIRMED') {
      // Special signal: user registered but never verified their email
      _showSnackBar(
          'Email not confirmed. Please check your inbox or sign up again.',
          Colors.red);
    } else {
      // All other Supabase errors (wrong password, rate limit, etc.)
      _showSnackBar(result, Colors.red);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleForgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BackgroundWrapper(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: size.height * 0.06),

                // App logo
                Image.asset(
                  AppConstants.logoWithBg,
                  width: size.width * 0.38,
                  height: size.width * 0.38,
                ),
                SizedBox(height: size.height * 0.025),

                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.075,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: size.height * 0.006),
                Text(
                  'Login to continue your adventure',
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
                    fontSize: size.width * 0.038,
                  ),
                ),
                SizedBox(height: size.height * 0.045),

                // ── Email field ──────────────────────────────────────────────
                GradientInputField(
                  hintText: 'Email',
                  controller: _emailController,
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: size.height * 0.022),

                // ── Password field ───────────────────────────────────────────
                // UI FIX: Uses GradientInputField (silver-grey) instead of a
                // hard-coded blue Container, matching the Email field above.
                // showToggle:true adds the eye icon for show/hide password.
                GradientInputField(
                  hintText: 'Password',
                  controller: _passwordController,
                  prefixIcon: Icons.lock,
                  obscureText: true,    // starts hidden
                  showToggle: true,     // eye icon to reveal/hide
                ),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.cyan, fontSize: 13),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.018),

                // Spinner while loading, button otherwise
                _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan))
                    : GradientButton(text: 'LOGIN', onPressed: _handleLogin),

                SizedBox(height: size.height * 0.022),

                // Sign-up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.white.withAlpha(128)),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                            color: Colors.cyan, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
