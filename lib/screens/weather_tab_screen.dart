import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/notification_service.dart';
import '../widgets/weather/weather_header.dart';
import '../widgets/weather/weather_info_card.dart';
import '../widgets/weather/hourly_forecast_card.dart';
import '../widgets/weather/weather_tiles_grid.dart';
import 'home_shell_screen.dart';

class WeatherTabScreen extends StatefulWidget {
  const WeatherTabScreen({super.key});

  @override
  State<WeatherTabScreen> createState() => _WeatherTabScreenState();
}

class _WeatherTabScreenState extends State<WeatherTabScreen>
    with TickerProviderStateMixin {
  // User authentication state
  bool _isUserLoggedIn = false;
  int _notificationCount = 0;
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
    _loadNotificationCount();

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


  void _loadNotificationCount() {
      NotificationService.instance.userNotificationsStream().listen((notifications) {
        if (mounted) {
          setState(() {
            _notificationCount = notifications. length;
          });
        }
      });
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
    await _authService.initialize();

    if (mounted) {
      setState(() {
        _isUserLoggedIn = _authService.isLoggedIn;
      });
    }
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
      }
    }
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

  Widget _buildMapPreview() {
    return GestureDetector(
      onTap: () {
        // Switch to Map tab (index 1)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full map view coming soon!  Tap the Map tab below.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets. all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius. circular(16),
          child: Stack(
            children: [
              // Simple map placeholder with location marker
              Container(
                color:  Colors.grey.shade300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size:  60,
                        color: Colors. green.shade700,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'San Pedro, Laguna',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors. grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Overlay with "Tap to explore" prompt
              Positioned(
                bottom:  12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius. circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Tap to explore',
                        style: TextStyle(color:  Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _showNotifications,
            icon:  const Icon(
              Icons.notifications,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        
        // Notification badge
        if (_notificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child:  Text(
                _notificationCount > 9 ? '9+' : '$_notificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

// Keep your existing _showNotifications method
  void _showNotifications() {
    if (! _isUserLoggedIn) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notifications'),
            content: const Text(
                'Notifications are not available.  Please log in first to view notifications.'),
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
                onPressed:  () {
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
                if (! snapshot.hasData || snapshot.data!.isEmpty) {
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
                        color:  _getNotificationColor(notif['type']),
                        size: 28,
                      ),
                      title: Text(
                        notif['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:  Column(
                        crossAxisAlignment:  CrossAxisAlignment.start,
                        children: [
                          Text(notif['body'] ?? ''),
                          if (notif['timestamp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                notif['timestamp']. toString(),
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

  IconData _getNotificationIcon(String?  type) {
    switch (type) {
      case 'Emergency':
        return Icons.priority_high_rounded;
      case 'Warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getNotificationColor(String?  type) {
    switch (type) {
      case 'Emergency':
        return Colors.red;
      case 'Warning': 
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(getBackgroundImage(), fit: BoxFit.cover),
              Container(color: Colors.black.withOpacity(0.1)),
            ],
          ),
        ),

        // Main content
        Column(
          children: [
            // Weather Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✅ Custom notification button with badge
                  _buildNotificationButton(),
                  
                  const Spacer(),
                  
                  // App Title
                  const Text(
                    'HydroMet',
                    style: TextStyle(
                      color:  Colors.white,
                      fontSize: 24,
                      fontWeight:  FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Empty space to balance layout (no menu button)
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: loadWeather,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            if (weatherData != null) ...[
                              // Weather Info Card
                              WeatherInfoCard(weatherData: weatherData!),

                              // Hourly Forecast Card
                              if (hourlyForecast.isNotEmpty)
                                HourlyForecastCard(forecast: hourlyForecast),

                              const SizedBox(height: 20),

                              // Weather Tiles Grid
                              WeatherTilesGrid(
                                weatherData: weatherData!,
                                airData: airData,
                                isGuest: !_isUserLoggedIn,
                              ),

                              const SizedBox(height: 20),

                              // Map preview
                              _buildMapPreview(),

                              const SizedBox(height: 40),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
