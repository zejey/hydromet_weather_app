import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart' as auth_service;
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/weather/weather_info_card.dart';
import '../widgets/weather/hourly_forecast_card.dart';
import '../widgets/weather/weather_tiles_grid.dart';
import '../widgets/weather/weather_map_widget.dart';
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
  bool _isOffline = false;
  DateTime? _lastUpdate;
  LatLng? selectedLocation;

  // Services
  final ConnectivityService _connectivityService = ConnectivityService();
  final CacheService _cacheService = CacheService();
  final WeatherService _weatherService = WeatherService();
  final auth_service.AuthService _authService = auth_service.AuthService();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _monitorConnectivity();
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

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivityService.isOnline();
    final lastUpdate = await _cacheService.getLastUpdateTime();

    setState(() {
      _isOffline = !isOnline;
      _lastUpdate = lastUpdate;
    });
  }

  // ✅ Monitor connectivity changes
  void _monitorConnectivity() {
    _connectivityService.onConnectivityChanged.listen((result) async {
      final isOnline = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      setState(() {
        _isOffline = !isOnline;
      });

      if (isOnline) {
        // Back online - refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white),
                SizedBox(width: 12),
                Text('Back online - refreshing data'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        loadWeather();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('Offline - showing cached data'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  // ✅ Build offline indicator
  Widget _buildOfflineIndicator() {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_lastUpdate != null)
                  Text(
                    'Last updated: ${_formatLastUpdate(_lastUpdate!)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: loadWeather,
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdate(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _loadNotificationCount() {
    NotificationService.instance.notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() {
          _notificationCount = notifications.length;
        });

        // ✅ Show system notifications for new alerts
        for (var notification in notifications) {
          if (notification['type'] == 'Emergency' ||
              notification['type'] == 'Warning') {
            LocalNotificationService().showWeatherAlert(
              hazardType: notification['title'] ?? 'Weather Hazard',
              message: notification['body'] ??
                  'Unusual weather conditions detected.',
              riskLevel:
                  notification['type'] == 'Emergency' ? 'high' : 'medium',
            );
          }
        }
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
            icon: const Icon(
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
              child: Text(
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

  static const _timestampFormat = "MMM d, yyyy • h:mm a";

  String _formatTimestamp(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat(_timestampFormat).format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  void _showNotifications() {
    NotificationService.instance.refresh();
    if (!_isUserLoggedIn) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            title: const Row(
              children: [
                Icon(Icons.notifications, color: Colors.green),
                SizedBox(width: 10),
                Text('Notifications'),
              ],
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.green, size: 26),
              SizedBox(width: 10),
              Text(
                'Weather Alerts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificationService.instance.notificationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading alerts…',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No weather alerts right now',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                final notifications = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    final type = notif['type'] as String?;
                    final color = _getNotificationColor(type);
                    final formattedTime = _formatTimestamp(notif['timestamp']);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: color.withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _getNotificationIcon(type),
                                color: color,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif['title'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            border: Border.all(
                                                color: color.withOpacity(0.6)),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            type ?? 'Info',
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif['body'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (formattedTime.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
              child: const Text('Close'),
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
            _buildOfflineIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
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
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
