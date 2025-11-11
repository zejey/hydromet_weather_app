import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      final authService = AuthService();
      await authService.initialize();

      final prefs = await SharedPreferences.getInstance();
      final sessionExpiryStr = prefs.getString('session_expires_at');

      print('🔍 Checking session...');
      print('📱 Logged in: ${authService.isLoggedIn}');
      print('📱 Session expires: $sessionExpiryStr');

      if (authService.isLoggedIn && authService.phoneNumber.isNotEmpty) {
        // Check if session expired
        if (sessionExpiryStr != null) {
          final sessionExpiry = DateTime.parse(sessionExpiryStr);
          final now = DateTime.now();

          if (now.isAfter(sessionExpiry)) {
            // Session expired (> 30 days)
            print('⏰ Session expired - logging out');
            await authService.logout();

            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
            return;
          }
        }

        // Session valid
        print('✅ Session valid - going to weather');

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/weather');
        }
      } else {
        // No session
        print('❌ No session - going to login');

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('❌ Error: $e');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.green,
          image: DecorationImage(
            image: AssetImage('assets/b.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Transform.rotate(
                    angle: -1.5708, // -90 degrees in radians
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if logo fails to load
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud,
                            size: 80,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'HydroMET',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'San Pedro Weather & Alerts',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 40),

              // Loading indicator
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),

              const SizedBox(height: 16),

              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
