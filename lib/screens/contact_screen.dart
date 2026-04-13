// lib/screens/contact_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Arrow Araw — Contact Us Screen  (FINAL RECTIFICATION v2)
//
// [FIX CONTACT-1] Email field REMOVED from UI — user only types Name + Message.
// [FIX CONTACT-2] Authenticated user's email is read from Supabase and used
//                 automatically in the backend (reply_to / from_name fallback).
//                 No email input required from the user.
// [FIX CONTACT-3] Validation now only requires a non-empty Message.
//                 Name remains optional (falls back to account email in payload).
// [FIX CONTACT-4] EmailJS payload unchanged — reply_to still uses the account
//                 email so the team can reply directly to the sender.
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
const String _kServiceId  = 'service_vtus5km';
const String _kTemplateId = 'template_eb907ud';
const String _kPublicKey  = 'Pc1EQujpT72L2Po8V';
const String _kEndpoint   = 'https://api.emailjs.com/api/v1.0/email/send';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _nameCtrl    = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool  _isSending   = false;

  // [FIX CONTACT-2] Account email auto-fetched — never shown as an input field
  String get _accountEmail =>
      Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    // [FIX CONTACT-3] Only message is required
    if (message.isEmpty) {
      _snack('Please enter a message.', Colors.red);
      return;
    }

    setState(() => _isSending = true);
    try {
      // reply_to uses the authenticated account email automatically
      final senderName = name.isNotEmpty ? name : _accountEmail;

      final payload = {
        'service_id':  _kServiceId,
        'template_id': _kTemplateId,
        'user_id':     _kPublicKey,
        'template_params': {
          'from_name': senderName,                          // → {{from_name}}
          'reply_to':  _accountEmail,                       // → {{reply_to}}
          'message':   message,                             // → {{message}}
          'to_email':  'arrowarawsipaglang@gmail.com',     // → {{to_email}}
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
      if (mounted) setState(() => _isSending = false);
    }
  }

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

            // ── [FIX CONTACT-1] Name only — Email field REMOVED ──────────────
            GradientInputField(
              hintText: 'Your Name (optional)',
              controller: _nameCtrl,
              prefixIcon: Icons.person,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),

            // ── [FIX CONTACT-2] Account email displayed as read-only badge ───
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

            // ── Message ──────────────────────────────────────────────────────
            GradientInputField(
              hintText: 'Describe your problem...',
              controller: _messageCtrl,
              prefixIcon: Icons.message,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 30),

            // ── Send button ───────────────────────────────────────────────────
            _isSending
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan))
                : GradientButton(text: 'SEND MESSAGE', onPressed: _submit),

            const SizedBox(height: 24),

            // ── Feedback email display ────────────────────────────────────────
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
