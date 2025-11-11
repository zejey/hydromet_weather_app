import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/notification_service.dart';
import '../widgets/weather/weather_header.dart';
import '../widgets/weather/weather_info_card.dart';
import '../widgets/weather/hourly_forecast_card.dart';
import '../widgets/weather/weather_tiles_grid.dart';
import '../widgets/weather/weather_map.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  // User authentication state
  bool _isUserLoggedIn = false;
  String _currentUserName = '';

  // Weather data
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airData;
  List<Map<String, dynamic>> hourlyForecast = [];
  bool isLoading = true;
  LatLng? selectedLocation;

  // Services
  final WeatherService _weatherService = WeatherService();
  final auth_service.AuthService _authService = auth_service.AuthService();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    loadWeather();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final auth = auth_service.AuthService();
    await auth.initialize();

    print('🔍 Weather Screen Auth Check:');
    print('   - isLoggedIn: ${auth.isLoggedIn}');
    print('   - username: ${auth.username}');
    print('   - phone: ${auth.phoneNumber}');

    setState(() {
      _isUserLoggedIn = auth.isLoggedIn;
      _currentUserName = auth.username;
    });
  }

  Future<void> loadWeather() async {
    try {
      setState(() => isLoading = true);

      const sanPedroLat = 14.3358;
      const sanPedroLon = 121.0417;

      final weather = await _weatherService
          .fetchCurrentWeatherByCoords(sanPedroLat, sanPedroLon)
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? air;
      try {
        air = await _weatherService
            .fetchAirPollution(sanPedroLat, sanPedroLon)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Air pollution data fetch failed: $e');
      }

      List<Map<String, dynamic>> forecast = [];
      try {
        forecast = await _weatherService
            .fetchHourlyForecast(sanPedroLat, sanPedroLon)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Hourly forecast fetch failed: $e');
      }

      if (mounted) {
        setState(() {
          weatherData = weather;
          airData = air;
          hourlyForecast = forecast;
          selectedLocation = LatLng(sanPedroLat, sanPedroLon);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Weather data fetch failed: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar(
            'Failed to load weather data. Please check your internet connection.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get weatherMain =>
      (weatherData?['weather']?[0]?['main'] ?? '').toLowerCase();

  String getBackgroundImage() {
    switch (weatherMain) {
      case 'clear':
        return 'assets/clear_day.jpg';
      case 'clouds':
        return 'assets/cloudy.jpg';
      case 'rain':
      case 'drizzle':
      case 'thunderstorm':
        return 'assets/rainy.jpg';
      case 'snow':
        return 'assets/snowy.jpg';
      case 'mist':
      case 'fog':
      case 'haze':
        return 'assets/clear_day.jpg';
      default:
        return 'assets/clear_day.jpg';
    }
  }

  // ✅ LOGGED-IN USER NOTIFICATIONS
  void _showNotifications() {
    if (!_isUserLoggedIn) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notifications'),
            content: const Text(
                'Notifications are not available. Please log in first to view notifications.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Login'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificationService.instance.userNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No new notifications.');
                }
                final notifications = snapshot.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return ListTile(
                      leading: Icon(
                        _getNotificationIcon(notif['type']),
                        color: _getNotificationColor(notif['type']),
                        size: 28,
                      ),
                      title: Text(
                        notif['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notif['body'] ?? ''),
                          if (notif['timestamp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                notif['timestamp'].toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'Emergency':
        return Icons.priority_high_rounded;
      case 'Warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'Emergency':
        return Colors.red;
      case 'Warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // ✅ LOGGED-IN USER PROFILE MENU
  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Logged in as:',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _currentUserName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Menu options
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Safety Tips'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/tips');
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Emergency Hotlines'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hotlines');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                nav.pop();

                await _authService.logout();

                if (mounted) {
                  setState(() {});
                  nav.pushNamedAndRemoveUntil('/', (route) => false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Logged out successfully'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About HydroMet San Pedro'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HydroMet San Pedro, Laguna'),
              SizedBox(height: 8),
              Text('Version: 1.0.0'),
              SizedBox(height: 8),
              Text(
                  'A weather application specifically designed for San Pedro, Laguna, Philippines. Provides real-time weather updates, local hazard warnings, emergency hotlines, and safety tips for residents.'),
              SizedBox(height: 16),
              Text('© 2025 City of San Pedro, Laguna'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                      scale: _scaleAnimation.value, child: child);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(getBackgroundImage(), fit: BoxFit.cover),
                    Container(color: Colors.black.withOpacity(0.1)),
                  ],
                ),
              ),
            ),

            // Main content
            Column(
              children: [
                // ✅ Shared Header Widget (User mode)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: WeatherHeader(
                    isGuest: false, // ✅ User mode
                    onNotificationTap: _showNotifications,
                    onMenuTap: _showProfileMenu,
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              if (weatherData != null) ...[
                                // ✅ Shared Weather Info Card
                                WeatherInfoCard(weatherData: weatherData!),

                                // ✅ Shared Hourly Forecast Card
                                if (hourlyForecast.isNotEmpty)
                                  HourlyForecastCard(forecast: hourlyForecast),

                                const SizedBox(height: 20),

                                // ✅ Shared Weather Tiles Grid
                                WeatherTilesGrid(
                                  weatherData: weatherData!,
                                  airData: airData,
                                  isGuest: false, // ✅ User mode
                                ),

                                const SizedBox(height: 20),

                                // ✅ Shared Weather Map
                                if (selectedLocation != null)
                                  WeatherMap(
                                    location: selectedLocation!,
                                    weatherData: weatherData!,
                                    airData: airData,
                                    isGuest: false, // ✅ User mode
                                  ),

                                const SizedBox(height: 40),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
