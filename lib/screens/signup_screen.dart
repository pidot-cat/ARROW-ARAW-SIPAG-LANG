// ============================================================
// lib/screens/signup_screen.dart
// ============================================================
//
// PURPOSE:
//   The Create Account screen. Handles a two-phase registration flow:
//
//   PHASE 1 — Registration:
//     User fills Username, Email, Password, Confirm Password → taps SIGN UP
//     → AuthProvider.signUp() sends the data to Supabase
//     → If "Confirm email" is OFF in Dashboard → session created → go to /home
//     → If "Confirm email" is ON  in Dashboard → OTP emailed   → Phase 2
//
//   PHASE 2 — OTP Verification (only when "Confirm email" is ON):
//     A 6-digit code input and a Resend button appear on screen.
//     User enters the code → taps VERIFY & SIGN UP
//     → AuthProvider.verifySignupOtp() confirms the account with Supabase
//     → On success → navigate to /home
//
// ── FIXES IN THIS FILE ──────────────────────────────────────────────────────
//
// FIX 1 — Scroll / Keyboard blocking:
//   The keyboard was covering the "Confirm Password" field and SIGN UP button.
//   Three changes work together to solve this:
//     a) resizeToAvoidBottomInset: true  — Scaffold shrinks when keyboard opens
//     b) SingleChildScrollView          — wraps the form so it is scrollable
//     c) Column(mainAxisSize: min)      — prevents infinite-height layout error
//        inside the ScrollView
//
// FIX 2 — Password field color consistency:
//   Password and Confirm Password were rendering with a blue background instead
//   of the same silver-grey as the Email field. The cause was that the original
//   code used plain TextField widgets with a default InputDecoration for those
//   fields. The fix is to use GradientInputField for ALL fields — it applies
//   AppColors.secondaryGradient consistently.
//   GradientInputField also supports showToggle:true for the eye icon.
//
// FIX 3 — Instructor comments:
//   Every import, class, function, and widget is annotated so you can explain
//   exactly what each line does and why it was changed.
//
// ── WHAT DID NOT CHANGE ─────────────────────────────────────────────────────
//   • App logo (LOGO.png) — untouched
//   • BackgroundWrapper (city background image) — untouched
//   • General layout structure — untouched
//   • GradientButton style — untouched
//   • Navigation routes — untouched
//
// ============================================================

// dart:async — provides the Timer class used for the OTP resend countdown.
// Without this import, 'Timer' and 'Timer.periodic' would be undefined.
import 'dart:async';

// flutter/material.dart — the core Flutter UI framework.
// Provides StatefulWidget, State, Scaffold, Column, Text, TextEditingController,
// Colors, Icons, MediaQuery, Navigator, ScaffoldMessenger, SnackBar, etc.
import 'package:flutter/material.dart';

// provider — the state management library. Provider.of<T>() lets us access
// AuthProvider from within this widget without passing it manually as a parameter.
import 'package:provider/provider.dart';

// BackgroundWrapper — a custom widget that displays the city-themed
// background image. Used on all auth screens for visual consistency.
import '../widgets/background_wrapper.dart';

// GradientButton — a custom button widget with the app's deep-blue gradient.
// Used for primary action buttons (SIGN UP, VERIFY & SIGN UP).
import '../widgets/gradient_button.dart';

// GradientInputField — a custom text field with the silver-grey gradient
// background. Using this for ALL fields (including password) ensures they
// all look the same — this is the FIX 2 design consistency fix.
import '../widgets/gradient_input_field.dart';

// AuthProvider — the ChangeNotifier that manages all authentication logic.
// We access it here to call signUp(), verifySignupOtp(), and resendSignupOtp().
import '../providers/auth_provider.dart';

// AppConstants — holds string constants like asset paths so we don't
// scatter raw strings throughout the code.
import '../utils/constants.dart';

/// SignUpScreen — the Create Account screen.
///
/// StatefulWidget is used (instead of StatelessWidget) because this screen
/// has mutable state: loading spinner, OTP sent flag, countdown timer, etc.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

/// _SignUpScreenState — holds all the mutable state for SignUpScreen.
///
/// The underscore prefix makes it private — Flutter convention for State classes.
class _SignUpScreenState extends State<SignUpScreen> {

