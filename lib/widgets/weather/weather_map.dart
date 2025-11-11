import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Forecast overlay enum for map overlays
enum ForecastLayer { none, precipitation, clouds, temp, wind }

class WeatherMap extends StatefulWidget {
  final LatLng location;
  final Map<String, dynamic> weatherData;
  final Map<String, dynamic>? airData;
  final bool isGuest;

  const WeatherMap({
    required this.location,
    required this.weatherData,
    this.airData,
    this.isGuest = false,
    super.key,
  });

  @override
  State<WeatherMap> createState() => _WeatherMapState();
}

class _WeatherMapState extends State<WeatherMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  double _currentZoom = 14.0;
  String _currentMapStyle = 'satellite';
  ForecastLayer _forecastLayer = ForecastLayer.none;
  bool _showHazardLocations = false;
  bool _showAirQualityIndicator = false;
  bool _showTemperatureHeatmap = false;
  bool _showWindArrows = false;
  bool _showRainAnimation = false;

  // Map data
  final List<LatLng> _rainParticleLocations = [];
  final List<Map<String, dynamic>> _temperaturePoints = [];
  final List<Map<String, dynamic>> _windData = [];

  // Animations
  late AnimationController _rainAnimationController;
  late Animation<double> _rainAnimation;
  late AnimationController _scaleAnimationController;
  late Animation<double> _scaleAnimation;

  // Hazard locations
  final List<Map<String, dynamic>> _hazardLocations = [
    {
      'name': 'Barangay Riverside - Flood Risk',
      'type': 'flood',
      'location': LatLng(14.3450, 121.0580),
      'severity': 'high',
      'description':
          'High flood risk during heavy rainfall and typhoons due to proximity to Laguna de Bay',
    },
    {
      'name': 'Barangay San Vicente - Landslide Risk',
      'type': 'landslide',
      'location': LatLng(14.3300, 121.0380),
      'severity': 'medium',
      'description':
          'Moderate landslide risk on steep slopes in hillside areas',
    },
    {
      'name': 'Pacita Complex - Heat Island',
      'type': 'heat',
      'location': LatLng(14.3189, 121.0401),
      'severity': 'medium',
      'description':
          'Urban heat island effect during summer months in dense residential area',
    },
    {
      'name': 'Barangay Landayan - Air Quality',
      'type': 'air_pollution',
      'location': LatLng(14.3380, 121.0450),
      'severity': 'medium',
      'description':
          'Elevated air pollution levels from commercial activities and heavy traffic',
    },
    {
      'name': 'Barangay Poblacion - Storm Surge',
      'type': 'storm_surge',
      'location': LatLng(14.3364, 121.0423),
      'severity': 'high',
      'description':
          'High storm surge risk during typhoons affecting central low-lying areas',
    },
    {
      'name': 'West Valley Fault Zone - Earthquake Risk',
      'type': 'earthquake',
      'location': LatLng(14.3280, 121.0350),
      'severity': 'high',
      'description':
          'Near West Valley Fault line - earthquake preparedness required for all residents',
    },
  ];

  @override
  void initState() {
    super.initState();

    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeInOut,
      ),
    );

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

    _initializeWeatherEffects();
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    _rainAnimationController.dispose();
    super.dispose();
  }

  void _initializeWeatherEffects() {
    final weatherCondition =
        widget.weatherData['weather'][0]['main'].toLowerCase();
    final temperature = widget.weatherData['main']['temp'] ?? 0.0;

    if (weatherCondition.contains('rain') ||
        weatherCondition.contains('thunderstorm')) {
      _showRainAnimation = true;
      _generateRainParticles();
    }

    if (temperature > 30 || temperature < 10) {
      _showTemperatureHeatmap = true;
      _generateTemperaturePoints();
    }

    if (widget.weatherData['wind'] != null) {
      _showWindArrows = true;
      _generateWindData();
    }
  }

  void _generateRainParticles() {
    _rainParticleLocations.clear();
    final random = Random();
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.05;
      final lat = widget.location.latitude + (distance * cos(angle));
      final lng = widget.location.longitude + (distance * sin(angle));
      _rainParticleLocations.add(LatLng(lat, lng));
    }
  }

  void _generateTemperaturePoints() {
    _temperaturePoints.clear();
    final random = Random();
    final baseTemp = widget.weatherData['main']['temp'] ?? 25.0;
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.08;
      final lat = widget.location.latitude + (distance * cos(angle));
      final lng = widget.location.longitude + (distance * sin(angle));
      final tempVariation = (random.nextDouble() - 0.5) * 6;
      final pointTemp = baseTemp + tempVariation;
      _temperaturePoints.add({
        'location': LatLng(lat, lng),
        'temperature': pointTemp,
        'intensity': _getTemperatureIntensity(pointTemp),
      });
    }
  }

  void _generateWindData() {
    _windData.clear();
    final random = Random();
    final windSpeed = widget.weatherData['wind']['speed'] ?? 0.0;
    final windDirection = widget.weatherData['wind']['deg'] ?? 0.0;
    for (int i = 0; i < 15; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 0.06;
      final lat = widget.location.latitude + (distance * cos(angle));
      final lng = widget.location.longitude + (distance * sin(angle));
      final directionVariation = (random.nextDouble() - 0.5) * 30;
      final pointDirection = windDirection + directionVariation;
      _windData.add({
        'location': LatLng(lat, lng),
        'speed': windSpeed + (random.nextDouble() - 0.5) * 2,
        'direction': pointDirection,
      });
    }
  }

  double _getTemperatureIntensity(double temperature) {
    if (temperature <= 0) return 0.0;
    if (temperature >= 40) return 1.0;
    return temperature / 40.0;
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature <= 10) return Colors.blue;
    if (temperature <= 20) return Colors.cyan;
    if (temperature <= 25) return Colors.green;
    if (temperature <= 30) return Colors.yellow;
    if (temperature <= 35) return Colors.orange;
    return Colors.red;
  }

  Color _getWeatherCircleColor() {
    final weatherCondition =
        widget.weatherData['weather'][0]['main'].toLowerCase();
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

  String _getForecastTileUrl(ForecastLayer layer) {
    const apiKey = 'a62db0fee1e1de12a993982cece6a6bc';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Main Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: widget.location,
                zoom: _currentZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && position.zoom != null) {
                    setState(() {
                      _currentZoom = position.zoom!;
                    });
                  }
                },
              ),
              children: [
                // Base map layer
                TileLayer(
                  urlTemplate: _getMapStyleUrl(),
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.weather_app',
                ),

                // Forecast overlay layer
                if (_forecastLayer != ForecastLayer.none)
                  TileLayer(
                    urlTemplate: _getForecastTileUrl(_forecastLayer),
                    backgroundColor: Colors.transparent,
                  ),

                // Temperature heatmap circles
                if (_showTemperatureHeatmap)
                  CircleLayer(
                    circles: _temperaturePoints.map((point) {
                      return CircleMarker(
                        point: point['location'],
                        radius: (800 + (point['intensity'] * 400)).toDouble(),
                        color: _getTemperatureColor(point['temperature'])
                            .withOpacity(0.15),
                        borderColor: _getTemperatureColor(point['temperature'])
                            .withOpacity(0.5),
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
                      point: widget.location,
                      builder: (ctx) => _buildWeatherMarker(),
                    ),

                    // Nearby locations
                    ..._buildNearbyLocationMarkers(),

                    // Hazard markers
                    if (_showHazardLocations) ..._buildHazardMarkers(),
                  ],
                ),

                // Weather coverage circle
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: widget.location,
                      radius: 5000,
                      color: _getWeatherCircleColor().withOpacity(0.08),
                      borderColor: _getWeatherCircleColor().withOpacity(0.3),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),

                // Pulsing effect
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: widget.location,
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

            // Weather emoji overlay
            _buildWeatherEmojiOverlay(),

            // Air quality indicator
            if (widget.airData != null && _showAirQualityIndicator)
              _buildAirQualityIndicator(),

            // Weather info overlay
            _buildWeatherInfoOverlay(),

            // Hazard toggle button
            Positioned(
              bottom: 120,
              left: 16,
              child: _buildHazardToggleButton(),
            ),

            // Guest overlay (if guest mode)
            if (widget.isGuest) _buildGuestOverlay(),
          ],
        ),
      ),
    );
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
                  color: Colors.blue.withOpacity(0.3),
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
    final main = widget.weatherData['weather'][0]['main'].toLowerCase();
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

  List<Marker> _buildRainParticles() {
    final random = Random();
    return _rainParticleLocations.map((location) {
      final dropHeight = 12.0 + random.nextDouble() * 8.0;
      final tilt = (random.nextDouble() - 0.5) * 0.2;
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
                    borderRadius: BorderRadius.circular(8),
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

  List<Marker> _buildWindArrows() {
    return _windData.map((windPoint) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: windPoint['location'],
        builder: (ctx) => Transform.rotate(
          angle: (windPoint['direction'] * pi) / 180,
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

  Color _getWindSpeedColor(double speed) {
    if (speed <= 5) return Colors.green;
    if (speed <= 10) return Colors.yellow;
    if (speed <= 15) return Colors.orange;
    return Colors.red;
  }

  List<Marker> _buildNearbyLocationMarkers() {
    final sanPedroLocations = [
      {'name': 'San Pedro City Hall', 'coords': LatLng(14.3358, 121.0417)},
      {
        'name': 'St. Peter the Apostle Cathedral',
        'coords': LatLng(14.3364, 121.0423)
      },
      {'name': 'Pacita Complex I', 'coords': LatLng(14.3189, 121.0401)},
      {'name': 'SM City San Pedro', 'coords': LatLng(14.3320, 121.0440)},
      {'name': 'Landayan Town Center', 'coords': LatLng(14.3390, 121.0460)},
      {'name': 'San Pedro Plaza', 'coords': LatLng(14.3361, 121.0419)},
      {'name': 'Laguna de Bay Shoreline', 'coords': LatLng(14.3480, 121.0600)},
      {'name': 'San Pedro Sports Complex', 'coords': LatLng(14.3290, 121.0370)},
    ];

    return sanPedroLocations.map((location) {
      return Marker(
        width: 30.0,
        height: 30.0,
        point: location['coords'] as LatLng,
        builder: (ctx) => Container(
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
      );
    }).toList();
  }

  List<Marker> _buildHazardMarkers() {
    return _hazardLocations.map((hazard) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: hazard['location'] as LatLng,
        builder: (ctx) => GestureDetector(
          onTap: () => _onHazardLocationTap(hazard),
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
                      color: Colors.black.withOpacity(0.6),
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
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
              const Expanded(
                child: Text(
                  'Hazard Alert',
                  style: TextStyle(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
            if (widget.airData != null)
              PopupMenuItem<String>(
                value: 'toggle_air_quality',
                child: Row(
                  children: [
                    Icon(
                      _showAirQualityIndicator
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _showAirQualityIndicator
                          ? Colors.purple
                          : Colors.grey,
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
                  Text('Center Map',
                      style: TextStyle(color: Colors.green.shade600)),
                ],
              ),
            ),
          ],
          onSelected: (String value) {
            setState(() {
              if (value == 'style_street') {
                _currentMapStyle = 'street';
              } else if (value == 'style_satellite') {
                _currentMapStyle = 'satellite';
              } else if (value == 'weather_off') {
                _forecastLayer = ForecastLayer.none;
              } else if (value == 'weather_rain') {
                _forecastLayer = ForecastLayer.precipitation;
              } else if (value == 'weather_temp') {
                _forecastLayer = ForecastLayer.temp;
              } else if (value == 'toggle_hazards') {
                _showHazardLocations = !_showHazardLocations;
              } else if (value == 'toggle_air_quality') {
                _showAirQualityIndicator = !_showAirQualityIndicator;
              } else if (value == 'center_location') {
                _mapController.move(widget.location, 14.0);
              }
            });
          },
        ),
      ),
    );
  }

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
        ),
        child: Text(
          _getWeatherEmoji(),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  String _getWeatherEmoji() {
    final condition = widget.weatherData['weather'][0]['main'].toLowerCase();
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

  Widget _buildAirQualityIndicator() {
    final aqi = widget.airData!['list'][0]['main']['aqi'];
    final aqiInfo = _getAQIInfo(aqi);

    return Positioned(
      bottom: 220,
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

  Map<String, dynamic> _getAQIInfo(int aqi) {
    switch (aqi) {
      case 1:
        return {'label': 'Good', 'color': Colors.green};
      case 2:
        return {'label': 'Fair', 'color': Colors.yellow};
      case 3:
        return {'label': 'Moderate', 'color': Colors.orange};
      case 4:
        return {'label': 'Poor', 'color': Colors.red};
      case 5:
        return {'label': 'Very Poor', 'color': Colors.purple};
      default:
        return {'label': 'Unknown', 'color': Colors.grey};
    }
  }

  Widget _buildWeatherInfoOverlay() {
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
                    widget.weatherData['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${widget.weatherData['main']['temp'].round()}°C - ${widget.weatherData['weather'][0]['description']}',
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

  Widget _buildHazardToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: _showHazardLocations ? Colors.red.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color:
              _showHazardLocations ? Colors.red.shade900 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _showHazardLocations = !_showHazardLocations;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_rounded,
                  color:
                      _showHazardLocations ? Colors.white : Colors.red.shade700,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _showHazardLocations ? 'HAZARDS ON' : 'HAZARDS OFF',
                  style: TextStyle(
                    color: _showHazardLocations
                        ? Colors.white
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestOverlay() {
    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sign in for personalized weather alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
