import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum ForecastLayer { none, precipitation, clouds, temp, wind }

class WeatherMapWidget extends StatefulWidget {
  final LatLng selectedLocation;
  final double initialZoom;
  final Map<String, dynamic>? weatherData;
  final bool showHazardLocations;
  final bool showEvacuationCenters;
  final bool showNearestEvacuationCenters;
  final bool showGovernmentAgencies;
  final bool showAirQualityIndicator;
  final bool showSafetyIndicator;
  final List<Map<String, dynamic>> hazardLocations;
  final List<Map<String, dynamic>> evacuationCenters;
  final List<Map<String, dynamic>> governmentAgencies;
  final Map<String, dynamic>? airData;
  final List<Map<String, dynamic>> temperaturePoints;
  final List<Map<String, dynamic>> windData;
  final List<LatLng> rainParticleLocations;
  final Animation<double> rainAnimation;
  final Animation<double> scaleAnimation;
  final ForecastLayer forecastLayer;
  final Function(LatLng point)? onMapTap;
  final double searchRadius;
  final LatLng? pinnedLocation;
  final bool showRainAnimation;
  final bool showWindArrows;
  final bool showTemperatureHeatmap;
  final MapController? externalMapController;

  const WeatherMapWidget({
    super.key,
    required this.selectedLocation,
    this.initialZoom = 14.0,
    this.weatherData,
    this.showHazardLocations = false,
    this.showEvacuationCenters = false,
    this.showNearestEvacuationCenters = false,
    this.showGovernmentAgencies = false,
    this.showAirQualityIndicator = false,
    this.showSafetyIndicator = false,
    required this.hazardLocations,
    required this.evacuationCenters,
    required this.governmentAgencies,
    this.airData,
    this.temperaturePoints = const [],
    this.windData = const [],
    this.rainParticleLocations = const [],
    required this.rainAnimation,
    required this.scaleAnimation,
    this.forecastLayer = ForecastLayer.none,
    this.onMapTap,
    this.searchRadius = 400,
    this.pinnedLocation,
    this.showRainAnimation = false,
    this.showWindArrows = false,
    this.showTemperatureHeatmap = false,
    this.externalMapController,
  });

  @override
  State<WeatherMapWidget> createState() => _WeatherMapWidgetState();
}

class _WeatherMapWidgetState extends State<WeatherMapWidget> {
  late MapController _mapController;
  late double _currentZoom;
  String _currentMapStyle = 'street';

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    _mapController = widget.externalMapController ?? MapController();
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

  // MARKER HELPERS

