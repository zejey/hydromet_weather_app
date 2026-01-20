import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart' as auth_service;
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
        final shell = context.findAncestorStateOfType<_HomeShellScreenState>();
        if (shell != null) {
          shell.switchToTab(1);
        }
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets.all(16),
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
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Simple map placeholder with location marker
              Container(
                color: Colors.grey.shade300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 60,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'San Pedro, Laguna',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Overlay with "Tap to explore" prompt
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Tap to explore',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(scale: _scaleAnimation.value, child: child);
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
            // Weather Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: WeatherHeader(
                isGuest: !_isUserLoggedIn,
                onNotificationTap: () {
                  // For now, do nothing - notifications are in Profile tab
                  // Could show a tooltip or navigate to Profile tab
                },
                onMenuTap: () {
                  // For now, do nothing - menu is now in Profile tab
                  // Could navigate to Profile tab
                  final shell = context.findAncestorStateOfType<_HomeShellScreenState>();
                  if (shell != null) {
                    shell.switchToTab(4); // Profile tab
                  }
                },
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
