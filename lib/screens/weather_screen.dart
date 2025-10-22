import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart';
import 'log_in.dart';
import '../services/notification_service.dart';

// Forecast overlay enum for map overlays
enum ForecastLayer { none, precipitation, clouds, temp, wind }

// Notification dialog handler
void _showNotifications(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Notifications'),
        content: const Text('No new notifications.'),
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

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  // Controller to sync forecast graph, icons, and time labels
  final ScrollController _forecastScrollController = ScrollController();
  // Build aligned weather tiles in a 2-column grid
  Widget buildWeatherTilesGrid() {
    if (weatherData == null) return const SizedBox();
    final tiles = [
      buildWeatherTile("Feels Like",
          "${weatherData!['main']['feels_like'].round()}°C", Icons.thermostat),
      buildWeatherTile(
          "Humidity", "${weatherData!['main']['humidity']}%", Icons.water_drop),
      buildWeatherTile(
          "Wind", "${weatherData!['wind']['speed']} m/s", Icons.air),
      buildWeatherTile(
          "Pressure", "${weatherData!['main']['pressure']} hPa", Icons.speed),
      buildWeatherTile(
          "Visibility",
          "${(weatherData!['visibility'] / 1000).toStringAsFixed(1)} km",
          Icons.remove_red_eye),
      buildWeatherTile(
          "Clouds", "${weatherData!['clouds']['all']}%", Icons.cloud),
    ];
    // Add Air Quality as a full-width tile if available
    if (airData != null) {
      final aqi = airData!['list'][0]['main']['aqi'];
      final aqiInfo = _getAQIInfo(aqi);
      tiles.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: aqiInfo['color'].withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.13),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.air, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Air Quality",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      aqiInfo['label'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aqiInfo['description'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "AQI $aqi",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    List<Widget> rows = [];
    for (int i = 0; i < tiles.length; i += 2) {
      // If last tile and odd count, make it full width
      if (i == tiles.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: tiles[i],
        ));
      } else {
        rows.add(Row(
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 12),
            Expanded(child: tiles[i + 1]),
          ],
        ));
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Map<String, dynamic> _getAQIInfo(int aqi) {
    // Detailed AQI info with color, label, and description
    switch (aqi) {
      case 1:
        return {
          'label': 'Good',
          'color': Colors.green,
          'description': 'Air quality is good. Ideal for outdoor activities.',
        };
      case 2:
        return {
          'label': 'Fair',
          'color': Colors.yellow,
          'description':
              'Air quality is acceptable. Sensitive individuals should take care.',
        };
      case 3:
        return {
          'label': 'Moderate',
          'color': Colors.orange,
          'description':
              'Air quality is moderate. People with respiratory issues should limit outdoor exertion.',
        };
      case 4:
        return {
          'label': 'Poor',
          'color': Colors.red,
          'description':
              'Air quality is poor. Limit outdoor activities, especially for sensitive groups.',
        };
      case 5:
        return {
          'label': 'Very Poor',
          'color': Colors.purple,
          'description':
              'Air quality is very poor. Avoid outdoor activities and stay indoors.',
        };
      default:
        return {
          'label': 'Unknown',
          'color': Colors.grey,
          'description': 'Air quality data unavailable.',
        };
    }
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
                // Clear both authentication systems
                await _authManager.logout();
                AuthService.signOut();
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

  // Admin notifications (replace with backend data as needed)
  List<Map<String, dynamic>> notifications = [];
  final bool _notificationsLoading = true;

  double _getTemperatureIntensity(double temperature) {
    // Normalize temperature to 0-1 scale for heat map intensity
    if (temperature <= 0) return 0.0;
    if (temperature >= 40) return 1.0;
    return temperature / 40.0;
  }

  // Generate temperature points for heatmap
  void _generateTemperaturePoints() {
    if (selectedLocation == null || weatherData == null) return;
    _temperaturePoints.clear();
    final random = Random();
    final baseTemp = weatherData!['main']['temp'] ?? 25.0;
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.08; // ~8km radius
      final lat = selectedLocation!.latitude + (distance * cos(angle));
      final lng = selectedLocation!.longitude + (distance * sin(angle));
      final tempVariation = (random.nextDouble() - 0.5) * 6; // ±3°C variation
      final pointTemp = baseTemp + tempVariation;
      _temperaturePoints.add({
        'location': LatLng(lat, lng),
        'temperature': pointTemp,
        'intensity': _getTemperatureIntensity(pointTemp),
      });
    }
  }

  // Generate wind data points
  void _generateWindData() {
    if (selectedLocation == null || weatherData == null) return;
    _windData.clear();
    final random = Random();
    final windSpeed = weatherData!['wind']['speed'] ?? 0.0;
    final windDirection = weatherData!['wind']['deg'] ?? 0.0;
    for (int i = 0; i < 15; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.06; // ~6km radius
      final lat = selectedLocation!.latitude + (distance * cos(angle));
      final lng = selectedLocation!.longitude + (distance * sin(angle));
      final directionVariation =
          (random.nextDouble() - 0.5) * 30; // ±15° variation
      final pointDirection = windDirection + directionVariation;
      _windData.add({
        'location': LatLng(lat, lng),
        'speed':
            windSpeed + (random.nextDouble() - 0.5) * 2, // ±1 m/s variation
        'direction': pointDirection,
      });
    }
  }

  // Helper for temperature color (used in heatmap)
  Color _getTemperatureColor(double temperature) {
    if (temperature <= 10) return Colors.blue;
    if (temperature <= 20) return Colors.cyan;
    if (temperature <= 25) return Colors.green;
    if (temperature <= 30) return Colors.yellow;
    if (temperature <= 35) return Colors.orange;
    return Colors.red;
  }

  // Build animated rain particles
  List<Marker> _buildRainParticles() {
    final random = Random();
    return _rainParticleLocations.map((location) {
      final dropHeight = 12.0 + random.nextDouble() * 8.0; // 12-20 px
      final tilt = (random.nextDouble() - 0.5) * 0.2; // -0.1 to 0.1 radians
      return Marker(
        width: 18.0,
        height: 24.0,
        point: location,
        builder: (ctx) => AnimatedBuilder(
          animation: _rainAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _rainAnimation.value * 10),
              child: Transform.rotate(
                angle: tilt,
                child: Container(
                  width: 4,
                  height: dropHeight,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.7),
                    borderRadius:
                        BorderRadius.circular(8), // More rounded for raindrop
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  // Build wind direction arrows
  List<Marker> _buildWindArrows() {
    return _windData.map((windPoint) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: windPoint['location'],
        builder: (ctx) => Transform.rotate(
          angle:
              (windPoint['direction'] * pi) / 180, // Convert degrees to radians
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueGrey, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_upward,
              color: _getWindSpeedColor(windPoint['speed']),
              size: 24,
            ),
          ),
        ),
      );
    }).toList();
  }

  // Get color based on wind speed
  Color _getWindSpeedColor(double speed) {
    if (speed <= 5) return Colors.green;
    if (speed <= 10) return Colors.yellow;
    if (speed <= 15) return Colors.orange;
    return Colors.red;
  }

  // Get weather-based circle color
  Color _getWeatherCircleColor() {
    if (weatherData == null) return Colors.blue;
    final weatherCondition = weatherData!['weather'][0]['main'].toLowerCase();
    switch (weatherCondition) {
      case 'rain':
      case 'drizzle':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.purple;
      case 'snow':
        return Colors.lightBlue;
      case 'clear':
        return Colors.yellow;
      case 'clouds':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // Minimized "Safe to go out" indicator
  Widget _buildSafetyIndicator() {
    final isSafe = _calculateSafetyStatus();
    return Positioned(
      bottom: 180,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSafe ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isSafe ? 'SAFE' : 'STAY IN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BEGIN ALL REQUIRED FIELDS (deduplicated) ---
  List<Map<String, dynamic>> hourlyForecast = [];
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airData;
  bool isLoading = true;
  LatLng? selectedLocation;
  List<Map<String, dynamic>> locationSuggestions = [];
  String city = 'San Pedro, Laguna, Philippines';
  final MapController _mapController = MapController();
  double _currentZoom = 14.0;
  String _currentMapStyle = 'satellite';
  final bool _showSatelliteLayer = false;
  bool _showRainAnimation = false;
  bool _showHazardLocations = false;
  bool _showEvacuationCenters = false;
  bool _showGovernmentAgencies = false;
  bool _showAirQualityIndicator = false;
  final bool _showSafetyIndicator = false;
  // --- END ALL REQUIRED FIELDS ---

  // --- BEGIN CLEAN FORECAST SECTION (single version) ---
  // ...existing code...
  // --- END CLEAN FORECAST SECTION ---

  Widget buildHourlyForecast() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), // Reduced bottom margin
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 12), // Slightly reduced padding
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title with Updated badge
          Padding(
            padding: const EdgeInsets.only(
                left: 0, bottom: 8, top: 0, right: 0), // Less bottom padding
            child: Row(
              children: [
                const Text(
                  '24-Hour Forecast',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin:
                const EdgeInsets.symmetric(vertical: 4), // Less vertical margin
            padding: const EdgeInsets.symmetric(
                vertical: 6, horizontal: 0), // Less vertical padding
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.blueGrey,
                      displayColor: Colors.blueGrey,
                    ),
                iconTheme: IconThemeData(color: Colors.blueGrey.shade600),
              ),
              child: _buildTemperatureGraph(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureGraph() {
    // Show all 24 hours instead of just 12
    final displayData = hourlyForecast.take(24).toList();
    if (displayData.isEmpty) return const SizedBox();

    // Calculate temperature range
    final temps =
        displayData.map((e) => (e['temp']?.toDouble() ?? 0.0)).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;

    return Column(
      children: [
        // Temperature Graph
        SizedBox(
          height: 135,
          child: SingleChildScrollView(
            controller: _forecastScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: displayData.length * 85.0,
              child: CustomPaint(
                size: Size(displayData.length * 85.0, 135),
                painter: TemperatureGraphPainter(
                  data: displayData,
                  minTemp: minTemp,
                  maxTemp: maxTemp,
                  tempRange: tempRange,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Weather Icons Row (no wind speed)
        SizedBox(
          height: 64,
          child: SingleChildScrollView(
            controller: _forecastScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: displayData.asMap().entries.map((entry) {
                final index = entry.key;
                final forecast = entry.value;
                final icon = forecast['icon'] ?? '01d';
                return Container(
                  width: 85,
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 0,
                    right: index == displayData.length - 1 ? 16 : 0,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(
                              0.13), // Slightly darker for better icon visibility
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Image.network(
                          "https://openweathermap.org/img/wn/$icon.png",
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.wb_cloudy,
                              color: Colors.white,
                              size: 36,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Time Labels Row
        SizedBox(
          height: 27,
          child: SingleChildScrollView(
            controller: _forecastScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: displayData.asMap().entries.map((entry) {
                final index = entry.key;
                final forecast = entry.value;
                final time = forecast['time'] ?? '';
                String displayTime = "N/A";
                bool isNow = index == 0;
                if (time.isNotEmpty) {
                  try {
                    final dateTime = DateTime.parse(time);
                    if (isNow) {
                      displayTime = "Now";
                    } else {
                      displayTime =
                          "${dateTime.hour.toString().padLeft(2, '0')}:00";
                    }
                  } catch (e) {
                    displayTime = "${index}h";
                  }
                }
                return Container(
                  width: 85,
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 0,
                    right: index == displayData.length - 1 ? 16 : 0,
                  ),
                  child: Text(
                    displayTime,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: isNow ? 16 : 14,
                      fontWeight: isNow ? FontWeight.bold : FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Helper for forecast overlay tile URLs
  String _getForecastTileUrl(ForecastLayer layer) {
    const apiKey = 'a62db0fee1e1de12a993982cece6a6bc'; // OpenWeatherMap API key
    switch (layer) {
      case ForecastLayer.precipitation:
        return 'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=$apiKey';
      case ForecastLayer.clouds:
        return 'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=$apiKey';
      case ForecastLayer.temp:
        return 'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid=$apiKey';
      case ForecastLayer.wind:
        return 'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid=$apiKey';
      default:
        return '';
    }
  }

  ForecastLayer _forecastLayer = ForecastLayer.none;
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController =
      TextEditingController(text: "San Pedro, Laguna, Philippines");
  final GlobalKey _notificationButtonKey = GlobalKey();
  final GlobalKey _profileButtonKey = GlobalKey();

  // Notification dialog handler with sample admin-posted notifications
  // Helper methods for notification icon and color
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

  void _showNotifications() {
    if (!_authManager.isLoggedIn) {
      // User is not logged in, show a dialog/message with a Login button
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
                  Navigator.pop(context); // Close the dialog
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

  bool _showTemperatureHeatmap = false;
  bool _showWindArrows = false;
  final List<LatLng> _rainParticleLocations = [];
  final List<Map<String, dynamic>> _temperaturePoints = [];
  final List<Map<String, dynamic>> _windData = [];
  late AnimationController _rainAnimationController;
  late Animation<double> _rainAnimation;

  // Hazard locations in San Pedro, Laguna barangays with accurate coordinates
  final List<Map<String, dynamic>> _hazardLocations = [
    {
      'name': 'Barangay Riverside - Flood Risk',
      'type': 'flood',
      'location': LatLng(14.334500, 121.028400), // Aligned with SM San Pedro and Riverside evacuation centers
      'severity': 'high',
      'description':
          'High flood risk during heavy rainfall and typhoons due to proximity to Laguna de Bay',
    },
    {
      'name': 'Barangay San Vicente - Landslide Risk',
      'type': 'landslide',
      'location': LatLng(14.357300, 121.048300), // Aligned with San Vicente Isolation Facility coordinates
      'severity': 'medium',
      'description':
          'Moderate landslide risk on steep slopes in hillside areas',
    },
    {
      'name': 'Pacita Complex - Heat Island',
      'type': 'heat',
      'location': LatLng(14.349700, 121.058900), // Aligned with Pacita Square area
      'severity': 'medium',
      'description':
          'Urban heat island effect during summer months in dense residential area',
    },
    {
      'name': 'Barangay Landayan - Air Quality',
      'type': 'air_pollution',
      'location': LatLng(14.352600, 121.067000), // Aligned with Landayan evacuation centers
      'severity': 'medium',
      'description':
          'Elevated air pollution levels from commercial activities and heavy traffic',
    },
    {
      'name': 'Barangay Poblacion - Storm Surge',
      'type': 'storm_surge',
      'location': LatLng(14.363000, 121.058800), // Aligned with Poblacion Covered Court
      'severity': 'high',
      'description':
          'High storm surge risk during typhoons affecting central low-lying areas',
    },
    {
      'name': 'West Valley Fault Zone - Earthquake Risk',
      'type': 'earthquake',
      'location': LatLng(14.344500, 121.035600), // Positioned in Sampaguita area along fault line
      'severity': 'high',
      'description':
          'Near West Valley Fault line - earthquake preparedness required for all residents',
    },
  ];

  // Evacuation centers in San Pedro, Laguna
  final List<Map<String, dynamic>> _evacuationCenters = [
    {
      'name': 'Rosario Complex Multi-Purpose Evacuation',
      'location': LatLng(14.336771, 121.048821),
      'capacity': 400,
      'families': 80,
      'type': 'government',
      'facilities': ['Multi-Purpose Hall', 'Medical', 'Kitchen', 'Communications'],
      'description': 'Multi-purpose evacuation center with full facilities'
    },
    {
      'name': 'San Pedro Town Center',
      'location': LatLng(14.3675, 121.0507),
      'capacity': 200,
      'families': 40,
      'type': 'commercial',
      'facilities': ['Large Space', 'Restrooms', 'Security'],
      'description': 'Commercial evacuation center in town center area'
    },
    {
      'name': 'City Plaza',
      'location': LatLng(14.364022, 121.056847),
      'capacity': 200,
      'families': 40,
      'type': 'government',
      'facilities': ['Open Space', 'Basic Shelter', 'Water'],
      'description': 'City plaza evacuation area with basic facilities'
    },
    {
      'name': 'CDRRM Complex',
      'location': LatLng(14.365262, 121.057283),
      'capacity': 200,
      'families': 40,
      'type': 'government',
      'facilities': ['Emergency Operations', 'Communications', 'Medical', 'Supplies'],
      'description': 'City Disaster Risk Reduction Management complex'
    },
    {
      'name': 'City Sports Center',
      'location': LatLng(14.3350, 121.0450),
      'capacity': 400,
      'families': 80,
      'type': 'sports',
      'facilities': ['Large Sports Hall', 'Restrooms', 'Parking', 'Kitchen'],
      'description': 'Large capacity sports center for major emergencies'
    },
    {
      'name': 'Barangay Bagong Silang Elementary School',
      'location': LatLng(14.335576, 121.024305),
      'capacity': 100,
      'families': 20,
      'type': 'school',
      'facilities': ['Classrooms', 'Basic Shelter', 'Water', 'Restrooms'],
      'description': 'Elementary school evacuation center in Bagong Silang'
    },
    {
      'name': 'Madrigal Multi-purpose Hall',
      'location': LatLng(14.335703, 121.026632),
      'capacity': 40,
      'families': 8,
      'type': 'community',
      'facilities': ['Hall Space', 'Basic Shelter', 'Water'],
      'description': 'Multi-purpose hall for small group evacuations in Bagong Silang'
    },
    {
      'name': 'Barangay Calendola Covered Court',
      'location': LatLng(14.342129, 121.034627),
      'capacity': 485,
      'families': 83,
      'type': 'sports',
      'facilities': ['Covered Court', 'Large Space', 'Restrooms', 'Water'],
      'description': 'Large covered court evacuation center in Calendola'
    },
    {
      'name': 'St. Raymond Homes Club House',
      'location': LatLng(14.338602, 121.032836),
      'capacity': 335,
      'families': 79,
      'type': 'community',
      'facilities': ['Club House', 'Meeting Rooms', 'Kitchen', 'Restrooms'],
      'description': 'Residential club house evacuation center in Calendola'
    },
    {
      'name': 'Chrysanthemum Village Elementary School',
      'location': LatLng(14.341489, 121.043739),
      'capacity': 328,
      'families': 38,
      'type': 'school',
      'facilities': ['Classrooms', 'Playground', 'Water', 'Restrooms'],
      'description': 'Elementary school evacuation center in Chrysanthemum Village'
    },
    {
      'name': 'Pili Street Phase 3 Covered Court',
      'location': LatLng(14.340336, 121.047576),
      'capacity': 200,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water'],
      'description': 'Covered court evacuation center in Pili Street Phase 3'
    },
    {
      'name': 'Florentina Street Phase 2 Covered Court',
      'location': LatLng(14.334357, 121.047518),
      'capacity': 200,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water'],
      'description': 'Covered court evacuation center in Florentina Street Phase 2'
    },
    {
      'name': 'Cuyab Covered Court',
      'location': LatLng(14.371669, 121.059093),
      'capacity': 150,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basketball Court', 'Basic Shelter', 'Water'],
      'description': 'Covered court evacuation center in Barangay Cuyab'
    },
    {
      'name': 'Barangay Estrella Session Hall',
      'location': LatLng(14.335198, 121.013571),
      'capacity': 50,
      'families': 20,
      'type': 'government',
      'facilities': ['Session Hall', 'Meeting Room', 'Basic Shelter', 'Water'],
      'description': 'Barangay session hall evacuation center in Estrella'
    },
    {
      'name': 'Estrella Multi-Purpose Hall',
      'location': LatLng(14.333917, 121.018022),
      'capacity': 30,
      'families': 10,
      'type': 'community',
      'facilities': ['Multi-Purpose Hall', 'Basic Shelter', 'Water'],
      'description': 'Community multi-purpose hall in Barangay Estrella'
    },
    {
      'name': 'Barangay Estrella Covered Court',
      'location': LatLng(14.335153, 121.019765),
      'capacity': 200,
      'families': 80,
      'type': 'sports',
      'facilities': ['Covered Court', 'Large Space', 'Restrooms', 'Water'],
      'description': 'Large covered court evacuation center in Barangay Estrella'
    },
    {
      'name': 'Elvind Village Covered Court',
      'location': LatLng(14.311647, 121.032982),
      'capacity': 48,
      'families': 12,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water'],
      'description': 'Village covered court evacuation center in Barangay Fatima'
    },
    {
      'name': 'Covered Court Phase 5 Olivarez Homes',
      'location': LatLng(14.312645, 121.031130),
      'capacity': 48,
      'families': 12,
      'type': 'sports',
      'facilities': ['Covered Court', 'Residential Area', 'Water'],
      'description': 'Residential covered court in Olivarez Homes Phase 5, Barangay Fatima'
    },
    {
      'name': 'GSIS-HOA Multi-Purpose Center',
      'location': LatLng(14.349783, 121.041388),
      'capacity': 60,
      'families': 20,
      'type': 'community',
      'facilities': ['Multi-Purpose Hall', 'Meeting Rooms', 'Kitchen', 'Water'],
      'description': 'HOA multi-purpose center evacuation facility in Barangay GSIS'
    },
    {
      'name': 'Independence Drive Covered Court',
      'location': LatLng(14.349992, 121.041402),
      'capacity': 120,
      'families': 40,
      'type': 'sports',
      'facilities': ['Covered Court', 'Large Space', 'Restrooms', 'Water'],
      'description': 'Covered court evacuation center on Independence Drive, GSIS'
    },
    {
      'name': 'Park View Subdivision Covered Court',
      'location': LatLng(14.350033, 121.037597),
      'capacity': 120,
      'families': 40,
      'type': 'sports',
      'facilities': ['Covered Court', 'Subdivision Facility', 'Water', 'Parking'],
      'description': 'Subdivision covered court in Park View, Barangay GSIS'
    },
    {
      'name': 'Easter Circle Ground',
      'location': LatLng(14.349985, 121.041390),
      'capacity': 100,
      'families': 35,
      'type': 'community',
      'facilities': ['Open Ground', 'Emergency Assembly Area', 'Water Access'],
      'description': 'Open ground emergency assembly area near Easter Circle, GSIS'
    },
    {
      'name': 'Barangay Landayan Covered Court',
      'location': LatLng(14.35226, 121.06768),
      'capacity': 700,
      'families': 150,
      'type': 'sports',
      'facilities': ['Large Covered Court', 'Restrooms', 'Water', 'Parking'],
      'description': 'Major covered court evacuation center in Barangay Landayan'
    },
    {
      'name': 'Barangay Landayan Evacuation Center',
      'location': LatLng(14.35308, 121.06625),
      'capacity': 250,
      'families': 50,
      'type': 'government',
      'facilities': ['Evacuation Center', 'Medical Bay', 'Kitchen', 'Communications'],
      'description': 'Dedicated evacuation center facility in Barangay Landayan'
    },
    {
      'name': 'PEA 2A Covered Court',
      'location': LatLng(14.330897, 121.021147),
      'capacity': 120,
      'families': 40,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water'],
      'description': 'PEA subdivision covered court in Barangay Langgam'
    },
    {
      'name': 'PEA 2B Covered Court',
      'location': LatLng(14.330086, 121.020453),
      'capacity': 90,
      'families': 30,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water'],
      'description': 'PEA 2B subdivision covered court in Barangay Langgam'
    },
    {
      'name': 'Alitaptap Half Court',
      'location': LatLng(14.330115, 121.01931),
      'capacity': 30,
      'families': 10,
      'type': 'sports',
      'facilities': ['Half Court', 'Basic Shelter', 'Water'],
      'description': 'Alitaptap area half court evacuation point in Langgam'
    },
    {
      'name': 'Saint Joseph Village 10 Phase 1 Covered Court',
      'location': LatLng(14.32700, 121.01644),
      'capacity': 120,
      'families': 40,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Center', 'Water', 'Restrooms'],
      'description': 'Village covered court in Saint Joseph Village 10 Phase 1'
    },
    {
      'name': 'Saint Joseph Village 10 Phase 2 Club House',
      'location': LatLng(14.326996, 121.016323),
      'capacity': 30,
      'families': 10,
      'type': 'community',
      'facilities': ['Club House', 'Meeting Room', 'Basic Shelter'],
      'description': 'Village club house in Saint Joseph Village 10 Phase 2'
    },
    {
      'name': 'Saint Joseph Village 10 Phase 3 Club House',
      'location': LatLng(14.325968, 121.012878),
      'capacity': 60,
      'families': 20,
      'type': 'community',
      'facilities': ['Club House', 'Meeting Room', 'Kitchen', 'Water'],
      'description': 'Village club house in Saint Joseph Village 10 Phase 3'
    },
    {
      'name': 'Saint Joseph Village 9 Phase 1 Club House',
      'location': LatLng(14.328784, 121.017676),
      'capacity': 15,
      'families': 5,
      'type': 'community',
      'facilities': ['Small Club House', 'Meeting Room', 'Basic Shelter'],
      'description': 'Village club house in Saint Joseph Village 9 Phase 1'
    },
    {
      'name': 'Barangay Laram Covered Court',
      'location': LatLng(14.329611, 121.023722),
      'capacity': 225,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Large Space', 'Restrooms', 'Water'],
      'description': 'Main covered court evacuation center in Barangay Laram'
    },
    {
      'name': 'Laram Parking Area',
      'location': LatLng(14.328917, 121.022944),
      'capacity': 225,
      'families': 50,
      'type': 'community',
      'facilities': ['Open Parking Area', 'Emergency Assembly Point', 'Vehicle Access'],
      'description': 'Large parking area for emergency assembly in Barangay Laram'
    },
    {
      'name': 'Multi-Purpose Hall Near Argana Compound',
      'location': LatLng(14.330056, 121.023139),
      'capacity': 30,
      'families': 6,
      'type': 'community',
      'facilities': ['Multi-Purpose Hall', 'Meeting Room', 'Basic Shelter'],
      'description': 'Multi-purpose hall near Argana Compound in Barangay Laram'
    },
    {
      'name': 'San Antonio de Padua Chapel',
      'location': LatLng(14.19463, 121.01276),
      'capacity': 40,
      'families': 8,
      'type': 'religious',
      'facilities': ['Chapel', 'Shelter', 'Water', 'Community Space'],
      'description': 'Religious facility evacuation center in Barangay Laram'
    },
    {
      'name': 'Adelina 2 Covered Court Maharlika',
      'location': LatLng(14.346413, 121.045933),
      'capacity': 250,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Large Space', 'Restrooms', 'Water'],
      'description': 'Adelina 2 subdivision covered court in Barangay Maharlika'
    },
    {
      'name': 'Villa Olympia 1A Covered Court',
      'location': LatLng(14.342981, 121.043327),
      'capacity': 250,
      'families': 50,
      'type': 'sports',
      'facilities': ['Covered Court', 'Villa Complex', 'Water', 'Security'],
      'description': 'Villa Olympia phase 1A covered court in Barangay Maharlika'
    },
    {
      'name': 'Mercedes Homes Open Court',
      'location': LatLng(14.349717, 121.046181),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water', 'Basic Shelter'],
      'description': 'Mercedes Homes open court evacuation area in Barangay Maharlika'
    },
    {
      'name': 'Harmony Homes Court',
      'location': LatLng(14.33905, 121.03952),
      'capacity': 250,
      'families': 50,
      'type': 'sports',
      'facilities': ['Court Facility', 'Residential Complex', 'Water', 'Restrooms'],
      'description': 'Harmony Homes court evacuation center in Barangay Maharlika'
    },
    {
      'name': 'Purok 2 Covered Court Magsaysay',
      'location': LatLng(14.336508, 121.033557),
      'capacity': 600,
      'families': 200,
      'type': 'sports',
      'facilities': ['Large Covered Court', 'Restrooms', 'Water', 'Parking'],
      'description': 'Major covered court evacuation center in Purok 2, Barangay Magsaysay'
    },
    {
      'name': 'Purok 6 Court Magsaysay',
      'location': LatLng(14.335962, 121.034522),
      'capacity': 200,
      'families': 100,
      'type': 'sports',
      'facilities': ['Court Facility', 'Basic Shelter', 'Water'],
      'description': 'Court evacuation center in Purok 6, Barangay Magsaysay'
    },
    {
      'name': 'Magsaysay Daycare Main',
      'location': LatLng(14.337873, 121.032947),
      'capacity': 25,
      'families': 5,
      'type': 'government',
      'facilities': ['Daycare Center', 'Child-Friendly Space', 'Basic Shelter'],
      'description': 'Main daycare center evacuation point in Barangay Magsaysay'
    },
    {
      'name': 'Magsaysay Daycare Annex',
      'location': LatLng(14.335735, 121.034522),
      'capacity': 25,
      'families': 5,
      'type': 'government',
      'facilities': ['Daycare Annex', 'Child-Friendly Space', 'Basic Shelter'],
      'description': 'Daycare annex evacuation point in Barangay Magsaysay'
    },
    {
      'name': 'BADAC Office Magsaysay',
      'location': LatLng(14.335735, 121.028453),
      'capacity': 15,
      'families': 2,
      'type': 'government',
      'facilities': ['Government Office', 'Meeting Room', 'Communications'],
      'description': 'BADAC office evacuation point in Barangay Magsaysay'
    },
    {
      'name': 'SK Building Magsaysay',
      'location': LatLng(14.336508, 121.033557),
      'capacity': 50,
      'families': 10,
      'type': 'government',
      'facilities': ['SK Office', 'Meeting Hall', 'Basic Shelter'],
      'description': 'Sangguniang Kabataan building evacuation center in Barangay Magsaysay'
    },
    {
      'name': 'Multi-Purpose Hall Purok 2 Magsaysay',
      'location': LatLng(14.337119, 121.033535),
      'capacity': 75,
      'families': 25,
      'type': 'community',
      'facilities': ['Multi-Purpose Hall', 'Community Space', 'Kitchen', 'Water'],
      'description': 'Multi-purpose hall evacuation center in Purok 2, Barangay Magsaysay'
    },
    {
      'name': 'Church Main Road Narra',
      'location': LatLng(14.331387, 121.026628),
      'capacity': 300,
      'families': 25,
      'type': 'religious',
      'facilities': ['Church Building', 'Large Hall', 'Kitchen', 'Restrooms'],
      'description': 'Church evacuation center on Main Road in Barangay Narra'
    },
    {
      'name': 'Narra Covered Court',
      'location': LatLng(14.331396, 121.026247),
      'capacity': 100,
      'families': 15,
      'type': 'sports',
      'facilities': ['Covered Court', 'Basic Shelter', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Barangay Narra'
    },
    {
      'name': 'Barangay Nueva Covered Court',
      'location': LatLng(14.358283, 121.057762),
      'capacity': 500,
      'families': 20,
      'type': 'sports',
      'facilities': ['Large Covered Court', 'Multi-Purpose Space', 'Restrooms', 'Water', 'Parking'],
      'description': 'Major covered court evacuation center in Barangay Nueva'
    },
    {
      'name': 'Pacita 1 Convention Center',
      'location': LatLng(14.345044, 121.056026),
      'capacity': 150,
      'families': 30,
      'type': 'commercial',
      'facilities': ['Convention Hall', 'Meeting Rooms', 'Kitchen', 'Restrooms', 'Parking'],
      'description': 'Convention center evacuation facility in Barangay Pacita 1'
    },
    {
      'name': 'Pacita 1 Covered Court',
      'location': LatLng(14.340247, 121.0522),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Barangay Pacita 1'
    },
    {
      'name': 'Pacita 2 Multi-Purpose Evacuation Center',
      'location': LatLng(14.3498, 121.0482),
      'capacity': 120,
      'families': 30,
      'type': 'community',
      'facilities': ['Multi-Purpose Hall', 'Meeting Rooms', 'Kitchen', 'Restrooms', 'Water'],
      'description': 'Main multi-purpose evacuation facility in Barangay Pacita 2'
    },
    {
      'name': 'Pacita 2 Covered Court',
      'location': LatLng(14.3501, 121.0486),
      'capacity': 160,
      'families': 40,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Barangay Pacita 2'
    },
    {
      'name': 'South View Homes Open Space/Open Court',
      'location': LatLng(14.3475, 121.0504),
      'capacity': 160,
      'families': 40,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open space evacuation area in South View Homes, Barangay Pacita 2'
    },
    {
      'name': 'Pacita Square Open Court',
      'location': LatLng(14.3497, 121.0589),
      'capacity': 160,
      'families': 40,
      'type': 'sports',
      'facilities': ['Open Court', 'Public Square', 'Water Access'],
      'description': 'Open court evacuation center at Pacita Square, Barangay Pacita 2'
    },
    {
      'name': 'Pacita 2-C Open Court',
      'location': LatLng(14.3475, 121.0567),
      'capacity': 120,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open court evacuation center in Pacita 2-C area'
    },
    {
      'name': 'Sto. Niño Open Court',
      'location': LatLng(14.3537, 121.0563),
      'capacity': 120,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open court evacuation center near Sto. Niño area, Barangay Pacita 2'
    },
    {
      'name': 'Phase 1 Flamingo Open Court',
      'location': LatLng(14.3503, 121.0515),
      'capacity': 80,
      'families': 20,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open court evacuation center in Phase 1 Flamingo area, Barangay Pacita 2'
    },
    {
      'name': 'Pacita 2 Elementary School',
      'location': LatLng(14.3496, 121.0478),
      'capacity': 240,
      'families': 60,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay Pacita 2'
    },
    {
      'name': 'Poblacion Covered Court',
      'location': LatLng(14.362926, 121.058856),
      'capacity': 50,
      'families': 10,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Barangay Poblacion'
    },
    {
      'name': 'Central Elem School Covered Court Poblacion',
      'location': LatLng(14.363018, 121.058759),
      'capacity': 100,
      'families': 20,
      'type': 'educational',
      'facilities': ['School Covered Court', 'Classrooms', 'Restrooms', 'Water', 'Playground'],
      'description': 'Central Elementary School covered court evacuation center in Barangay Poblacion'
    },
    {
      'name': 'SM San Pedro',
      'location': LatLng(14.333950, 121.028111),
      'capacity': 120,
      'families': 25,
      'type': 'commercial',
      'facilities': ['Shopping Mall', 'Large Spaces', 'Food Court', 'Restrooms', 'Water', 'Parking'],
      'description': 'SM San Pedro shopping mall evacuation center in Barangay Riverside'
    },
    {
      'name': 'Barangay Hall Covered Court Riverside',
      'location': LatLng(14.335008, 121.028755),
      'capacity': 75,
      'families': 15,
      'type': 'government',
      'facilities': ['Covered Court', 'Barangay Office', 'Meeting Hall', 'Restrooms', 'Water'],
      'description': 'Barangay Hall covered court evacuation center in Barangay Riverside'
    },
    {
      'name': 'Roof Top Barangay Hall Riverside',
      'location': LatLng(14.334936, 121.028569),
      'capacity': 50,
      'families': 10,
      'type': 'government',
      'facilities': ['Rooftop Space', 'Open Area', 'Water Access', 'Emergency Shelter'],
      'description': 'Rooftop evacuation area at Barangay Hall in Barangay Riverside'
    },
    {
      'name': 'Covered Court at Rosario Complex',
      'location': LatLng(14.336360, 121.048521),
      'capacity': 200,
      'families': 150,
      'type': 'sports',
      'facilities': ['Covered Court', 'Complex Facilities', 'Restrooms', 'Water', 'Parking'],
      'description': 'Covered court evacuation center at Rosario Complex in Barangay Rosario'
    },
    {
      'name': 'Rosario Evacuation Center',
      'location': LatLng(14.336771, 121.048821),
      'capacity': 400,
      'families': 150,
      'type': 'community',
      'facilities': ['Dedicated Evacuation Center', 'Large Hall', 'Kitchen', 'Restrooms', 'Water', 'Emergency Supplies'],
      'description': 'Main evacuation center in Barangay Rosario'
    },
    {
      'name': 'Rosario Elementary School',
      'location': LatLng(14.336067, 121.048325),
      'capacity': 400,
      'families': 150,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay Rosario'
    },
    {
      'name': 'Sampaguita Covered Court',
      'location': LatLng(14.344471, 121.035574),
      'capacity': 1000,
      'families': 200,
      'type': 'sports',
      'facilities': ['Large Covered Court', 'Community Space', 'Restrooms', 'Water', 'Parking'],
      'description': 'Major covered court evacuation center in Barangay Sampaguita'
    },
    {
      'name': 'Villa Rita Basketball Court',
      'location': LatLng(14.34214, 121.034064),
      'capacity': 200,
      'families': 40,
      'type': 'sports',
      'facilities': ['Basketball Court', 'Open Space', 'Water Access'],
      'description': 'Basketball court evacuation center in Villa Rita, Barangay Sampaguita'
    },
    {
      'name': 'Filinvest South Peak Open Space',
      'location': LatLng(14.345251, 121.034064),
      'capacity': 20,
      'families': 4,
      'type': 'open',
      'facilities': ['Open Space', 'Community Area'],
      'description': 'Open space evacuation area in Filinvest South Peak, Barangay Sampaguita'
    },
    {
      'name': 'Barangay Tennis Court Sampaguita',
      'location': LatLng(14.344585, 121.035115),
      'capacity': 200,
      'families': 40,
      'type': 'sports',
      'facilities': ['Tennis Court', 'Sports Complex', 'Water Access'],
      'description': 'Tennis court evacuation center in Barangay Sampaguita'
    },
    {
      'name': 'Purok Manggahan Entrance',
      'location': LatLng(14.343982, 121.033049),
      'capacity': 200,
      'families': 40,
      'type': 'community',
      'facilities': ['Community Entrance Area', 'Open Space', 'Water Access'],
      'description': 'Evacuation center at Purok Manggahan entrance in Barangay Sampaguita'
    },
    {
      'name': 'Villa Fatima Open Space',
      'location': LatLng(14.347038, 121.037212),
      'capacity': 200,
      'families': 40,
      'type': 'open',
      'facilities': ['Open Space', 'Community Area', 'Water Access'],
      'description': 'Open space evacuation area in Villa Fatima, Barangay Sampaguita'
    },
    {
      'name': 'Jaka Basketball Covered Court',
      'location': LatLng(14.342086, 121.03053),
      'capacity': 350,
      'families': 70,
      'type': 'sports',
      'facilities': ['Covered Basketball Court', 'Sports Facility', 'Restrooms', 'Water'],
      'description': 'Covered basketball court evacuation center in Jaka area, Barangay Sampaguita'
    },
    {
      'name': 'New Barangay Hall San Antonio',
      'location': LatLng(14.36702, 121.056266),
      'capacity': 100,
      'families': 20,
      'type': 'government',
      'facilities': ['Barangay Hall', 'Meeting Rooms', 'Office Space', 'Restrooms', 'Water'],
      'description': 'New Barangay Hall evacuation center in Barangay San Antonio'
    },
    {
      'name': 'San Antonio Elementary School',
      'location': LatLng(14.36752, 121.05674),
      'capacity': 350,
      'families': 70,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay San Antonio'
    },
    {
      'name': 'Greatland Covered Court',
      'location': LatLng(14.350823, 121.050964),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Greatland area, Barangay San Lorenzo Ruiz'
    },
    {
      'name': 'Compil 1 Covered Court',
      'location': LatLng(14.350823, 121.050964),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Compil 1 area, Barangay San Lorenzo Ruiz'
    },
    {
      'name': 'Pacita 2B Covered Court',
      'location': LatLng(14.350823, 121.050964),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Pacita 2B area, Barangay San Lorenzo Ruiz'
    },
    {
      'name': 'Pacita 2A Open Court',
      'location': LatLng(14.351575, 121.052678),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open court evacuation center in Pacita 2A area, Barangay San Lorenzo Ruiz'
    },
    {
      'name': 'Guevarra Subdivision Open Court',
      'location': LatLng(14.350856, 121.052949),
      'capacity': 150,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Court', 'Community Space', 'Water Access'],
      'description': 'Open court evacuation center in Guevarra Subdivision, Barangay San Lorenzo Ruiz'
    },
    {
      'name': 'Covered Court at San Roque near Barangay Hall',
      'location': LatLng(14.36648667, 121.06171000),
      'capacity': 400,
      'families': 80,
      'type': 'sports',
      'facilities': ['Covered Court', 'Near Barangay Hall', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center near Barangay Hall in Barangay San Roque'
    },
    {
      'name': 'San Roque Elementary School',
      'location': LatLng(14.36656167, 121.06183000),
      'capacity': 400,
      'families': 80,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay San Roque'
    },
    {
      'name': 'Barangay Hall Sto. Niño',
      'location': LatLng(14.36680, 121.05786),
      'capacity': 32,
      'families': 8,
      'type': 'government',
      'facilities': ['Barangay Hall', 'Meeting Rooms', 'Office Space', 'Restrooms', 'Water'],
      'description': 'Barangay Hall evacuation center in Barangay Sto. Niño'
    },
    {
      'name': 'Sto Niño Elementary School',
      'location': LatLng(14.36783, 121.05929),
      'capacity': 264,
      'families': 66,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay Sto. Niño'
    },
    {
      'name': 'Laguerta Covered Court',
      'location': LatLng(14.361557, 121.052334),
      'capacity': 60,
      'families': 12,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Laguerta area, Barangay San Vicente'
    },
    {
      'name': 'San Vicente Elementary School',
      'location': LatLng(14.359762, 121.056009),
      'capacity': 250,
      'families': 50,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in Barangay San Vicente'
    },
    {
      'name': 'Isolation Facility at Old Barangay Hall San Vicente',
      'location': LatLng(14.357331, 121.048288),
      'capacity': 50,
      'families': 10,
      'type': 'government',
      'facilities': ['Isolation Facility', 'Old Barangay Hall', 'Medical Support', 'Restrooms', 'Water'],
      'description': 'Isolation facility at old Barangay Hall in Barangay San Vicente'
    },
    {
      'name': 'San Isidro Village Elementary School',
      'location': LatLng(14.342375, 121.0235988),
      'capacity': 200,
      'families': 40,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Elementary school evacuation center in San Isidro Village, Barangay San Vicente'
    },
    {
      'name': 'San Isidro Labrador Chapel',
      'location': LatLng(14.323624, 121.0235766),
      'capacity': 60,
      'families': 12,
      'type': 'religious',
      'facilities': ['Chapel', 'Religious Hall', 'Community Space', 'Water'],
      'description': 'Chapel evacuation center in San Isidro Labrador area, Barangay San Vicente'
    },
    {
      'name': 'Sitio Bagong Pag-asa Covered Court',
      'location': LatLng(14.33340, 121.03003),
      'capacity': 50,
      'families': 10,
      'type': 'sports',
      'facilities': ['Covered Court', 'Community Space', 'Water', 'Restrooms'],
      'description': 'Covered court evacuation center in Sulo Bayang Pag-asa area, Barangay UB'
    },
    {
      'name': 'Laguna Resettlement School',
      'location': LatLng(14.33359, 121.03003),
      'capacity': 350,
      'families': 70,
      'type': 'educational',
      'facilities': ['Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water', 'Playground'],
      'description': 'Resettlement school evacuation center in Barangay UB'
    },
    {
      'name': 'Dreamland Heights Subdivision Court',
      'location': LatLng(14.33611, 121.02971),
      'capacity': 50,
      'families': 10,
      'type': 'sports',
      'facilities': ['Subdivision Court', 'Community Space', 'Water Access'],
      'description': 'Subdivision court evacuation center in Dreamland Heights, Barangay UB'
    },
    {
      'name': 'PUP School UB',
      'location': LatLng(14.33447, 121.02923),
      'capacity': 250,
      'families': 50,
      'type': 'educational',
      'facilities': ['University Facilities', 'Classrooms', 'Gymnasium', 'Cafeteria', 'Restrooms', 'Water'],
      'description': 'PUP school evacuation center in Barangay UB'
    },
    {
      'name': 'SM San Pedro UB',
      'location': LatLng(14.33424, 121.02844),
      'capacity': 500,
      'families': 100,
      'type': 'commercial',
      'facilities': ['Shopping Mall', 'Large Spaces', 'Food Court', 'Restrooms', 'Water', 'Parking'],
      'description': 'SM San Pedro shopping mall evacuation center in Barangay UB'
    },
    {
      'name': 'Barangay UB Daycare',
      'location': LatLng(14.33406, 121.02995),
      'capacity': 20,
      'families': 4,
      'type': 'educational',
      'facilities': ['Daycare Center', 'Childcare Facilities', 'Water', 'Restrooms'],
      'description': 'Daycare center evacuation facility in Barangay UB'
    },
    {
      'name': 'Rosa 1 Court',
      'location': LatLng(14.33672, 121.02955),
      'capacity': 30,
      'families': 6,
      'type': 'sports',
      'facilities': ['Community Court', 'Open Space', 'Water Access'],
      'description': 'Community court evacuation center in Roza 1 area, Barangay UB'
    },
    {
      'name': 'Rosa 2 Court',
      'location': LatLng(14.33716, 121.02916),
      'capacity': 15,
      'families': 3,
      'type': 'sports',
      'facilities': ['Community Court', 'Open Space', 'Water Access'],
      'description': 'Community court evacuation center in Roza 2 area, Barangay UB'
    },
    {
      'name': 'Zone 4 Multi-purpose Hall',
      'location': LatLng(14.33365, 121.02916),
      'capacity': 30,
      'families': 6,
      'type': 'community',
      'facilities': ['Multi-purpose Hall', 'Community Space', 'Meeting Room', 'Water', 'Restrooms'],
      'description': 'Multi-purpose hall evacuation center in Purok 4, Barangay UB'
    },
    {
      'name': 'Barangay Basketball Court UBL',
      'location': LatLng(14.337377, 121.023778),
      'capacity': 100,
      'families': 30,
      'type': 'sports',
      'facilities': ['Basketball Court', 'Open Space', 'Water Access'],
      'description': 'Basketball court evacuation center in Barangay United Better Living (UBL)'
    },
    {
      'name': 'Southern Heights II Open Basketball Court',
      'location': LatLng(14.337196, 121.023672),
      'capacity': 100,
      'families': 30,
      'type': 'sports',
      'facilities': ['Open Basketball Court', 'Block 3A Area', 'Community Space', 'Water Access'],
      'description': 'Open basketball court evacuation center in Southern Heights II Blk 3A, Barangay UBL'
    },
    {
      'name': 'Barangay Health Center/Day Care Center UBL',
      'location': LatLng(14.337518, 121.02377),
      'capacity': 25,
      'families': 8,
      'type': 'medical',
      'facilities': ['Health Center', 'Day Care Center', 'Medical Facilities', 'Restrooms', 'Water'],
      'description': 'Health center and day care evacuation facility in Barangay UBL'
    },
  ];

  // Government agencies in San Pedro, Laguna (Fire and Police Stations)
  final List<Map<String, dynamic>> _governmentAgencies = [
    {
      'name': 'San Pedro City Fire Station - BFP',
      'location': LatLng(14.34516839884017, 121.06266445864843),
      'type': 'fire_station',
      'contact': 'Emergency: 911',
      'facilities': ['Fire Trucks', 'Emergency Response', '24/7 Service', 'Rescue Equipment'],
      'description': 'Main Bureau of Fire Protection station serving San Pedro City'
    },
    {
      'name': 'BFP San Pedro City Fire Station (North)',
      'location': LatLng(14.364343096714173, 121.05738372854574),
      'type': 'fire_station',
      'contact': 'Emergency: 911',
      'facilities': ['Fire Trucks', 'Emergency Response', '24/7 Service', 'First Aid'],
      'description': 'Bureau of Fire Protection station serving northern San Pedro areas'
    },
    {
      'name': 'BFP San Pedro City Fire Station (Central)',
      'location': LatLng(14.365029061924009, 121.05759830525388),
      'type': 'fire_station',
      'contact': 'Emergency: 911',
      'facilities': ['Fire Trucks', 'Emergency Response', '24/7 Service', 'Specialized Equipment'],
      'description': 'Bureau of Fire Protection station serving central San Pedro areas'
    },
    {
      'name': 'San Pedro City Police Station',
      'location': LatLng(14.363131922911142, 121.05757373747483),
      'type': 'police_station',
      'contact': 'Emergency: 911',
      'facilities': ['24/7 Police Service', 'Emergency Response', 'Crime Investigation', 'Traffic Enforcement'],
      'description': 'Main San Pedro City Police Station providing law enforcement services'
    },
    {
      'name': 'Police Station (Barangay Unit)',
      'location': LatLng(14.329704212866993, 121.03463366815814),
      'type': 'police_station',
      'contact': 'Emergency: 911',
      'facilities': ['Community Policing', 'Emergency Response', 'Local Security', 'Crime Prevention'],
      'description': 'Barangay police unit providing local law enforcement services'
    },
    {
      'name': 'San Pedro Police Station Head Quarters',
      'location': LatLng(14.365352558890569, 121.05740279884132),
      'type': 'police_station',
      'contact': 'Emergency: 911',
      'facilities': ['Police Headquarters', 'Administrative Services', 'Emergency Command', 'Investigation Units'],
      'description': 'San Pedro Police Station Headquarters - main command center'
    },
    {
      'name': 'San Pedro Police (Station 2)',
      'location': LatLng(14.350430051543146, 121.02750894486623),
      'type': 'police_station',
      'contact': 'Emergency: 911',
      'facilities': ['Police Services', 'Emergency Response', 'Community Safety', 'Crime Prevention'],
      'description': 'San Pedro Police Station providing security services to western areas'
    },
    {
      'name': 'Old San Pedro Municipal Hall Bldg',
      'location': LatLng(14.364588172639383, 121.05740637137525),
      'type': 'city_hall',
      'contact': 'Administrative Services',
      'facilities': ['Government Services', 'Administrative Offices', 'Public Records', 'Municipal Services'],
      'description': 'Former municipal hall building providing government administrative services'
    },
    {
      'name': 'San Pedro City Hall',
      'location': LatLng(14.363361746093352, 121.06021732625193),
      'type': 'city_hall',
      'contact': 'Administrative Services',
      'facilities': ['City Government Offices', 'Administrative Services', 'Public Records', 'Municipal Services', 'Mayor\'s Office'],
      'description': 'Main San Pedro City Hall - center of city government administration'
    },
    // Barangay Halls
    {
      'name': 'Bagong Silang Barangay Hall',
      'location': LatLng(14.335886660238907, 121.02686750976196),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Bagong Silang Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Hall Calendola',
      'location': LatLng(14.343466490944863, 121.03597248092653),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Calendola Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Chrysanthemum',
      'location': LatLng(14.341636833586847, 121.04511339448426),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Chrysanthemum Barangay Hall providing local government services'
    },
    {
      'name': 'Cuyab Barangay Hall',
      'location': LatLng(14.374727543775055, 121.0572017116103),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Cuyab Barangay Hall providing local government services'
    },
    {
      'name': 'Estrella Barangay Hall',
      'location': LatLng(14.335145439196346, 121.01954834229292),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Estrella Barangay Hall providing local government services'
    },
    {
      'name': 'Fatima Barangay Hall',
      'location': LatLng(14.354711882063242, 121.05563552695152),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Fatima Barangay Hall providing local government services'
    },
    {
      'name': 'Brgy Hall GSIS San Pedro, Laguna',
      'location': LatLng(14.35000090347985, 121.04157244414111),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'GSIS Barangay Hall providing local government services'
    },
    {
      'name': 'Landayan Barangay Hall',
      'location': LatLng(14.352310607983583, 121.06764132510376),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Landayan Barangay Hall providing local government services'
    },
    {
      'name': 'Langgam Barangay Hall',
      'location': LatLng(14.328746670145382, 121.01772957847696),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Langgam Barangay Hall providing local government services'
    },
    {
      'name': 'Laram Barangay Hall',
      'location': LatLng(14.329539516783225, 121.02320432510356),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Laram Barangay Hall providing local government services'
    },
    {
      'name': 'Magsaysay Barangay Hall',
      'location': LatLng(14.337540348842719, 121.03327230976181),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Magsaysay Barangay Hall providing local government services'
    },
    {
      'name': 'Maharlika Barangay Hall',
      'location': LatLng(14.346692982653394, 121.04574662510362),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Maharlika Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Hall Narra',
      'location': LatLng(14.331134439810109, 121.0251590046282),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Narra Barangay Hall providing local government services'
    },
    {
      'name': 'Brgy. Nueva (Brgy. Hall)',
      'location': LatLng(14.35838097208905, 121.05768857143597),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Nueva Barangay Hall providing local government services'
    },
    {
      'name': 'Pamahalaang Barangay Ng Pacita 1',
      'location': LatLng(14.34535705762904, 121.05656198604945),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Pacita 1 Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Hall Pacita 2, San Pedro, Laguna',
      'location': LatLng(14.350098350303574, 121.04823528092668),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Pacita 2 Barangay Hall providing local government services'
    },
    {
      'name': 'Poblacion Barangay Hall',
      'location': LatLng(14.363154862374707, 121.05897655393932),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Poblacion Barangay Hall providing local government services'
    },
    {
      'name': 'Riverside Barangay Hall',
      'location': LatLng(14.332494953029865, 121.02806314289465),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Riverside Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Hall Rosario',
      'location': LatLng(14.336619318138863, 121.04768528621652),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Rosario Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Sampaguita San Pedro Laguna',
      'location': LatLng(14.344764489920069, 121.03549044044527),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Sampaguita Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay San Antonio Hall',
      'location': LatLng(14.367129081801519, 121.05625740920348),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'San Antonio Barangay Hall providing local government services'
    },
    {
      'name': 'San Lorenzo Ruiz Barangay Hall',
      'location': LatLng(14.350847285116295, 121.05128915209119),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'San Lorenzo Ruiz Barangay Hall providing local government services'
    },
    {
      'name': 'San Roque Barangay Hall',
      'location': LatLng(14.365739279975925, 121.06171785578724),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'San Roque Barangay Hall providing local government services'
    },
    {
      'name': 'San Vicente Barangay Hall',
      'location': LatLng(14.358409120936944, 121.04846934679776),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'San Vicente Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Bayan-Bayanan Barangay Hall',
      'location': LatLng(14.34280730530945, 121.0235005120474),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Bayan-Bayanan Barangay Hall providing local government services'
    },
    {
      'name': 'Barangay Hall Santo Niño',
      'location': LatLng(14.366036744929923, 121.05595501242121),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'Santo Niño Barangay Hall providing local government services'
    },
    {
      'name': 'United Bayanihan Barangay Hall',
      'location': LatLng(14.334256267218713, 121.03001478462217),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'United Bayanihan Barangay Hall providing local government services'
    },
    {
      'name': 'United Better Living Barangay Hall',
      'location': LatLng(14.337640732824969, 121.02400626928059),
      'type': 'barangay_hall',
      'contact': 'Barangay Services',
      'facilities': ['Barangay Government', 'Community Services', 'Local Records', 'Permits'],
      'description': 'United Better Living Barangay Hall providing local government services'
    },
  ];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final AuthManager _authManager = AuthManager();

  @override
  void initState() {
    super.initState();
    loadWeather();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize rain animation controller
    _rainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _rainAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rainAnimationController,
        curve: Curves.linear,
      ),
    );

    _checkLoginStatus();
    _initializeWeatherEffects();
  }

  // Initialize weather effects based on current conditions
  void _initializeWeatherEffects() {
    if (weatherData != null) {
      final weatherCondition = weatherData!['weather'][0]['main'].toLowerCase();
      final temperature = weatherData!['main']['temp'] ?? 0.0;

      // Enable rain animation for rainy conditions
      if (weatherCondition.contains('rain') ||
          weatherCondition.contains('thunderstorm')) {
        _showRainAnimation = true;
        _generateRainParticles();
      }

      // Enable temperature heatmap for extreme temperatures
      if (temperature > 30 || temperature < 10) {
        _showTemperatureHeatmap = true;
        _generateTemperaturePoints();
      }

      // Enable wind arrows if wind data available
      if (weatherData!['wind'] != null) {
        _showWindArrows = true;
        _generateWindData();
      }
    }
  }

  // Generate rain particle locations around the selected area
  void _generateRainParticles() {
    if (selectedLocation == null) return;
    _rainParticleLocations.clear();
    final random = Random();
    // Generate 50 rain particles in a 5km radius
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.05; // ~5km radius in degrees
      final lat = selectedLocation!.latitude + (distance * cos(angle));
      final lng = selectedLocation!.longitude + (distance * sin(angle));
      _rainParticleLocations.add(LatLng(lat, lng));
    }
  }

  bool _calculateSafetyStatus() {
    if (weatherData == null) return true;
    final condition = weatherData!['weather'][0]['main'].toLowerCase();
    final temp = weatherData!['main']['temp'];
    final windSpeed = weatherData!['wind']['speed'] ?? 0.0;

    // Check air quality if available
    bool airQualitySafe = true;
    if (airData != null) {
      final aqi = airData!['list'][0]['main']['aqi'];
      airQualitySafe = aqi <= 2; // Safe if AQI is Good or Fair
    }

    // Not safe if: rain/storm, extreme temp, strong wind, or poor air quality
    return !(condition.contains('rain') ||
        condition.contains('thunderstorm') ||
        temp > 38 ||
        temp < 5 ||
        windSpeed > 20 ||
        !airQualitySafe);
  }

  // Air Quality Index (AQI) indicator - positioned closer to safety indicator and hazard button
  Widget _buildAirQualityIndicator() {
    if (airData == null || !_showAirQualityIndicator) {
      return const SizedBox.shrink();
    }

    final aqi = airData!['list'][0]['main']['aqi'];
    final aqiInfo = _getAQIInfo(aqi);

    return Positioned(
      bottom:
          80, // Moved closer to hazard toggle (40px gap from hazard toggle at bottom: 120)
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: aqiInfo['color'],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.air, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              aqiInfo['label'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simplified weather emoji overlay - positioned at top-left
  Widget _buildWeatherEmojiOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          _getWeatherEmoji(),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  String _getWeatherEmoji() {
    if (weatherData == null) return '🌤️';
    final condition = weatherData!['weather'][0]['main'].toLowerCase();

    switch (condition) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'drizzle':
        return '🌦️';
      default:
        return '🌤️';
    }
  }

  // Helper method to get weather color
  Color _getWeatherColor() {
    if (weatherData == null) return Colors.blue;
    final condition = weatherData!['weather'][0]['main'].toLowerCase();

    switch (condition) {
      case 'clear':
        return Colors.orange;
      case 'clouds':
        return Colors.grey;
      case 'rain':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.purple;
      case 'drizzle':
        return Colors.lightBlue;
      default:
        return Colors.blue;
    }
  }

  // Helper method to get weather icon data
  IconData _getWeatherIconData() {
    if (weatherData == null) return Icons.wb_cloudy;
    final condition = weatherData!['weather'][0]['main'].toLowerCase();

    switch (condition) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'drizzle':
        return Icons.grain;
      default:
        return Icons.wb_cloudy;
    }
  }

  @override
  void dispose() {
    _forecastScrollController.dispose();
    _cityController.dispose();
    _animationController.dispose();
    _rainAnimationController.dispose();
    super.dispose();
  }

  Future<void> loadWeather() async {
    try {
      setState(() => isLoading = true);

      // Use specific coordinates for San Pedro City Hall, Laguna, Philippines for accurate location
      const sanPedroLat = 14.3358; // San Pedro City Hall coordinates
      const sanPedroLon = 121.0417;

      // Fetch weather data with timeout
      final weather = await _weatherService
          .fetchCurrentWeatherByCoords(sanPedroLat, sanPedroLon)
          .timeout(const Duration(seconds: 10));

      // Fetch air pollution data (optional, continue if fails)
      Map<String, dynamic>? air;
      try {
        air = await _weatherService
            .fetchAirPollution(sanPedroLat, sanPedroLon)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Air pollution data fetch failed: $e');
        // Continue without air data
      }

      // Fetch hourly forecast (optional, continue if fails)
      List<Map<String, dynamic>> forecast = [];
      try {
        forecast = await _weatherService
            .fetchHourlyForecast(sanPedroLat, sanPedroLon)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Hourly forecast fetch failed: $e');
        // Continue with empty forecast
      }

      if (mounted) {
        setState(() {
          weatherData = weather;
          airData = air;
          hourlyForecast = forecast;
          selectedLocation = LatLng(sanPedroLat, sanPedroLon);
          isLoading = false;
        });

        // Update weather effects based on new data
        _initializeWeatherEffects();
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

  Future<void> searchLocations(String query) async {
    if (query.trim().isEmpty) {
      setState(() => locationSuggestions = []);
      return;
    }
    final suggestions = await _weatherService.fetchLocationSuggestions(query);
    setState(() => locationSuggestions = suggestions);
  }

  void handleSelectLocation(Map<String, dynamic> location) {
    final newCity = [
      location['name'] ?? '',
      location['state'] ?? '',
      location['country'] ?? '',
    ].where((e) => e.isNotEmpty).join(', ');

    setState(() {
      city = newCity;
      _cityController.text = newCity;
      locationSuggestions = [];
    });

    // Use the coordinates from the selected location
    if (location['lat'] != null && location['lon'] != null) {
      _fetchWeatherForLocation(LatLng(location['lat'], location['lon']));
    } else {
      loadWeather();
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

  Widget buildWeatherTile(String title, String value, IconData icon,
      {bool isFullWidth = false, Color? backgroundColor}) {
    return Container(
      width: isFullWidth
          ? double.infinity
          : MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200
            .withOpacity(0.85), // Lighter grey for better contrast
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: Colors.black87,
              size: 24), // Use dark icon for light background
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ...existing code...

  String _getLastUpdateTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Notification button
        IconButton(
          key: _notificationButtonKey,
          onPressed: _showNotifications,
          icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
        ),

        // Fixed location display bar (expanded to fill middle space)
        Expanded(
          child: Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Icon(
                    Icons.location_pin, // Pinpoint icon
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'San Pedro, Laguna, Philippines', // Fixed location text
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis, // Handle long text
                  ),
                ),
              ],
            ),
          ),
        ),

        // Profile button
        IconButton(
          key: _profileButtonKey,
          onPressed: _showProfileMenu,
          icon: Icon(
            _authManager.isLoggedIn
                ? Icons.account_circle
                : Icons.account_circle_outlined,
            color: _authManager.isLoggedIn ? Colors.white : Colors.white70,
            size: 28,
          ),
        ),
      ],
    );
  }

  void _showMenuOptions() {
    final RenderBox? button =
        _notificationButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        // Hamburger menu is now empty (no items)
      ],
    );
  }

  void _showProfileMenu() {
    final RenderBox? button =
        _profileButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        // Always available items
        const PopupMenuItem(
            value: 'tips',
            child: Row(
              children: [
                Icon(Icons.lightbulb, size: 20),
                SizedBox(width: 8),
                Text('Tips'),
              ],
            )),
        // "About"
        const PopupMenuItem(
            value: 'about',
            child: Row(
              children: [
                Icon(Icons.info, size: 20),
                SizedBox(width: 8),
                Text('About'),
              ],
            )),
        const PopupMenuItem(
            value: 'hotlines',
            child: Row(
              children: [
                Icon(Icons.phone, size: 20),
                SizedBox(width: 8),
                Text('Emergency Hotlines'),
              ],
            )),
        // Login-required items
        if (_authManager.isLoggedIn) ...[
          const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 8),
                  Text('Profile'),
                ],
              )),
          const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              )),
          const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              )),
        ] else ...[
          const PopupMenuItem(
              value: 'login',
              child: Row(
                children: [
                  Icon(Icons.login, size: 20, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Login', style: TextStyle(color: Colors.black)),
                ],
              )),
        ],
      ],
    ).then((String? result) {
      if (result == 'profile' && mounted) {
        if (_authManager.isLoggedIn) {
          Navigator.pushNamed(context, '/profile');
        } else {
          _showSnackBar('Please log in to access profile');
          Navigator.pushNamed(context, '/login');
        }
      } else if (result == 'settings' && mounted) {
        _navigateToSettings();
      } else if (result == 'tips' && mounted) {
        Navigator.pushNamed(context, '/tips');
      } else if (result == 'hotlines' && mounted) {
        Navigator.pushNamed(context, '/hotlines');
      } else if (result == 'logout' && mounted) {
        _handleLogout();
      } else if (result == 'login' && mounted) {
        Navigator.pushNamed(context, '/login');
      } else if (result == 'about' && mounted) {
        _showAboutDialog();
      }
    });
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

  // Check if user is logged in
  void _checkLoginStatus() {
    // Just trigger a state rebuild to check auth status
    setState(() {
      // The state will be rebuilt when auth state changes
    });
  }

  void _navigateToSettings() {
    if (_authManager.isLoggedIn) {
      Navigator.pushNamed(context, '/settings');
    } else {
      _showSnackBar('Please log in to access settings');
      Navigator.pushNamed(context, '/login');
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to use the app:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• View current weather conditions on the main screen'),
              Text(
                  '• Use the profile menu to access Settings, Tips, and Hotlines'),
              Text('• Login to access personalized settings'),
              Text(
                  '• Emergency hotlines are available for immediate assistance'),
              SizedBox(height: 16),
              Text('Need more help? Contact your local authorities.'),
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

            // Main scrollable content with fixed header
            Column(
              children: [
                // Fixed header (non-scrollable)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildHeader(),
                ),

                // Scrollable content area
                Expanded(
                  child: locationSuggestions.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: locationSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = locationSuggestions[index];
                            final displayText = [
                              suggestion['name'] ?? '',
                              suggestion['state'] ?? '',
                              suggestion['country'] ?? '',
                            ].where((e) => e.isNotEmpty).join(', ');
                            return ListTile(
                              title: Text(displayText,
                                  style: const TextStyle(color: Colors.white)),
                              onTap: () => handleSelectLocation(suggestion),
                            );
                          },
                        )
                      : isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              // Enhanced scroll physics for better scrolling experience
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (weatherData != null) ...[
                                    // Main weather info - Highlighted
                                    Text(
                                      weatherData!['name'],
                                      style: const TextStyle(
                                        fontSize: 44, // Much bigger
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'Montserrat',
                                        letterSpacing: 1.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Image.network(
                                      "https://openweathermap.org/img/wn/${weatherData!['weather'][0]['icon']}@2x.png",
                                      width: 100,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${weatherData!['main']['temp'].round()}°C",
                                      style: const TextStyle(
                                        fontSize: 64, // Much bigger
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Montserrat',
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 10,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      weatherData!['weather'][0]['description']
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white70,
                                        fontFamily: 'Montserrat',
                                        letterSpacing: 1.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),

                                    // 24-Hour Forecast - Now properly sized for scrolling
                                    if (hourlyForecast.isNotEmpty)
                                      buildHourlyForecast(),

                                    const SizedBox(height: 20),

                                    // Weather details grid (aligned)
                                    buildWeatherTilesGrid(),

                                    const SizedBox(height: 20),

                                    // Enhanced Interactive Geospatial Map
                                    if (selectedLocation != null)
                                      Container(
                                        height: 400,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Stack(
                                            children: [
                                              // Main Map
                                              FlutterMap(
                                                mapController: _mapController,
                                                options: MapOptions(
                                                  center: selectedLocation,
                                                  zoom: _currentZoom,
                                                  minZoom: 3.0,
                                                  maxZoom: 18.0,
                                                  interactiveFlags:
                                                      InteractiveFlag.all,
                                                  onTap: (tapPosition, point) {
                                                    _onMapTap(point);
                                                  },
                                                  onPositionChanged:
                                                      (position, hasGesture) {
                                                    if (hasGesture) {
                                                      setState(() {
                                                        _currentZoom =
                                                            position.zoom!;
                                                      });
                                                    }
                                                  },
                                                ),
                                                children: [
                                                  // Base map layer
                                                  TileLayer(
                                                    urlTemplate:
                                                        _getMapStyleUrl(),
                                                    subdomains: const [
                                                      'a',
                                                      'b',
                                                      'c'
                                                    ],
                                                    userAgentPackageName:
                                                        'com.example.weather_app',
                                                  ),

                                                  // Forecast overlay layer
                                                  if (_forecastLayer !=
                                                      ForecastLayer.none)
                                                    TileLayer(
                                                      urlTemplate:
                                                          _getForecastTileUrl(
                                                              _forecastLayer),
                                                      backgroundColor:
                                                          Colors.transparent,
                                                    ),

                                                  // Satellite overlay
                                                  if (_showSatelliteLayer)
                                                    TileLayer(
                                                      urlTemplate:
                                                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                                    ),

                                                  // Temperature heatmap circles
                                                  if (_showTemperatureHeatmap)
                                                    CircleLayer(
                                                      circles:
                                                          _temperaturePoints
                                                              .map((point) {
                                                        return CircleMarker(
                                                          point:
                                                              point['location'],
                                                          radius: (800 +
                                                                  (point['intensity'] *
                                                                      400))
                                                              .toDouble(), // 800-1200m radius
                                                          color: _getTemperatureColor(
                                                                  point[
                                                                      'temperature'])
                                                              .withOpacity(
                                                                  0.15),
                                                          borderColor:
                                                              _getTemperatureColor(
                                                                      point[
                                                                          'temperature'])
                                                                  .withOpacity(
                                                                      0.5),
                                                          borderStrokeWidth: 1,
                                                        );
                                                      }).toList(),
                                                    ),

                                                  // Rain particle effects
                                                  if (_showRainAnimation)
                                                    MarkerLayer(
                                                      markers:
                                                          _buildRainParticles(),
                                                    ),

                                                  // Wind direction arrows
                                                  if (_showWindArrows)
                                                    MarkerLayer(
                                                      markers:
                                                          _buildWindArrows(),
                                                    ),

                                                  // Markers layer
                                                  MarkerLayer(
                                                    markers: [
                                                      // Current location marker
                                                      Marker(
                                                        width: 50.0,
                                                        height: 50.0,
                                                        point:
                                                            selectedLocation!,
                                                        builder: (ctx) =>
                                                            _buildWeatherMarker(),
                                                      ),

                                                      // Hazard location markers
                                                      if (_showHazardLocations)
                                                        ..._buildHazardMarkers(),

                                                      // Evacuation center markers
                                                      if (_showEvacuationCenters)
                                                        ..._buildEvacuationCenterMarkers(),

                                                      // Government agency markers (Fire & Police)
                                                      if (_showGovernmentAgencies)
                                                        ..._buildGovernmentAgencyMarkers(),
                                                    ],
                                                  ),

                                                  // Enhanced weather coverage circle with pulsing effect
                                                  CircleLayer(
                                                    circles: [
                                                      CircleMarker(
                                                        point:
                                                            selectedLocation!,
                                                        radius:
                                                            5000, // 5km radius
                                                        color:
                                                            _getWeatherCircleColor()
                                                                .withOpacity(
                                                                    0.08),
                                                        borderColor:
                                                            _getWeatherCircleColor()
                                                                .withOpacity(
                                                                    0.3),
                                                        borderStrokeWidth: 1,
                                                      ),
                                                    ],
                                                  ),

                                                  // Pulsing weather effect overlay
                                                  CircleLayer(
                                                    circles: [
                                                      CircleMarker(
                                                        point:
                                                            selectedLocation!,
                                                        radius: 3000,
                                                        color:
                                                            _getWeatherCircleColor()
                                                                .withOpacity(
                                                                    0.05),
                                                        borderColor:
                                                            Colors.transparent,
                                                        borderStrokeWidth: 0,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),

                                              // Map controls overlay
                                              _buildMapControls(),

                                              // Safety and weather emoji indicators
                                              if (_showSafetyIndicator)
                                                _buildSafetyIndicator(),
                                              _buildWeatherEmojiOverlay(),
                                              _buildAirQualityIndicator(),

                                              // Weather info overlay
                                              _buildWeatherInfoOverlay(),

                                              // Zoom controls

                                              // Floating hazard toggle button
                                              Positioned(
                                                bottom: 120,
                                                left: 16,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: _showHazardLocations
                                                        ? Colors.red.shade700
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.2),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 4),
                                                      ),
                                                    ],
                                                    border: Border.all(
                                                      color:
                                                          _showHazardLocations
                                                              ? Colors
                                                                  .red.shade900
                                                              : Colors.grey
                                                                  .shade300,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      onTap: () {
                                                        setState(() {
                                                          _showHazardLocations =
                                                              !_showHazardLocations;
                                                        });
                                                        _showSnackBar(
                                                            _showHazardLocations
                                                                ? 'Hazard locations are now visible'
                                                                : 'Hazard locations are now hidden');
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 8),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .warning_rounded,
                                                              color: _showHazardLocations
                                                                  ? Colors.white
                                                                  : Colors.red
                                                                      .shade700,
                                                              size: 18,
                                                            ),
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                              _showHazardLocations
                                                                  ? 'HAZARDS ON'
                                                                  : 'HAZARDS OFF',
                                                              style: TextStyle(
                                                                color: _showHazardLocations
                                                                    ? Colors
                                                                        .white
                                                                    : Colors.red
                                                                        .shade700,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Bottom padding for better scroll experience
                                    const SizedBox(height: 40),
                                  ]
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

  // Geospatial Map Helper Methods
  String _getMapStyleUrl() {
    switch (_currentMapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'terrain':
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'dark':
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case 'street':
      default:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }
  }

  void _onMapTap(LatLng point) {
    // Handle map tap - could fetch weather for tapped location
    setState(() {
      selectedLocation = point;
    });

    // Optional: Fetch weather for the tapped location
    _fetchWeatherForLocation(point);
  }

  Future<void> _fetchWeatherForLocation(LatLng point) async {
    try {
      final weather = await _weatherService.fetchCurrentWeatherByCoords(
          point.latitude, point.longitude);
      final air = await _weatherService.fetchAirPollution(
          point.latitude, point.longitude);
      final forecast = await _weatherService.fetchHourlyForecast(
          point.latitude, point.longitude);

      if (mounted) {
        setState(() {
          weatherData = weather;
          airData = air;
          hourlyForecast = forecast;
          selectedLocation = point;
        });

        // Update weather effects for new location
        _initializeWeatherEffects();
      }
    } catch (e) {
      // Handle error - could show a snackbar or toast
      if (mounted) {
        _showSnackBar('Failed to fetch weather data for selected location');
      }
    }
  }

  Widget _buildWeatherMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing animation
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
            );
          },
        ),
        // Weather icon
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getWeatherIcon(),
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon() {
    if (weatherData == null) return Icons.location_on;

    final main = weatherData!['weather'][0]['main'].toLowerCase();
    switch (main) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.location_on;
    }
  }

  List<Marker> _buildHazardMarkers() {
    if (!_showHazardLocations) return [];

    return _hazardLocations.map((hazard) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: hazard['location'] as LatLng,
        builder: (ctx) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              _onHazardLocationTap(hazard);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getHazardColor(hazard['type'], hazard['severity']),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getHazardIcon(hazard['type']),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getHazardTypeLabel(hazard['type']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  String _getHazardTypeLabel(String type) {
    switch (type) {
      case 'flood':
        return 'FLOOD';
      case 'landslide':
        return 'LANDSLIDE';
      case 'heat':
        return 'HEAT';
      case 'air_pollution':
        return 'AIR QUALITY';
      case 'storm_surge':
        return 'STORM SURGE';
      case 'earthquake':
        return 'EARTHQUAKE';
      default:
        return 'HAZARD';
    }
  }

  Color _getHazardColor(String type, String severity) {
    Color baseColor;
    switch (type) {
      case 'flood':
        baseColor = Colors.blue;
        break;
      case 'landslide':
        baseColor = Colors.brown;
        break;
      case 'heat':
        baseColor = Colors.orange;
        break;
      case 'air_pollution':
        baseColor = Colors.grey;
        break;
      case 'storm_surge':
        baseColor = Colors.indigo;
        break;
      case 'earthquake':
        baseColor = Colors.red;
        break;
      default:
        baseColor = Colors.purple;
    }

    // Adjust color intensity based on severity
    switch (severity) {
      case 'high':
        return Color.fromRGBO(
          ((baseColor.r * 255.0).round() * 0.8).round(),
          ((baseColor.g * 255.0).round() * 0.8).round(),
          ((baseColor.b * 255.0).round() * 0.8).round(),
          1.0,
        );
      case 'medium':
        return baseColor;
      case 'low':
        return Color.fromRGBO(
          255 - ((255 - (baseColor.r * 255.0).round()) * 0.6).round(),
          255 - ((255 - (baseColor.g * 255.0).round()) * 0.6).round(),
          255 - ((255 - (baseColor.b * 255.0).round()) * 0.6).round(),
          1.0,
        );
      default:
        return baseColor;
    }
  }

  IconData _getHazardIcon(String type) {
    switch (type) {
      case 'flood':
        return Icons.water;
      case 'landslide':
        return Icons.landscape;
      case 'heat':
        return Icons.thermostat;
      case 'air_pollution':
        return Icons.air;
      case 'storm_surge':
        return Icons.tsunami;
      case 'earthquake':
        return Icons.vibration;
      default:
        return Icons.warning;
    }
  }

  void _onHazardLocationTap(Map<String, dynamic> hazard) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getHazardColor(hazard['type'], hazard['severity']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getHazardIcon(hazard['type']),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hazard Alert',
                  style: TextStyle(
                    color: _getHazardColor(hazard['type'], hazard['severity']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hazard['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getHazardColor(hazard['type'], hazard['severity']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${hazard['severity'].toUpperCase()} RISK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hazard['description'],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Safety Recommendations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getHazardRecommendations(hazard['type']),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/tips');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _getHazardColor(hazard['type'], hazard['severity']),
              ),
              child: const Text(
                'View Safety Tips',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getHazardRecommendations(String type) {
    switch (type) {
      case 'flood':
        return '• Avoid the area during heavy rainfall\n• Keep emergency supplies ready\n• Monitor flood warnings\n• Know evacuation routes';
      case 'landslide':
        return '• Watch for signs of ground movement\n• Avoid construction on steep slopes\n• Plant vegetation to stabilize soil\n• Report cracks or unusual sounds';
      case 'heat':
        return '• Stay hydrated and seek shade\n• Limit outdoor activities during peak hours\n• Wear light-colored clothing\n• Check on elderly neighbors';
      case 'air_pollution':
        return '• Limit outdoor activities on high pollution days\n• Use air purifiers indoors\n• Wear N95 masks when outside\n• Plant trees and reduce emissions';
      case 'storm_surge':
        return '• Evacuate if storm surge warning issued\n• Move to higher ground\n• Secure loose outdoor items\n• Monitor weather updates continuously';
      case 'earthquake':
        return '• Secure heavy furniture and appliances\n• Know Drop, Cover, Hold procedures\n• Keep emergency supplies ready\n• Plan evacuation routes';
      default:
        return '• Stay informed about weather conditions\n• Follow official safety guidelines\n• Keep emergency supplies ready\n• Have evacuation plans prepared';
    }
  }

  List<Marker> _buildEvacuationCenterMarkers() {
    if (!_showEvacuationCenters) return [];

    return _evacuationCenters.map((center) {
      return Marker(
        width: 32.0,
        height: 32.0,
        point: center['location'] as LatLng,
        builder: (ctx) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _onEvacuationCenterTap(center);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade600,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_work,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildGovernmentAgencyMarkers() {
    if (!_showGovernmentAgencies) return [];

    return _governmentAgencies.map((agency) {
      return Marker(
        width: 32.0,
        height: 32.0,
        point: agency['location'] as LatLng,
        builder: (ctx) => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _onGovernmentAgencyTap(agency);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: agency['type'] == 'fire_station' 
                    ? Colors.red.shade600 
                    : agency['type'] == 'police_station'
                    ? Colors.blue.shade600
                    : agency['type'] == 'city_hall'
                    ? Colors.purple.shade600
                    : Colors.orange.shade600, // barangay_hall
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                agency['type'] == 'fire_station' 
                    ? Icons.local_fire_department 
                    : agency['type'] == 'police_station'
                    ? Icons.local_police
                    : agency['type'] == 'city_hall'
                    ? Icons.account_balance
                    : Icons.location_city, // barangay_hall
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getEvacuationCenterColor(String type) {
    // Use consistent green color for all evacuation centers
    return Colors.green.shade600;
  }

  IconData _getEvacuationCenterIcon(String type) {
    // Use consistent evacuation center icon for all types
    return Icons.home_work;
  }

  void _onEvacuationCenterTap(Map<String, dynamic> center) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                _getEvacuationCenterIcon(center['type']),
                color: _getEvacuationCenterColor(center['type']),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  center['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Type', center['type'].toString().toUpperCase()),
                const SizedBox(height: 8),
                _buildInfoRow('Capacity', '${center['capacity']} individuals'),
                const SizedBox(height: 8),
                _buildInfoRow('Families', '${center['families']} families'),
                const SizedBox(height: 8),
                _buildInfoRow('Description', center['description']),
                const SizedBox(height: 12),
                const Text(
                  'Available Facilities:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...center['facilities'].map<Widget>((facility) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(facility),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Add navigation functionality here if needed
                _showSnackBar('Directions to ${center['name']} would open here');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getEvacuationCenterColor(center['type']),
                foregroundColor: Colors.white,
              ),
              child: const Text('Get Directions'),
            ),
          ],
        );
      },
    );
  }

  void _onGovernmentAgencyTap(Map<String, dynamic> agency) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                agency['type'] == 'fire_station' 
                    ? Icons.local_fire_department 
                    : Icons.local_police,
                color: agency['type'] == 'fire_station' 
                    ? Colors.red.shade600 
                    : Colors.blue.shade600,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  agency['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Type', agency['type'] == 'fire_station' ? 'Fire Station' : 'Police Station'),
                const SizedBox(height: 8),
                _buildInfoRow('Emergency Contact', agency['contact']),
                const SizedBox(height: 8),
                _buildInfoRow('Description', agency['description']),
                const SizedBox(height: 12),
                const Text(
                  'Available Services:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...agency['facilities'].map<Widget>((facility) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: agency['type'] == 'fire_station' ? Colors.red : Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(facility),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSnackBar('Emergency Call: 911');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: agency['type'] == 'fire_station' 
                    ? Colors.red.shade600 
                    : Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Emergency Call'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.layers,
              color: Colors.black87,
              size: 20,
            ),
          ),
          tooltip: 'Map Options',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          offset: const Offset(-120, 40),
          itemBuilder: (context) => [
            // Map Type
            PopupMenuItem<String>(
              value: 'style_street',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: _currentMapStyle == 'street'
                        ? Colors.blue
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Street Map'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'style_satellite',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: _currentMapStyle == 'satellite'
                        ? Colors.blue
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Satellite'),
                ],
              ),
            ),

            const PopupMenuDivider(),

            // Weather Overlay
            PopupMenuItem<String>(
              value: 'weather_off',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: _forecastLayer == ForecastLayer.none
                        ? Colors.green
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Weather Off'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'weather_rain',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: _forecastLayer == ForecastLayer.precipitation
                        ? Colors.green
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.grain, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('Rain/Storm'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'weather_temp',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: _forecastLayer == ForecastLayer.temp
                        ? Colors.green
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.thermostat, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Temperature'),
                    ],
                  ),
                ],
              ),
            ),

            const PopupMenuDivider(),

            // Essential Features
            PopupMenuItem<String>(
              value: 'toggle_hazards',
              child: Row(
                children: [
                  Icon(
                    _showHazardLocations
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: _showHazardLocations ? Colors.red : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Show Hazards'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'toggle_evacuation',
              child: Row(
                children: [
                  Icon(
                    _showEvacuationCenters
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: _showEvacuationCenters ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.home, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Evacuation Centers'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'toggle_government_agencies',
              child: Row(
                children: [
                  Icon(
                    _showGovernmentAgencies
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: _showGovernmentAgencies ? Colors.blue : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.account_balance, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('Government Agencies'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'toggle_air_quality',
              child: Row(
                children: [
                  Icon(
                    _showAirQualityIndicator
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color:
                        _showAirQualityIndicator ? Colors.purple : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    children: [
                      Icon(Icons.air, size: 14, color: Colors.purple),
                      SizedBox(width: 4),
                      Text('Air Quality'),
                    ],
                  ),
                ],
              ),
            ),

            const PopupMenuDivider(),

            // Quick Actions
            PopupMenuItem<String>(
              value: 'center_location',
              child: Row(
                children: [
                  Icon(Icons.my_location,
                      color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Center Map',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (String value) {
            setState(() {
              // Handle map style
              if (value == 'style_street') {
                _currentMapStyle = 'street';
              } else if (value == 'style_satellite') {
                _currentMapStyle = 'satellite';
              }
              // Handle weather overlay
              else if (value == 'weather_off') {
                _forecastLayer = ForecastLayer.none;
              } else if (value == 'weather_rain') {
                _forecastLayer = ForecastLayer.precipitation;
              } else if (value == 'weather_temp') {
                _forecastLayer = ForecastLayer.temp;
              }
              // Handle hazards
              else if (value == 'toggle_hazards') {
                _showHazardLocations = !_showHazardLocations;
                _showSnackBar(_showHazardLocations
                    ? 'Hazard locations shown'
                    : 'Hazard locations hidden');
              }
              // Handle evacuation centers
              else if (value == 'toggle_evacuation') {
                _showEvacuationCenters = !_showEvacuationCenters;
                _showSnackBar(_showEvacuationCenters
                    ? 'Evacuation centers shown'
                    : 'Evacuation centers hidden');
              }
              // Handle government agencies (Fire & Police stations)
              else if (value == 'toggle_government_agencies') {
                _showGovernmentAgencies = !_showGovernmentAgencies;
                _showSnackBar(_showGovernmentAgencies
                    ? 'Government agencies shown'
                    : 'Government agencies hidden');
              }
              // Handle air quality
              else if (value == 'toggle_air_quality') {
                _showAirQualityIndicator = !_showAirQualityIndicator;
                _showSnackBar(_showAirQualityIndicator
                    ? 'Air quality indicator shown'
                    : 'Air quality indicator hidden');
              }
              // Handle center location
              else if (value == 'center_location') {
                _mapController.move(LatLng(14.3358, 121.0417), 14.0);
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildWeatherInfoOverlay() {
    if (weatherData == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _getWeatherIcon(),
              color: Colors.blue.shade700,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${weatherData!['name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${weatherData!['main']['temp'].round()}°C - ${weatherData!['weather'][0]['description']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Zoom: ${_currentZoom.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHazardLegend() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE RISK MONITOR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'San Pedro, Laguna',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current weather-based risk assessment
                  _buildCurrentRiskStatus(),

                  const SizedBox(height: 16),

                  // Real-time hazard risk levels
                  const Text(
                    'CURRENT RISK LEVELS:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dynamic risk assessment based on current conditions
                  ..._buildRealTimeRiskItems(),

                  const SizedBox(height: 16),

                  // Risk severity indicators
                  _buildRiskSeverityGuide(),

                  const SizedBox(height: 16),

                  // Live update indicator
                  _buildLiveUpdateIndicator(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/hotlines');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Emergency Hotlines',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for the real-time risk legend
  Widget _buildCurrentRiskStatus() {
    // Get current weather conditions
    final weatherCondition =
        weatherData?['weather']?[0]?['main']?.toLowerCase() ?? '';
    final temperature = weatherData?['main']?['temp'] ?? 0.0;
    final humidity = weatherData?['main']?['humidity'] ?? 0;
    final windSpeed = weatherData?['wind']?['speed'] ?? 0.0;

    // Determine overall risk level
    String riskLevel = 'LOW';
    Color riskColor = Colors.green;
    IconData riskIcon = Icons.check_circle;

    if (weatherCondition.contains('rain') ||
        weatherCondition.contains('thunderstorm')) {
      riskLevel = 'HIGH';
      riskColor = Colors.red;
      riskIcon = Icons.warning;
    } else if (temperature > 35 || humidity > 80 || windSpeed > 20) {
      riskLevel = 'MEDIUM';
      riskColor = Colors.orange;
      riskIcon = Icons.warning_amber;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(riskIcon, color: riskColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'CURRENT RISK: $riskLevel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Weather: ${weatherCondition.isNotEmpty ? weatherCondition.toUpperCase() : 'Unknown'}',
            style: TextStyle(
              fontSize: 12,
              color: riskColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            'Temperature: ${temperature.toStringAsFixed(1)}°C • Humidity: $humidity%',
            style: TextStyle(
              fontSize: 12,
              color: riskColor.withValues(alpha: 0.8),
            ),
          ),
          if (windSpeed > 0)
            Text(
              'Wind Speed: ${windSpeed.toStringAsFixed(1)} m/s',
              style: TextStyle(
                fontSize: 12,
                color: riskColor.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRealTimeRiskItems() {
    final weatherCondition =
        weatherData?['weather']?[0]?['main']?.toLowerCase() ?? '';
    final temperature = weatherData?['main']?['temp'] ?? 0.0;
    final humidity = weatherData?['main']?['humidity'] ?? 0;
    final windSpeed = weatherData?['wind']?['speed'] ?? 0.0;

    List<Widget> riskItems = [];

    // Flood risk based on rain/thunderstorm
    if (weatherCondition.contains('rain') ||
        weatherCondition.contains('thunderstorm')) {
      riskItems.add(_buildRiskItem(
        'Flood Risk',
        'HIGH',
        Colors.red,
        Icons.water_drop,
        'Active rain/storms increase flood risk in low-lying areas',
      ));
    } else {
      riskItems.add(_buildRiskItem(
        'Flood Risk',
        'LOW',
        Colors.green,
        Icons.water_drop,
        'No significant precipitation detected',
      ));
    }

    // Heat risk based on temperature
    if (temperature > 35) {
      riskItems.add(_buildRiskItem(
        'Heat Risk',
        'HIGH',
        Colors.red,
        Icons.thermostat,
        'Extreme heat warning - heat exhaustion risk',
      ));
    } else if (temperature > 32) {
      riskItems.add(_buildRiskItem(
        'Heat Risk',
        'MEDIUM',
        Colors.orange,
        Icons.thermostat,
        'Hot conditions - stay hydrated',
      ));
    } else {
      riskItems.add(_buildRiskItem(
        'Heat Risk',
        'LOW',
        Colors.green,
        Icons.thermostat,
        'Temperature within safe range',
      ));
    }

    // Air quality risk based on humidity and weather
    if (humidity > 80 ||
        weatherCondition.contains('haze') ||
        weatherCondition.contains('smoke')) {
      riskItems.add(_buildRiskItem(
        'Air Quality Risk',
        'MEDIUM',
        Colors.orange,
        Icons.air,
        'High humidity or poor air quality conditions',
      ));
    } else {
      riskItems.add(_buildRiskItem(
        'Air Quality Risk',
        'LOW',
        Colors.green,
        Icons.air,
        'Air quality conditions acceptable',
      ));
    }

    // Storm surge/wind risk
    if (windSpeed > 25) {
      riskItems.add(_buildRiskItem(
        'Storm Surge Risk',
        'HIGH',
        Colors.red,
        Icons.waves,
        'Strong winds may cause storm surge',
      ));
    } else if (windSpeed > 15) {
      riskItems.add(_buildRiskItem(
        'Storm Surge Risk',
        'MEDIUM',
        Colors.orange,
        Icons.waves,
        'Moderate winds detected',
      ));
    } else {
      riskItems.add(_buildRiskItem(
        'Storm Surge Risk',
        'LOW',
        Colors.green,
        Icons.waves,
        'Wind conditions normal',
      ));
    }

    return riskItems;
  }

  Widget _buildRiskItem(String title, String level, Color color, IconData icon,
      String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSeverityGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RISK SEVERITY GUIDE:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildSeverityItem('HIGH', Colors.red, 'Immediate action required'),
          _buildSeverityItem('MEDIUM', Colors.orange, 'Caution advised'),
          _buildSeverityItem('LOW', Colors.green, 'Normal conditions'),
        ],
      ),
    );
  }

  Widget _buildSeverityItem(String level, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            level,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- $description',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUpdateIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE UPDATES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  'Risk levels update automatically based on current weather conditions',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Animated legend widget for forecast overlays
class _ForecastOverlayLegend extends StatefulWidget {
  final ForecastLayer layer;
  const _ForecastOverlayLegend({Key? key, required this.layer})
      : super(key: key);

  @override
  State<_ForecastOverlayLegend> createState() => _ForecastOverlayLegendState();
}

class _ForecastOverlayLegendState extends State<_ForecastOverlayLegend>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final legendData = _getLegendData(widget.layer);
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: legendData['color'], width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(legendData['icon'], color: legendData['color'], size: 28),
            const SizedBox(width: 10),
            Text(
              legendData['label'],
              style: TextStyle(
                color: legendData['color'],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getLegendData(ForecastLayer layer) {
    switch (layer) {
      case ForecastLayer.precipitation:
        return {
          'icon': Icons.grain,
          'label': 'Precipitation',
          'color': Colors.blueAccent,
        };
      case ForecastLayer.clouds:
        return {
          'icon': Icons.cloud,
          'label': 'Clouds',
          'color': Colors.grey,
        };
      case ForecastLayer.temp:
        return {
          'icon': Icons.thermostat,
          'label': 'Temperature',
          'color': Colors.redAccent,
        };
      case ForecastLayer.wind:
        return {
          'icon': Icons.air,
          'label': 'Wind',
          'color': Colors.greenAccent,
        };
      default:
        return {
          'icon': Icons.layers,
          'label': 'Forecast',
          'color': Colors.white,
        };
    }
  }
}

class TemperatureGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minTemp;
  final double maxTemp;
  final double tempRange;

  TemperatureGraphPainter({
    required this.data,
    required this.minTemp,
    required this.maxTemp,
    required this.tempRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blueAccent // Blue accent for the line
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.45), // MAXIMUM opacity!
          Colors.white.withOpacity(0.15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = Colors.blueAccent // Blue accent for dots
      ..style = PaintingStyle.fill;

    // Temperature scaling for MASSIVE graph
    double effectiveMinTemp = minTemp;
    double effectiveTempRange = tempRange;

    if (tempRange < 10) {
      final midTemp = (minTemp + maxTemp) / 2;
      effectiveMinTemp = midTemp - 5;
      effectiveTempRange = 10;
    }

    // Calculate points with 85px width spacing - MASSIVE!
    final points = <Offset>[];
    final fillPath = ui.Path();
    final hourWidth =
        size.width / data.length; // This will be 85px per hour - MASSIVE!

    for (int i = 0; i < data.length; i++) {
      final temp = data[i]['temp']?.toDouble() ?? 0.0;
      final x = (i * hourWidth) + (hourWidth / 2);

      final normalizedTemp = effectiveTempRange == 0
          ? 0.5
          : (temp - effectiveMinTemp) / effectiveTempRange;

      // Use MASSIVE height (135px) with optimal padding for ultimate visualization
      final y = size.height * (1 - normalizedTemp) * 0.8 + size.height * 0.1;

      points.add(Offset(x, y));

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }

    // Draw gradient fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw temperature line with smooth curves
    if (points.length > 1) {
      final path = ui.Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final controlPoint1 = Offset(
          points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 3,
          points[i - 1].dy,
        );
        final controlPoint2 = Offset(
          points[i].dx - (points[i].dx - points[i - 1].dx) / 3,
          points[i].dy,
        );

        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          points[i].dx,
          points[i].dy,
        );
      }

      canvas.drawPath(path, paint);
    }

    // Draw temperature dots and labels - ULTIMATE maximum visibility
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final temp = data[i]['temp']?.round() ?? 0;
      // Draw dot
      canvas.drawCircle(point, 5.0, dotPaint);
      // Show temperature label for every hour
      textPainter.text = TextSpan(
        text: '$temp°',
        style: TextStyle(
          color: Colors.blueGrey.shade800, // Blue-grey for temp labels
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              offset: Offset(0.8, 0.8),
              blurRadius: 2.0,
              color: Colors.white,
            ),
          ],
        ),
      );
      textPainter.layout();
      final labelOffset = Offset(
        point.dx - textPainter.width / 2,
        point.dy - textPainter.height - 8,
      );
      final labelBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        labelBg,
        Paint()..color = Colors.black.withOpacity(0.18),
      );
      textPainter.paint(canvas, labelOffset);
    }

    // Draw more visible horizontal grid lines for temperature reference
    const gridLineCount = 5;
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = 1.0;
    for (int i = 0; i <= gridLineCount; i++) {
      final y = size.height * i / gridLineCount;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
