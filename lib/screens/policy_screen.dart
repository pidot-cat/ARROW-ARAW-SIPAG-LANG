// lib/screens/policy_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Screen — static informational screen listing all data
// collection and usage policies for Arrow Araw: Sipag Lang.
// Read-only, no state required (StatelessWidget).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../widgets/background_wrapper.dart';
import '../utils/constants.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

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
                      'Privacy Policy',
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

              // ── Policy sections ───────────────────────────────────────────
              _buildSection('Information Collection',
                  'We collect information you provide directly to us, including your username, email address, and game statistics.'),
              _buildSection('Data Usage',
                  'Your personal data is used to: authenticate your account, track game progress and statistics, provide customer support, and improve the gaming experience.'),
              _buildSection('Data Storage',
                  'All user data is stored securely via Supabase. We do not transmit your personal information to external servers without your explicit consent.'),
              _buildSection('Game Statistics',
                  'We collect and store game statistics including wins, losses, matches played, and playtime. This data is used solely to enhance your gaming experience.'),
              _buildSection('Data Security',
                  'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction.'),
              _buildSection('Third-Party Services',
                  'Our app may contain links to third-party websites or services. We are not responsible for the privacy practices of these external sites.'),
              _buildSection("Children's Privacy",
                  'Our service is not directed to children under 13. We do not knowingly collect personal information from children under 13.'),
              _buildSection('Your Rights',
                  'You have the right to access, update, or delete your personal information at any time through the app settings or by contacting us.'),
              _buildSection('Contact Us',
                  'If you have questions about this Privacy Policy, please contact us at arrowarawsipaglang@gmail.com'),

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

  /// Renders a single policy section with a cyan title and white body text.
  ///
  /// [title]   — Section heading in cyan.
  /// [content] — Policy description paragraph below the heading.
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
