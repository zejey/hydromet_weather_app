import 'package:flutter/material.dart';
import 'screens/weather_screen.dart';
import 'screens/log_in.dart';
import 'screens/login_form.dart';
import 'screens/user_registration.dart';
import 'screens/user_profile.dart';
import 'screens/tips_screen.dart';
import 'screens/hotlines_screen.dart';
import 'screens/user_settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/user_registration_service.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_form_pincode.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Remove or implement if AuthManager().initialize() does not exist
  await UserRegistrationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroMet San Pedro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      initialRoute: '/mpin-login',
      routes: {
        '/': (context) => const WeatherScreen(),
        '/splash': (context) => SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/login-form': (context) => const LoginFormScreen(),
        '/mpin-login': (context) => LoginMPINScreen(),
        '/register': (context) => const UserRegistrationScreen(),
        '/weather': (context) => const WeatherScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/tips': (context) => const TipsScreen(),
        '/hotlines': (context) => const HotlinesScreen(),
        '/settings': (context) => const UserSettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