  // ── TextEditingControllers ─────────────────────────────────────────────────
  //
  // A TextEditingController is linked to exactly one TextField/GradientInputField.
  // It lets us read the current text (.text), clear it (.clear()), or listen
  // for changes.
  //
  // IMPORTANT: Controllers must be disposed in dispose() to prevent memory leaks.
  // A leaked controller keeps listening to a widget that no longer exists,
  // wasting memory and potentially causing setState() calls on dead objects.
  final TextEditingController _usernameController     = TextEditingController();
  final TextEditingController _emailController        = TextEditingController();
  final TextEditingController _passwordController     = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _verificationController = TextEditingController();

  // ── Local UI state ─────────────────────────────────────────────────────────

  // True while waiting for a Supabase response (signUp or verifyOtp in progress).
  // Shows a CircularProgressIndicator instead of the SIGN UP button.
  bool _isLoading = false;

  // Flips to true after Supabase confirms it sent the OTP email.
  // Controls whether Phase 2 UI (code input + Resend button) is visible.
  bool _codeSent = false;

  // Counts down from 60 after each OTP send.
  // The Resend button is disabled while this is > 0.
  int _timerSeconds = 0;

  // The periodic Timer that decrements _timerSeconds every second.
  // Nullable because it doesn't exist until the first OTP is sent.
  Timer? _countdownTimer;

