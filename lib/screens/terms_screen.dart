// lib/screens/terms_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service Screen — static informational screen presenting the app's
// usage terms, intellectual property notice, and contact information.
// Read-only, no state required (StatelessWidget).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../widgets/background_wrapper.dart';
import '../utils/constants.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: BackgroundWrapper(
        showBackButton: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centred logo and title header
              Center(
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.055),
                    Image.asset(AppConstants.logoWithBg,
                        width: 160, height: 160),
                    const SizedBox(height: 16),
                    const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Terms sections ────────────────────────────────────────────
              _buildSection('Acceptance of Terms',
                  'By accessing and using Arrow Araw Sipag Lang, you accept and agree to be bound by the terms and provision of this agreement.'),
              _buildSection('Use License',
                  'Permission is granted to temporarily download one copy of Arrow Araw Sipag Lang per device for personal, non-commercial transitory viewing only.'),
              _buildSection('User Account',
                  'You are responsible for maintaining the confidentiality of your account and password.'),
              _buildSection('Game Rules',
                  'Players must follow the game rules and play fairly. Any attempt to cheat, hack, or exploit the game will result in immediate account termination.'),
              _buildSection('Intellectual Property',
                  'All content, features, and functionality are owned by Arrow Araw Sipag Lang and are protected by international copyright, trademark, and other intellectual property laws.'),
              _buildSection('Limitation of Liability',
                  'Arrow Araw Sipag Lang shall not be liable for any damages arising out of the use or inability to use the game.'),
              _buildSection('Modifications',
                  'We reserve the right to modify or replace these Terms at any time.'),
              _buildSection('Contact Information',
                  'For questions about these Terms, please contact us at arrowarawsipaglang@gmail.com'),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Last Updated: April 2026',
                  style: TextStyle(
                      color: Colors.white.withAlpha(128),
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders a single terms section with a cyan title and white body text.
  ///
  /// [title]   — Section heading in cyan.
  /// [content] — Terms description paragraph below the heading.
  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(content,
              style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 15,
                  height: 1.5)),
        ],
      ),
    );
  }
}
