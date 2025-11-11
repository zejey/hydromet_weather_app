import 'package:flutter/material.dart';
import 'screens/weather_screen.dart';
import 'screens/smart_login_screen.dart';
import 'screens/user_registration.dart';
import 'screens/user_profile.dart';
import 'screens/tips_screen.dart';
import 'screens/hotlines_screen.dart';
import 'screens/user_settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/guest_weather_screen.dart';
import 'services/user_registration_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const SmartLoginScreen(),
        '/register': (context) => const UserRegistrationScreen(),
        '/weather': (context) => const WeatherScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/tips': (context) => const TipsScreen(),
        '/hotlines': (context) => const HotlinesScreen(),
        '/settings': (context) => const UserSettingsScreen(),
        '/guest-weather': (context) => const GuestWeatherScreen(),
      },
      onGenerateRoute: (settings) {
        // ✅ REMOVED: No need for /login-otp route anymore
        // We navigate directly using MaterialPageRoute in smart_login_screen.dart

        return null; // Let routes table handle everything
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
