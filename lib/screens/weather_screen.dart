
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart';
import 'log_in.dart';

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

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  // Build aligned weather tiles in a 2-column grid
  Widget buildWeatherTilesGrid() {
    if (weatherData == null) return const SizedBox();
    final tiles = [
      buildWeatherTile("Feels Like", "${weatherData!['main']['feels_like'].round()}°C", Icons.thermostat),
      buildWeatherTile("Humidity", "${weatherData!['main']['humidity']}%", Icons.water_drop),
      buildWeatherTile("Wind", "${weatherData!['wind']['speed']} m/s", Icons.air),
      buildWeatherTile("Pressure", "${weatherData!['main']['pressure']} hPa", Icons.speed),
      buildWeatherTile("Visibility", "${(weatherData!['visibility'] / 1000).toStringAsFixed(1)} km", Icons.remove_red_eye),
      buildWeatherTile("Clouds", "${weatherData!['clouds']['all']}%", Icons.cloud),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          'description': 'Air quality is acceptable. Sensitive individuals should take care.',
        };
      case 3:
        return {
          'label': 'Moderate',
          'color': Colors.orange,
          'description': 'Air quality is moderate. People with respiratory issues should limit outdoor exertion.',
        };
      case 4:
        return {
          'label': 'Poor',
          'color': Colors.red,
          'description': 'Air quality is poor. Limit outdoor activities, especially for sensitive groups.',
        };
      case 5:
        return {
          'label': 'Very Poor',
          'color': Colors.purple,
          'description': 'Air quality is very poor. Avoid outdoor activities and stay indoors.',
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
              Text('A weather application specifically designed for San Pedro, Laguna, Philippines. Provides real-time weather updates, local hazard warnings, emergency hotlines, and safety tips for residents.'),
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
  List<Map<String, dynamic>> notifications = [
    {
      'title': 'Weather Alert: Heavy Rainfall',
      'body': 'A heavy rainfall warning is in effect for San Pedro, Laguna. Please stay indoors and monitor local advisories.',
      'timestamp': '2025-08-13 14:30'
    },
    // Add more alerts here or fetch from backend
  ];
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
      final directionVariation = (random.nextDouble() - 0.5) * 30; // ±15° variation
      final pointDirection = windDirection + directionVariation;
      _windData.add({
        'location': LatLng(lat, lng),
        'speed': windSpeed + (random.nextDouble() - 0.5) * 2, // ±1 m/s variation
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
    return _rainParticleLocations.map((location) {
      return Marker(
        width: 20.0,
        height: 20.0,
        point: location,
        builder: (ctx) => AnimatedBuilder(
          animation: _rainAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _rainAnimation.value * 10),
              child: Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
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
          angle: (windPoint['direction'] * pi) / 180, // Convert degrees to radians
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
  bool _showAirQualityIndicator = false;
  final bool _showSafetyIndicator = false;
  // --- END ALL REQUIRED FIELDS ---

  // --- BEGIN CLEAN FORECAST SECTION (single version) ---
  // ...existing code...
  // --- END CLEAN FORECAST SECTION ---

  Widget buildHourlyForecast() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
  color: const Color(0xFF388E3C), // Use app's main green for strong branding
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title with Updated badge
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12, top: 16, right: 16),
            child: Row(
              children: [
                const Text(
                  '24-Hour Forecast',
                  style: TextStyle(
                    color: ui.Color.fromARGB(221, 255, 255, 255),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
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
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            // No color here, inherit from parent
            child: _buildTemperatureGraph(),
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
    final temps = displayData.map((e) => (e['temp']?.toDouble() ?? 0.0)).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;

    return Column(
      children: [
        // Temperature Graph
        SizedBox(
          height: 135,
          child: SingleChildScrollView(
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
                          color: Colors.white.withOpacity(0.2),
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
                      displayTime = "${dateTime.hour.toString().padLeft(2, '0')}:00";
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
                      color: Colors.white,
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
  void _showNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: notifications.isEmpty
              ? const Text('No new notifications.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return ListTile(
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
                                  notif['timestamp'],
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
      'location': LatLng(14.3450, 121.0580), // Adjusted to better lakefront position
      'severity': 'high',
      'description':
          'High flood risk during heavy rainfall and typhoons due to proximity to Laguna de Bay',
    },
    {
      'name': 'Barangay San Vicente - Landslide Risk',
      'type': 'landslide',
      'location': LatLng(14.3300, 121.0380), // Moved to hillier area
      'severity': 'medium',
      'description':
          'Moderate landslide risk on steep slopes in hillside areas',
    },
    {
      'name': 'Pacita Complex - Heat Island',
      'type': 'heat',
      'location': LatLng(14.3189, 121.0401), // Keep original position - this is correct
      'severity': 'medium',
      'description':
          'Urban heat island effect during summer months in dense residential area',
    },
    {
      'name': 'Barangay Landayan - Air Quality',
      'type': 'air_pollution',
      'location': LatLng(14.3380, 121.0450), // Moved closer to main roads
      'severity': 'medium',
      'description':
          'Elevated air pollution levels from commercial activities and heavy traffic',
    },
    {
      'name': 'Barangay Poblacion - Storm Surge',
      'type': 'storm_surge',
      'location': LatLng(14.3364, 121.0423), // Keep original - city center
      'severity': 'high',
      'description':
          'High storm surge risk during typhoons affecting central low-lying areas',
    },
    {
      'name': 'West Valley Fault Zone - Earthquake Risk',
      'type': 'earthquake',
      'location': LatLng(14.3280, 121.0350), // Adjusted to western fault area
      'severity': 'high',
      'description':
          'Near West Valley Fault line - earthquake preparedness required for all residents',
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
      if (weatherCondition.contains('rain') || weatherCondition.contains('thunderstorm')) {
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
             temp > 38 || temp < 5 ||
             windSpeed > 20 ||
             !airQualitySafe);
  }

  // Air Quality Index (AQI) indicator - positioned closer to safety indicator and hazard button
  Widget _buildAirQualityIndicator() {
    if (airData == null || !_showAirQualityIndicator) return const SizedBox.shrink();
    
    final aqi = airData!['list'][0]['main']['aqi'];
    final aqiInfo = _getAQIInfo(aqi);
    
    return Positioned(
      bottom: 220, // Moved even closer to safety indicator (only 40px gap from safety indicator at bottom: 180)
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
      case 'clear': return '☀️';
      case 'clouds': return '☁️';
      case 'rain': return '🌧️';
      case 'thunderstorm': return '⛈️';
      case 'drizzle': return '🌦️';
      default: return '🌤️';
    }
  }

  // Helper method to get weather color
  Color _getWeatherColor() {
    if (weatherData == null) return Colors.blue;
    final condition = weatherData!['weather'][0]['main'].toLowerCase();
    
    switch (condition) {
      case 'clear': return Colors.orange;
      case 'clouds': return Colors.grey;
      case 'rain': return Colors.blue;
      case 'thunderstorm': return Colors.purple;
      case 'drizzle': return Colors.lightBlue;
      default: return Colors.blue;
    }
  }

  // Helper method to get weather icon data
  IconData _getWeatherIconData() {
    if (weatherData == null) return Icons.wb_cloudy;
    final condition = weatherData!['weather'][0]['main'].toLowerCase();
    
    switch (condition) {
      case 'clear': return Icons.wb_sunny;
      case 'clouds': return Icons.cloud;
      case 'rain': return Icons.grain;
      case 'thunderstorm': return Icons.flash_on;
      case 'drizzle': return Icons.grain;
      default: return Icons.wb_cloudy;
    }
  }

  @override
  void dispose() {
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
    final weather = await _weatherService.fetchCurrentWeatherByCoords(sanPedroLat, sanPedroLon)
      .timeout(const Duration(seconds: 10));
      
      // Fetch air pollution data (optional, continue if fails)
      Map<String, dynamic>? air;
      try {
        air = await _weatherService.fetchAirPollution(sanPedroLat, sanPedroLon)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Air pollution data fetch failed: $e');
        // Continue without air data
      }

      // Fetch hourly forecast (optional, continue if fails)
      List<Map<String, dynamic>> forecast = [];
      try {
        forecast = await _weatherService.fetchHourlyForecast(sanPedroLat, sanPedroLon)
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
        _showSnackBar('Failed to load weather data. Please check your internet connection.');
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

  Widget buildWeatherTile(String title, String value, IconData icon, {bool isFullWidth = false, Color? backgroundColor}) {
    return Container(
      width: isFullWidth
          ? double.infinity
          : MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.85), // Lighter grey for better contrast
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
          Icon(icon, color: Colors.black87, size: 24), // Use dark icon for light background
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      weatherData!['weather'][0]['description'].toString().toUpperCase(),
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
                                                color: Colors.black
                                                    .withOpacity(0.1),
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
                                                    onTap:
                                                        (tapPosition, point) {
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
                                                    if (_forecastLayer != ForecastLayer.none)
                                                      TileLayer(
                                                        urlTemplate: _getForecastTileUrl(_forecastLayer),
                                                        backgroundColor: Colors.transparent,                                          
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
                                                        circles: _temperaturePoints.map((point) {
                                                          return CircleMarker(
                                                            point: point['location'],
                                                            radius: (800 + (point['intensity'] * 400)).toDouble(), // 800-1200m radius
                                                            color: _getTemperatureColor(point['temperature']).withOpacity(0.15),
                                                            borderColor: _getTemperatureColor(point['temperature']).withOpacity(0.5),
                                                            borderStrokeWidth: 1,
                                                          );
                                                        }).toList(),
                                                      ),

                                                    // Rain particle effects
                                                    if (_showRainAnimation)
                                                      MarkerLayer(
                                                        markers: _buildRainParticles(),
                                                      ),

                                                    // Wind direction arrows
                                                    if (_showWindArrows)
                                                      MarkerLayer(
                                                        markers: _buildWindArrows(),
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

                                                        // Additional markers for nearby locations
                                                        ..._buildNearbyLocationMarkers(),

                                                        // Hazard location markers
                                                        if (_showHazardLocations)
                                                          ..._buildHazardMarkers(),
                                                      ],
                                                    ),

                                                    // Enhanced weather coverage circle with pulsing effect
                                                    CircleLayer(
                                                      circles: [
                                                        CircleMarker(
                                                          point: selectedLocation!,
                                                          radius: 5000, // 5km radius
                                                          color: _getWeatherCircleColor().withOpacity(0.08),
                                                          borderColor: _getWeatherCircleColor().withOpacity(0.3),
                                                          borderStrokeWidth: 1,
                                                        ),
                                                      ],
                                                    ),

                                                    // Pulsing weather effect overlay
                                                    CircleLayer(
                                                      circles: [
                                                        CircleMarker(
                                                          point: selectedLocation!,
                                                          radius: 3000,
                                                          color: _getWeatherCircleColor().withOpacity(0.05),
                                                          borderColor: Colors.transparent,
                                                          borderStrokeWidth: 0,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),

                                                // Map controls overlay
                                                _buildMapControls(),

                                                // Safety and weather emoji indicators
                                                if (_showSafetyIndicator) _buildSafetyIndicator(),
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
                                                      color:
                                                          _showHazardLocations
                                                              ? Colors
                                                                  .red.shade700
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
                                                          offset: const Offset(
                                                              0, 4),
                                                        ),
                                                      ],
                                                      border: Border.all(
                                                        color:
                                                            _showHazardLocations
                                                                ? Colors.red
                                                                    .shade900
                                                                : Colors.grey
                                                                    .shade300,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
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
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 8),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .warning_rounded,
                                                                color: _showHazardLocations
                                                                    ? Colors
                                                                        .white
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
                                                                style:
                                                                    TextStyle(
                                                                  color: _showHazardLocations
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .red
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

  List<Marker> _buildNearbyLocationMarkers() {
    // Updated San Pedro, Laguna specific locations with more accurate coordinates
    final sanPedroLocations = [
      {'name': 'San Pedro City Hall', 'coords': LatLng(14.3358, 121.0417)}, // Correct position
      {'name': 'St. Peter the Apostle Cathedral', 'coords': LatLng(14.3364, 121.0423)}, // Correct position
      {'name': 'Pacita Complex I', 'coords': LatLng(14.3189, 121.0401)}, // Correct position
      {'name': 'SM City San Pedro', 'coords': LatLng(14.3320, 121.0440)}, // Slightly adjusted
      {'name': 'Landayan Town Center', 'coords': LatLng(14.3390, 121.0460)}, // Better position
      {'name': 'San Pedro Plaza', 'coords': LatLng(14.3361, 121.0419)}, // Correct position
      {'name': 'Laguna de Bay Shoreline', 'coords': LatLng(14.3480, 121.0600)}, // Better lakefront position
      {'name': 'San Pedro Sports Complex', 'coords': LatLng(14.3290, 121.0370)}, // Adjusted position
    ];

    return sanPedroLocations.map((location) {
      return Marker(
        width: 30.0,
        height: 30.0,
        point: location['coords'] as LatLng,
        builder: (ctx) => GestureDetector(
          onTap: () => _onNearbyLocationTap(location),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.location_city,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _onNearbyLocationTap(Map<String, dynamic> location) {
    final coords = location['coords'] as LatLng;
    _mapController.move(coords, 12.0);
    _fetchWeatherForLocation(coords);
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
                    color: _currentMapStyle == 'street' ? Colors.blue : Colors.grey,
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
                    color: _currentMapStyle == 'satellite' ? Colors.blue : Colors.grey,
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
                    color: _forecastLayer == ForecastLayer.none ? Colors.green : Colors.grey,
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
                    color: _forecastLayer == ForecastLayer.precipitation ? Colors.green : Colors.grey,
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
                    color: _forecastLayer == ForecastLayer.temp ? Colors.green : Colors.grey,
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
                    _showHazardLocations ? Icons.check_box : Icons.check_box_outline_blank,
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
              value: 'toggle_air_quality',
              child: Row(
                children: [
                  Icon(
                    _showAirQualityIndicator ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _showAirQualityIndicator ? Colors.purple : Colors.grey,
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
                  Icon(Icons.my_location, color: Colors.green.shade600, size: 16),
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
  const _ForecastOverlayLegend({Key? key, required this.layer}) : super(key: key);

  @override
  State<_ForecastOverlayLegend> createState() => _ForecastOverlayLegendState();
}

class _ForecastOverlayLegendState extends State<_ForecastOverlayLegend> with SingleTickerProviderStateMixin {
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
      ..color = Colors.white
      ..strokeWidth = 4.0 // MASSIVE stroke from 3.5 to 4.0 - ultimate bold!
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
      ..color = Colors.white
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
    final hourWidth = size.width / data.length; // This will be 85px per hour - MASSIVE!
    
    for (int i = 0; i < data.length; i++) {
      final temp = data[i]['temp']?.toDouble() ?? 0.0;
      final x = (i * hourWidth) + (hourWidth / 2);
      
      final normalizedTemp = effectiveTempRange == 0 ? 0.5 : 
          (temp - effectiveMinTemp) / effectiveTempRange;
      
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
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          points[i].dx, points[i].dy,
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(0.8, 0.8),
              blurRadius: 2.0,
              color: Colors.black87,
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
        Paint()
          ..color = Colors.black.withOpacity(0.18),
      );
      textPainter.paint(canvas, labelOffset);
    }

    // Optionally, draw horizontal grid lines for temperature reference
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.13)
      ..strokeWidth = 1.0;
    for (int i = 0; i <= 4; i++) {
      final y = (size.height * 0.75 / 4) * i + size.height * 0.12;
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
