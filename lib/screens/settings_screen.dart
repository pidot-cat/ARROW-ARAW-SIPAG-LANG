// lib/screens/settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — Ultra-Refined v2
// Vibrant multi-color palette: Orange, Green, Purple accent tiles.
// Dynamic glassmorphism design with neon glow accents.
// ⚠️  Auth / Supabase / Navigation logic is UNCHANGED.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/background_wrapper.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../services/level_unlock_service.dart';

// Per-tile accent data
class _TileTheme {
  final Color accent;
  final Color glow;
  const _TileTheme(this.accent, this.glow);
}

const _orange = _TileTheme(Color(0xFFFF6D00), Color(0xFFFF6D00));
const _green = _TileTheme(Color(0xFF00E676), Color(0xFF00E676));
const _purple = _TileTheme(Color(0xFFD500F9), Color(0xFFAA00FF));
const _cyan = _TileTheme(Color(0xFF00E5FF), Color(0xFF00B8D4));

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioService _audio = AudioService();

  // ── Auth handlers (UNCHANGED) ─────────────────────────────────────────────

  Future<void> _handleLogout() async {
    _audio.stopAll();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final TextEditingController passCtrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        bool obscureText = true;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x33FF1744), width: 1)),
            title: const Text('Delete Account',
                style: TextStyle(
                    color: Color(0xFFFF1744),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is permanent and cannot be undone.\nEnter your password to confirm.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Re-registering with the same email will start fresh.',
                  style: TextStyle(
                      color: Colors.orange.withAlpha(200), fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white38),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white38),
                      onPressed: () =>
                          setDialogState(() => obscureText = !obscureText),
                    ),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    errorText: errorMsg,
                    errorStyle: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final pass = passCtrl.text.trim();
                        if (pass.isEmpty) {
                          setDialogState(
                              () => errorMsg = 'Password is required');
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorMsg = null;
                        });
                        final authProvider =
                            Provider.of<AuthProvider>(ctx, listen: false);
                        final gameProvider =
                            Provider.of<GameProvider>(ctx, listen: false);
                        final dialogNav = Navigator.of(ctx);
                        final rootNav = Navigator.of(context);
                        await gameProvider.resetStats();
                        await LevelUnlockService.instance.resetProgress();
                        final result = await authProvider.deleteAccount(pass);
                        if (!ctx.mounted) return;
                        if (result == null) {
                          dialogNav.pop();
                          _audio.stopAll();
                          rootNav.pushNamedAndRemoveUntil(
                              '/login', (r) => false);
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMsg = result;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
    passCtrl.dispose();
  }

  // ── Audio bottom sheet ────────────────────────────────────────────────────

  void _showAudioSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _orange.accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.graphic_eq_rounded,
                        color: _orange.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Audio Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                ],
              ),
              const SizedBox(height: 20),
              _buildAudioToggle(
                setModal,
                icon: Icons.music_note_rounded,
                label: 'Background Music',
                subtitle: 'Lobby-Music  ·  Ingame-Music',
                value: _audio.isMusicOn,
                theme: _green,
                onChanged: (v) async {
                  await _audio.toggleMusic();
                  setModal(() {});
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _buildAudioToggle(
                setModal,
                icon: Icons.volume_up_rounded,
                label: 'Sound FX',
                subtitle: 'Arrow  ·  Win  ·  Wrong Move  ·  Game Over',
                value: _audio.isSfxOn,
                theme: _purple,
                onChanged: (v) {
                  _audio.toggleSfx();
                  setModal(() {});
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioToggle(
    StateSetter setModal, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required _TileTheme theme,
    required Function(bool) onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? theme.accent.withAlpha(18) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              value ? theme.accent.withAlpha(80) : Colors.white.withAlpha(20),
          width: 1.2,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: theme.glow.withAlpha(40),
                  blurRadius: 12,
                  spreadRadius: 0,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accent.withAlpha(value ? 40 : 20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withAlpha(120), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return theme.accent;
              return Colors.grey.shade600;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return theme.accent.withAlpha(80);
              return Colors.grey.shade800;
            }),
          ),
        ],
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: BackgroundWrapper(
        showBackButton: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Column(
              children: [
                SizedBox(height: size.height * 0.01),

                // Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withAlpha(25), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _cyan.glow.withAlpha(40),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Image.asset(AppConstants.logoWithBg,
                      width: 80, height: 80),
                ),
                const SizedBox(height: 10),

                // Title
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Logged in as: ${authProvider.username}',
                  style: TextStyle(
                      color: Colors.white.withAlpha(160), fontSize: 13),
                ),
                const SizedBox(height: 22),

                // Audio tile — Orange accent
                _SettingTile(
                  title: 'Audio Settings',
                  subtitle: _audio.isMusicOn && _audio.isSfxOn
                      ? 'Music & SFX: On'
                      : !_audio.isMusicOn && !_audio.isSfxOn
                          ? 'Music & SFX: Off'
                          : 'Partially Muted',
                  icon: Icons.graphic_eq_rounded,
                  theme: _orange,
                  onTap: _showAudioSettingsModal,
                ),
                const SizedBox(height: 10),

                // Contact — Green
                _SettingTile(
                  title: 'Contact Us',
                  subtitle: 'Get help and support',
                  icon: Icons.contact_support_rounded,
                  theme: _green,
                  onTap: () => Navigator.pushNamed(context, '/contact'),
                ),
                const SizedBox(height: 10),

                // Terms — Purple
                _SettingTile(
                  title: 'Terms of Service',
                  subtitle: 'Read our terms',
                  icon: Icons.description_rounded,
                  theme: _purple,
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                ),
                const SizedBox(height: 10),

                // Privacy — Cyan
                _SettingTile(
                  title: 'Privacy Policy',
                  subtitle: 'Your privacy matters',
                  icon: Icons.privacy_tip_rounded,
                  theme: _cyan,
                  onTap: () => Navigator.pushNamed(context, '/policy'),
                ),
                const SizedBox(height: 10),

                // About — Purple
                _SettingTile(
                  title: 'About Us',
                  subtitle: 'Learn more about the app',
                  icon: Icons.info_rounded,
                  theme: _TileTheme(
                      const Color(0xFFAA00FF), const Color(0xFFAA00FF)),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),

                const SizedBox(height: 28),

                // Log Out button
                SizedBox(
                  width: double.infinity,
                  child: _GlowButton(
                    label: 'LOG OUT',
                    color: const Color(0xFFB71C1C),
                    glowColor: Colors.red,
                    icon: Icons.logout_rounded,
                    onTap: _handleLogout,
                  ),
                ),
                const SizedBox(height: 10),

                // Delete Account button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: Colors.redAccent, size: 18),
                    label: const Text('DELETE ACCOUNT',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Colors.redAccent, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.03),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingTile — colored accent glassmorphism tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final _TileTheme theme;
  final VoidCallback onTap;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: theme.accent.withAlpha(14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.accent.withAlpha(60), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: theme.glow.withAlpha(25),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: theme.accent.withAlpha(35),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: theme.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withAlpha(140), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.accent.withAlpha(180), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlowButton — neon glow CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final Color color, glowColor;
  final IconData icon;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.color,
    required this.glowColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: glowColor.withAlpha(100),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
