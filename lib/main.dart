import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/records_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/policy_screen.dart';
import 'screens/about_screen.dart';
import 'providers/game_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/app_colors.dart';
import 'services/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ibmfuatpdwamxslzmdfe.supabase.co',
    anonKey: 'sb_publishable_tlXQH89uv5o1BGCWvK6OCQ_RxePEa29',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // [FIX B] Attach lifecycle observer — hard-stops all audio on minimize/exit
  AudioService().attachLifecycleObserver();

  runApp(const ArrowArawSipagLang());
}

class ArrowArawSipagLang extends StatelessWidget {
  const ArrowArawSipagLang({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Arrow Araw Sipag Lang',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primaryDark,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            bodyLarge:  TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/':                (context) => const SplashScreen(),
          '/login':           (context) => const LoginScreen(),
          '/signup':          (context) => const SignUpScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home':            (context) => const HomeScreen(),
          '/records':         (context) => const RecordsScreen(),
          '/settings':        (context) => const SettingsScreen(),
          '/contact':         (context) => const ContactScreen(),
          '/terms':           (context) => const TermsScreen(),
          '/policy':          (context) => const PolicyScreen(),
          '/about':           (context) => const AboutScreen(),
        },
      ),
    );
  }
}