  Widget _buildWeatherMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: widget.scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.scaleAnimation.value,
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
    final weatherData = widget.weatherData;
    if (weatherData == null) return Icons.location_on;
    final main = weatherData['weather'][0]['main'].toLowerCase();
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
    return widget.rainParticleLocations.map((location) {
      final dropHeight = 12.0 + random.nextDouble() * 8.0;
      final tilt = (random.nextDouble() - 0.5) * 0.2;
      return Marker(
        width: 18.0,
        height: 24.0,
        point: location,
        child: AnimatedBuilder(
          animation: widget.rainAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, widget.rainAnimation.value * 10),
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
    return widget.windData.map((windPoint) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: windPoint['location'],
        child: Transform.rotate(
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

  // Hazards
  List<Marker> _buildHazardMarkers() {
    if (!widget.showHazardLocations) return [];
    return widget.hazardLocations.map((hazard) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: hazard['location'] as LatLng,
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
        return baseColor.withOpacity(0.8);
      case 'medium':
        return baseColor;
      case 'low':
        return baseColor.withOpacity(0.6);
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
        return Icons.waves;
      case 'earthquake':
        return Icons.vibration;
      default:
        return Icons.warning;
    }
  }

  // Evacuation Centers
  List<Marker> _buildEvacuationCenterMarkers() {
    if (!widget.showEvacuationCenters && !widget.showNearestEvacuationCenters) return [];
    List<Map<String, dynamic>> centersToShow = widget.evacuationCenters;
    if (widget.showNearestEvacuationCenters && widget.pinnedLocation != null) {
      centersToShow = widget.evacuationCenters.where((center) {
        final distance = _calculateDistance(widget.pinnedLocation!, center['location'] as LatLng);
        return distance <= widget.searchRadius;
      }).toList();
    }
    return centersToShow.map((center) {
      return Marker(
        width: 32.0,
        height: 32.0,
        point: center['location'] as LatLng,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.showNearestEvacuationCenters
                ? Colors.purple.shade600
                : Colors.green.shade600,
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
            widget.showNearestEvacuationCenters
                ? Icons.near_me
                : Icons.home_work,
            color: Colors.white,
            size: 14,
          ),
        ),
      );
    }).toList();
  }

  // Pinned Location Marker
  Marker? _buildPinnedLocationMarker() {
    if (widget.pinnedLocation == null) return null;
    return Marker(
      width: 40.0,
      height: 40.0,
      point: widget.pinnedLocation!,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.purple.shade700,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_pin,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // Search Radius Circle
  CircleMarker? _buildSearchRadiusCircle() {
    if (widget.pinnedLocation == null || !widget.showNearestEvacuationCenters) return null;
    return CircleMarker(
      point: widget.pinnedLocation!,
      radius: widget.searchRadius,
      color: Colors.purple.withOpacity(0.1),
      borderColor: Colors.purple.withOpacity(0.5),
      borderStrokeWidth: 2,
    );
  }

  // Government Agencies
  List<Marker> _buildGovernmentAgencyMarkers() {
    if (!widget.showGovernmentAgencies) return [];
    return widget.governmentAgencies.map((agency) {
      final type = agency['type'];
      Color color;
      IconData icon;
      switch (type) {
        case 'fire_station':
          color = Colors.red.shade600;
          icon = Icons.local_fire_department;
          break;
        case 'police_station':
          color = Colors.blue.shade600;
          icon = Icons.local_police;
          break;
        case 'city_hall':
          color = Colors.purple.shade600;
          icon = Icons.account_balance;
          break;
        default:
          color = Colors.orange.shade600;
          icon = Icons.location_city;
      }
      return Marker(
        width: 32.0,
        height: 32.0,
        point: agency['location'] as LatLng,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
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
            icon,
            color: Colors.white,
            size: 14,
          ),
        ),
      );
    }).toList();
  }

  // UTILITIES

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Temperature heatmap
  Color _getTemperatureColor(double temperature) {
    if (temperature <= 10) return Colors.blue;
    if (temperature <= 20) return Colors.cyan;
    if (temperature <= 25) return Colors.green;
    if (temperature <= 30) return Colors.yellow;
    if (temperature <= 35) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(vertical: 10),
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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.selectedLocation,
                initialZoom: _currentZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (tapPosition, point) {
                  if (widget.onMapTap != null) widget.onMapTap!(point);
                },
                onMapEvent: (MapEvent event) {
                  if (event is MapEventMove) {
                    setState(() {
                      _currentZoom = event.camera.zoom; 
                    });
                  }
                },
              ),
              children: [
                // Base
                TileLayer(
                  urlTemplate: _getMapStyleUrl(),
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.weather_app',
                ),
                // Forecast overlay
                if (widget.forecastLayer != ForecastLayer.none)
                  TileLayer(
                    urlTemplate: _getForecastTileUrl(widget.forecastLayer),
                  ),
                // Temperature heatmap
                if (widget.showTemperatureHeatmap)
                  CircleLayer(
                    circles: widget.temperaturePoints.map((point) {
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
                // Rain
                if (widget.showRainAnimation)
                  MarkerLayer(
                    markers: _buildRainParticles(),
                  ),
                // Wind
                if (widget.showWindArrows)
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
                      point: widget.selectedLocation,
                      child: _buildWeatherMarker(),
                    ),
                    // Pinned
                    if (_buildPinnedLocationMarker() != null) _buildPinnedLocationMarker()!,
                    // Hazards
                    ..._buildHazardMarkers(),
                    // Evacuation
                    ..._buildEvacuationCenterMarkers(),
                    // Agencies
                    ..._buildGovernmentAgencyMarkers(),
                  ],
                ),
                // Search radius
                CircleLayer(
                  circles: [
                    if (_buildSearchRadiusCircle() != null)
                      _buildSearchRadiusCircle()!,
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