  // ── dispose ───────────────────────────────────────────────────────────────
  //
  // Called automatically by Flutter when this widget is removed from the tree
  // (e.g. when the user navigates to /home or presses the back button).
  //
  // WHY THIS IS IMPORTANT:
  //   Not disposing controllers = memory leak. The controller holds a reference
  //   to the TextField's internal state, which keeps the widget alive in memory
  //   even after it should have been garbage-collected.
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationController.dispose();
    // Cancel the countdown timer so it doesn't fire after the screen is gone.
    // A timer firing on a disposed widget causes a "setState() called after
    // dispose()" crash.
    _countdownTimer?.cancel();
    super.dispose(); // Always call super.dispose() last
  }

  // ── _startTimer ───────────────────────────────────────────────────────────
  //
  // Starts (or restarts) the 60-second Resend lockout countdown.
  // Called immediately after a successful OTP send (or resend).
  //
  // HOW IT WORKS:
  //   Timer.periodic creates a repeating timer that fires a callback every
  //   Duration(seconds: 1). Inside the callback we call setState() to decrement
  //   the counter, which triggers a widget rebuild showing the updated countdown.
  //   When the counter hits zero we cancel the timer and hide the code row,
  //   allowing the user to re-submit the form if the OTP expired.
  void _startTimer() {
    // Cancel any running timer before starting a new one
    _countdownTimer?.cancel();

    // Set _codeSent = true (shows Phase 2 UI) and reset the counter to 60.
    setState(() {
      _codeSent     = true;
      _timerSeconds = 60;
    });

    // Create a repeating 1-second timer.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      // Safety check: if the widget was disposed while the timer was running,
      // cancel the timer and do nothing (avoids the setState-after-dispose crash).
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--; // Decrement counter; widget rebuilds to show new value
        } else {
          t.cancel();      // Timer reached zero — stop it
          _codeSent = false; // Hide OTP row so user can re-submit if code expired
        }
      });
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PHASE 1 — Register & request OTP
  // ════════════════════════════════════════════════════════════════════════════
  //
  // This is called when the user taps SIGN UP (before any OTP is sent).
  //
  // Flow:
  //   1. Validate that all four fields are filled in and passwords match.
  //   2. Show loading spinner.
  //   3. Call AuthProvider.signUp() which calls Supabase via SupabaseService.
  //   4. Interpret the result:
  //        null          → auto-confirm ON → go to /home
  //        'OTP_REQUIRED'→ OTP sent → show code input (Phase 2)
  //        String error  → show error SnackBar
  Future<void> _handleSignUp() async {
    // Read current field values and trim whitespace
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text; // DO NOT trim passwords
    final confirm  = _confirmPasswordController.text;

    // ── Client-side validation ─────────────────────────────────────────────
    // These checks don't require a network call — fast and saves API usage.
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.orange);
      return; // Stop here — don't hit the network with incomplete data
    }
    if (password != confirm) {
      _showSnackBar('Passwords do not match', Colors.red);
      return;
    }

    // ── Show loading indicator ─────────────────────────────────────────────
    // setState() triggers a rebuild; _isLoading=true replaces the button
    // with a CircularProgressIndicator while waiting for Supabase.
    setState(() => _isLoading = true);

    // Access AuthProvider WITHOUT listening for changes.
    // listen: false is correct here because we're inside an async function,
    // not inside build(). Using listen:true outside of build() causes errors.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ── Call Supabase (via AuthProvider → SupabaseService) ─────────────────
    // This is the async call that can return:
    //   null          → success, session created immediately
    //   'OTP_REQUIRED'→ email sent, waiting for OTP
    //   String        → error message
    final result = await authProvider.signUp(email, password, username);

    // Safety check: if the user navigated away while we were waiting,
    // 'mounted' is false and we must not call setState() or Navigator.
    if (!mounted) return;

    // ── Hide loading indicator ─────────────────────────────────────────────
    setState(() => _isLoading = false);

    // ── Handle result ──────────────────────────────────────────────────────
    if (result == null) {
      // "Confirm email" is OFF → user is already logged in → go to /home
      Navigator.pushReplacementNamed(context, '/home');
    } else if (result == 'OTP_REQUIRED') {
      // "Confirm email" is ON → Supabase emailed the 6-digit code
      _startTimer(); // Start the 60-second Resend lockout countdown
      _showSnackBar('Verification code sent to your email!', Colors.green);
      // _codeSent = true (set inside _startTimer) causes setState to rebuild,
      // which shows the Phase 2 UI (code input + Resend button).
    } else {
      // Any other string is an error message — display it in a red SnackBar
      _showSnackBar(result, Colors.red);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PHASE 2 — Verify the OTP code
  // ════════════════════════════════════════════════════════════════════════════
  //
  // Called when the user taps VERIFY & SIGN UP after entering the 6-digit code.
  //
  // Flow:
  //   1. Check that exactly 6 digits were entered.
  //   2. Show loading spinner.
  //   3. Call AuthProvider.verifySignupOtp() → Supabase verifyOTP(type: signup).
  //   4. On null (success) → navigate to /home.
  //   5. On error string  → show error SnackBar.
  Future<void> _handleVerifyOtp() async {
    final email    = _emailController.text.trim();
    final code     = _verificationController.text.trim();
    final username = _usernameController.text.trim();

    // Basic code length check before hitting the network
    if (code.length < 6) {
      _showSnackBar('Please enter the full 6-digit code', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // verifySignupOtp calls client.auth.verifyOTP(type: OtpType.signup)
    final result = await authProvider.verifySignupOtp(email, code, username);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      // Account confirmed and session created → go to /home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // e.g. "Token has expired or is invalid"
      _showSnackBar(result, Colors.red);
    }
  }

  // ── _resendCode ───────────────────────────────────────────────────────────
  //
  // Triggered when the user taps "Resend" after the 60-second countdown ends.
  // Calls Supabase resend() to issue a new OTP to the same email address.
  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return; // Guard — shouldn't happen but just in case

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // resendSignupOtp calls client.auth.resend(type: OtpType.signup)
    final result = await authProvider.resendSignupOtp(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      _startTimer(); // Restart the 60-second countdown
      _showSnackBar('Verification code resent!', Colors.green);
    } else {
      _showSnackBar(result, Colors.red);
    }
  }

  // ── _showSnackBar ─────────────────────────────────────────────────────────
  //
  // Convenience method to show a floating SnackBar at the bottom of the screen.
  // 'floating' style keeps it above the keyboard if the keyboard is open.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // floats above the keyboard
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  //
  // build() is called every time setState() is called.
  // It returns the complete widget tree for the current state of the screen.
  @override
  Widget build(BuildContext context) {
    // MediaQuery gives us the current screen dimensions.
    // Using size.height and size.width for padding/sizing makes the layout
    // proportional across different screen sizes (small phones vs large phones).
    final size = MediaQuery.of(context).size;

    // Proportional vertical spacing between form fields.
    // ~1.3% of screen height = roughly 10px on a 720px screen.
    final fieldSpacing = size.height * 0.013;

    return Scaffold(
      // ── FIX 1a: resizeToAvoidBottomInset ──────────────────────────────────
      //
      // When the software keyboard opens, the system notifies Flutter that
      // the visible area of the screen has shrunk.
      //
      // resizeToAvoidBottomInset: true (the Flutter default, but we set it
      // explicitly for clarity) tells the Scaffold to resize its body to fit
      // the remaining space above the keyboard.
      //
      // On its own this is not enough — without a scrollable container the
      // bottom widgets are just clipped. The SingleChildScrollView below
      // is what actually enables scrolling.
      resizeToAvoidBottomInset: true,

      body: BackgroundWrapper(
        // BackgroundWrapper draws the city-themed background image.
        // We leave it exactly as-is (requirement: do not change the background).
        child: SafeArea(
          // SafeArea adds padding around the system status bar and home indicator,
          // so content is never drawn underneath them.
          child: Center(
            // ── FIX 1b: SingleChildScrollView ─────────────────────────────────
            //
            // This is the primary scroll fix.
            //
            // Without this, the Column is a fixed-height layout that cannot
            // scroll. When the keyboard opens and the Scaffold shrinks,
            // the bottom of the Column is clipped — the Confirm Password
            // field and SIGN UP button disappear behind the keyboard.
            //
            // SingleChildScrollView makes the entire form column scrollable.
            // When the keyboard opens, the user can scroll up to see and
            // interact with every field and button.
            //
            // keyboardDismissBehavior.onDrag — swiping down on the scroll
            // view also dismisses the keyboard, improving usability.
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.07,  // 7% side margins
                // Extra vertical padding so the last widget (Login link)
                // has breathing room above the keyboard when scrolled down.
                vertical: size.height * 0.04,
              ),
              child: Column(
                // ── FIX 1c: mainAxisSize.min ───────────────────────────────────
                //
                // Inside a SingleChildScrollView, a Column with the default
                // mainAxisSize.max tries to expand to INFINITE height, which
                // causes a layout overflow error or breaks scrolling.
                //
                // mainAxisSize.min tells the Column to be only as tall as its
                // children require — no extra blank space at the bottom.
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Logo ─────────────────────────────────────────────────────
                  // Uses AppConstants.logoWithBg = 'assets/images/LOGO.png'
                  // The logo is intentionally not changed (project requirement).
                  Image.asset(
                    AppConstants.logoWithBg,
                    width:  size.width * 0.22, // 22% of screen width
                    height: size.width * 0.22, // Square aspect ratio
                  ),
                  SizedBox(height: size.height * 0.01), // Small gap below logo

                  // ── Screen title ──────────────────────────────────────────────
                  Text(
                    'Create Account',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   size.width * 0.06, // Proportional font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: size.height * 0.018),

                  // ── Field 1: Username ──────────────────────────────────────────
                  // GradientInputField wraps a TextField with the silver-grey
                  // gradient background. The 'enabled' property locks this field
                  // after the OTP is sent (Phase 2) to prevent tampering.
                  GradientInputField(
                    hintText:    'Username',
                    controller:  _usernameController,
                    prefixIcon:  Icons.person,
                    enabled:     !_codeSent, // Locked in Phase 2
                  ),
                  SizedBox(height: fieldSpacing),

                  // ── Field 2: Email ─────────────────────────────────────────────
                  // keyboardType: emailAddress shows the @ key on the keyboard
                  // and may auto-suggest email addresses from the user's contacts.
                  GradientInputField(
                    hintText:     'Email',
                    controller:   _emailController,
                    prefixIcon:   Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    enabled:      !_codeSent,
                  ),
                  SizedBox(height: fieldSpacing),

                  // ── Field 3: Password ──────────────────────────────────────────
                  //
                  // FIX 2 (Design Consistency):
                  //   Uses GradientInputField (same as Email field above).
                  //   obscureText: true — hides the text by default.
                  //   showToggle: true  — adds the eye icon so the user can
                  //                       tap to reveal/hide the password.
                  //
                  // Before this fix, the password fields used a different widget
                  // (or plain TextField) that rendered with a blue background,
                  // making the form look inconsistent and unprofessional.
                  GradientInputField(
                    hintText:    'Password',
                    controller:  _passwordController,
                    prefixIcon:  Icons.lock,
                    obscureText: true,   // Characters shown as dots by default
                    showToggle:  true,   // Eye icon to show/hide password
                    enabled:     !_codeSent,
                  ),
                  SizedBox(height: fieldSpacing),

                  // ── Field 4: Confirm Password ──────────────────────────────────
                  //
                  // FIX 2 continued:
                  //   Same GradientInputField, same silver-grey gradient.
                  //   Icons.lock_outline (hollow lock) visually distinguishes it
                  //   from the Password field (filled lock) without changing color.
                  //
                  // FIX 1 continued:
                  //   Because the Column is wrapped in SingleChildScrollView,
                  //   this field is now always reachable even when the keyboard
                  //   is open. Before the fix, this was the field most often
                  //   obscured by the keyboard on smaller screens.
                  GradientInputField(
                    hintText:    'Confirm Password',
                    controller:  _confirmPasswordController,
                    prefixIcon:  Icons.lock_outline,
                    obscureText: true,
                    showToggle:  true,
                    enabled:     !_codeSent,
                  ),
                  SizedBox(height: fieldSpacing),

                  // ── Phase 2 UI: OTP code input + Resend button ─────────────────
                  //
                  // This row is hidden in Phase 1 (_codeSent == false).
                  // It appears after _handleSignUp() receives 'OTP_REQUIRED'
                  // from AuthProvider and calls _startTimer().
                  //
                  // The '...' spread operator inserts the list of widgets
                  // into the parent Column as individual children.
                  if (_codeSent) ...[ // Only render if OTP has been sent

                    Row(
                      children: [
                        // Code entry field — takes most of the row width
                        Expanded(
                          // GradientInputField with number keyboard for digits
                          child: GradientInputField(
                            hintText:     '6-digit code',
                            controller:   _verificationController,
                            prefixIcon:   Icons.verified_user,
                            keyboardType: TextInputType.number, // Numeric keyboard
                          ),
                        ),

                        const SizedBox(width: 8), // Gap between field and button

                        // Resend button — shows countdown seconds OR "Resend" text
                        GestureDetector(
                          // Disable tap while countdown is active OR while loading
                          onTap: (_timerSeconds > 0 || _isLoading)
                              ? null       // null disables the tap
                              : _resendCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                // Grey gradient when disabled (countdown active)
                                // Blue gradient when enabled (ready to resend)
                                colors: _timerSeconds > 0
                                    ? [Colors.grey.shade800, Colors.grey.shade900]
                                    : [const Color(0xFF271E9A), const Color(0xFF212125)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              // Show countdown number OR "Resend" label
                              _timerSeconds > 0 ? '${_timerSeconds}s' : 'Resend',
                              style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:   13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: size.height * 0.02),
                  ], // end if (_codeSent)

                  SizedBox(height: size.height * 0.012),

                  // ── Action button (or loading spinner) ─────────────────────────
                  //
                  // Shows a CircularProgressIndicator while _isLoading is true.
                  // Otherwise shows GradientButton with a label that changes
                  // based on which phase we're in.
                  //
                  // FIX 1 continued:
                  //   The SIGN UP button is now always reachable because the form
                  //   is wrapped in SingleChildScrollView. On short screens or
                  //   when the keyboard is open, the user can scroll down to it.
                  _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan))
                      : GradientButton(
                          // Phase 1: "SIGN UP" | Phase 2: "VERIFY & SIGN UP"
                          text:      _codeSent ? 'VERIFY & SIGN UP' : 'SIGN UP',
                          // Phase 1: call _handleSignUp | Phase 2: call _handleVerifyOtp
                          onPressed: _codeSent ? _handleVerifyOtp : _handleSignUp,
                        ),

                  SizedBox(height: size.height * 0.018),

                  // ── "Already have an account? Login" link ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Static label — dimmed white
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                            color:    Colors.white.withAlpha(150),
                            fontSize: 13),
                      ),
                      // Tappable "Login" link — navigates to /login route
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                              color:      Colors.cyan,
                              fontWeight: FontWeight.bold,
                              fontSize:   13),
                        ),
                      ),
                    ],
                  ),

                  // Bottom padding so the Login link has room above the keyboard
                  // on short screens — prevents it from being cut off.
                  SizedBox(height: size.height * 0.02),

                ], // end Column children
              ),
            ),
          ),
        ),
      ),
    );
  }
}
