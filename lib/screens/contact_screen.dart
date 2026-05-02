// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/contact_screen.dart
// Contact Us screen — lets authenticated users send a support message via
// EmailJS without leaving the app.
//
// EmailJS Reply-To fix (CONTACT-2):
//   The authenticated user's email is read from Supabase and injected into the
//   `reply_to` template parameter.  EmailJS forwards this value to the email
//   client, so hitting "Reply" in Gmail opens a draft addressed to the user —
//   not to the app's own sending address.
//
// UI behaviour:
//   • Name field is optional; falls back to the account email in the payload.
//   • The account email is shown as a read-only badge (lock icon + cyan text)
//     so the user knows which address will receive replies.
//   • Message field is the only required input.
//   • A CircularProgressIndicator replaces the Send button while the HTTP
//     request is in flight.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/background_wrapper.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_input_field.dart';
import '../utils/constants.dart';

// ── EmailJS credentials ───────────────────────────────────────────────────────
// These values come from the EmailJS dashboard (emailjs.com → Account → API Keys
// and Email Services).  Keep them in a .env file or --dart-define flags before
// publishing to production.
const String _kServiceId  = 'service_vtus5km';   // EmailJS service ID
const String _kTemplateId = 'template_eb907ud';   // EmailJS template ID
const String _kPublicKey  = 'Pc1EQujpT72L2Po8V'; // EmailJS public key
const String _kEndpoint   = 'https://api.emailjs.com/api/v1.0/email/send';

/// ContactScreen — stateful form that submits user concerns to the support
/// email address via the EmailJS REST API.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  /// Controller for the optional name input field.
  final _nameCtrl    = TextEditingController();

  /// Controller for the required message input field.
  final _messageCtrl = TextEditingController();

  /// Tracks whether an EmailJS request is currently in flight.
  bool  _isSending   = false;

  /// Reads the signed-in user's email address directly from the Supabase auth
  /// session.  Returns an empty string when no user is logged in (should not
  /// happen on this screen, which is behind an auth guard).
  String get _accountEmail =>
      Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';

  @override
  void dispose() {
    // Release text-editing controllers to avoid memory leaks.
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  /// Validates inputs, builds the EmailJS payload, and posts it to the API.
  ///
  /// The `reply_to` field receives [_accountEmail] so the support team can
  /// reply directly to the user from their email client without any copy-paste.
  ///
  /// Template variables used (must match the EmailJS template exactly):
  ///   {{from_name}} — display name shown in the email subject/body.
  ///   {{reply_to}}  — the user's email; used as the Reply-To header.
  ///   {{message}}   — the body text typed by the user.
  ///   {{to_email}}  — the destination support address.
  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    // Guard: message must not be blank before making a network call.
    if (message.isEmpty) {
      _snack('Please enter a message.', Colors.red);
      return;
    }

    setState(() => _isSending = true);
    try {
      // Use the typed name when available; otherwise fall back to the email
      // address so `from_name` is never an empty string in the template.
      final senderName = name.isNotEmpty ? name : _accountEmail;

      final payload = {
        'service_id':  _kServiceId,
        'template_id': _kTemplateId,
        'user_id':     _kPublicKey,
        'template_params': {
          'from_name': senderName,                       // → {{from_name}}
          'reply_to':  _accountEmail,                    // → {{reply_to}}  ← KEY FIX
          'message':   message,                          // → {{message}}
          'to_email':  'arrowarawsipaglang@gmail.com',  // → {{to_email}}
        },
      };

      debugPrint('[EmailJS] POST → $_kEndpoint');
      debugPrint('[EmailJS] Payload → ${jsonEncode(payload)}');

      final res = await http.post(
        Uri.parse(_kEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://www.emailjs.com',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[EmailJS] Status → ${res.statusCode}');
      debugPrint('[EmailJS] Body   → ${res.body}');

      if (!mounted) return;
      if (res.statusCode == 200) {
        // Clear the form on success so the user can easily send another message.
        _nameCtrl.clear();
        _messageCtrl.clear();
        _snack('Message sent to arrowarawsipaglang@gmail.com ✓', Colors.green);
      } else {
        final errorDetail = res.body.isNotEmpty ? res.body : 'HTTP ${res.statusCode}';
        _snack('Failed: $errorDetail', Colors.red);
      }
    } catch (e, st) {
      debugPrint('[EmailJS] Exception → $e');
      debugPrint('[EmailJS] Stack     → $st');
      if (!mounted) return;
      _snack('Network error. Check your connection.', Colors.red);
    } finally {
      // Always re-enable the Send button, even if an exception was thrown.
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Displays a floating [SnackBar] with the given [msg] and [color].
  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BackgroundWrapper(
        showBackButton: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(children: [
            SizedBox(height: size.height * 0.055),
            Image.asset(AppConstants.logoWithBg, width: 160, height: 160),
            const SizedBox(height: 16),
            const Text('Contact Us',
                style: TextStyle(color: Colors.white, fontSize: 26,
                    fontWeight: FontWeight.bold, letterSpacing: 1.2),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("We're here to help!",
                style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 15)),
            SizedBox(height: size.height * 0.035),

            // ── Optional name field ──────────────────────────────────────────
            GradientInputField(
              hintText: 'Your Name (optional)',
              controller: _nameCtrl,
              prefixIcon: Icons.person,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),

            // ── Read-only account email badge ────────────────────────────────
            // Shows the user which address will appear in the Reply-To header.
            // Not editable — always sourced from the Supabase auth session.
            if (_accountEmail.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withAlpha(50)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 16, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sending from: $_accountEmail',
                      style: TextStyle(
                          color: Colors.cyanAccent.withAlpha(200), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            if (_accountEmail.isNotEmpty) const SizedBox(height: 14),

            // ── Required message field ───────────────────────────────────────
            GradientInputField(
              hintText: 'Describe your problem...',
              controller: _messageCtrl,
              prefixIcon: Icons.message,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 30),

            // ── Send button / loading indicator ──────────────────────────────
            // Replaced by a spinner while [_isSending] is true to prevent
            // duplicate submissions.
            _isSending
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan))
                : GradientButton(text: 'SEND MESSAGE', onPressed: _submit),

            const SizedBox(height: 24),

            // ── Fallback contact info ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withAlpha(26)),
              ),
              child: Column(children: [
                const Text('Feedback Email:',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.email_rounded, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text('arrowarawsipaglang@gmail.com',
                      style: TextStyle(
                          color: Colors.white.withAlpha(204), fontSize: 14)),
                ]),
              ]),
            ),
            SizedBox(height: size.height * 0.04),
          ]),
        ),
      ),
    );
  }
}
