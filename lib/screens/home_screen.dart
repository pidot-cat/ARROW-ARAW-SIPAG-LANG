// lib/screens/home_screen.dart

// Main hub screen shown after login. Provides navigation entry points to Play,
// Records, Settings, Contact, and About sections.
// Reads [AuthProvider] to display the current username and handle sign-out.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../widgets/background_wrapper.dart';
import '../widgets/gradient_button.dart';
import '../utils/constants.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioService.resumeMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BackgroundWrapper(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppConstants.logoWithBg,
                    width: size.width * 0.5,
                    height: size.width * 0.5,
                  ),
                  SizedBox(height: size.height * 0.022),
                  Text(
                    'Arrow Araw Sipag Lang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size.width * 0.07,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome, ${authProvider.username}!',
                    style: TextStyle(
                      color: Colors.white.withAlpha(128),
                      fontSize: size.width * 0.045,
                    ),
                  ),
                  SizedBox(height: size.height * 0.07),
                  GradientButton(
                    text: 'PLAY',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LevelSelectScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _audioService.resumeMenuMusic();
                      });
                    },
                  ),
                  SizedBox(height: size.height * 0.022),
                  GradientButton(
                    text: 'RECORDS',
                    onPressed: () => Navigator.pushNamed(context, '/records'),
                  ),
                  SizedBox(height: size.height * 0.022),
                  GradientButton(
                    text: 'SETTINGS',
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
