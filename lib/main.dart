import 'package:flutter/material.dart';
import 'screens/weather_screen.dart';
import 'screens/log_in.dart';
import 'screens/user_registration.dart';
import 'screens/user_profile.dart';
import 'screens/tips_screen.dart';
import 'screens/hotlines_screen.dart';
import 'screens/user_settings_screen.dart';
// import 'screens/community_forum_screen.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthManager().initialize();
  
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
      initialRoute: '/weather',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/login-form': (context) => const LoginFormScreen(),
        '/register': (context) => const UserRegistrationScreen(),
        '/weather': (context) => const WeatherScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/tips': (context) => const TipsScreen(),
        '/hotlines': (context) => const HotlinesScreen(),
        '/settings': (context) => const UserSettingsScreen(),
        // '/forum': (context) => const CommunityForumScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
