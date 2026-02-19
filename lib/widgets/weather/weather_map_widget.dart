import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum ForecastLayer { none, precipitation, clouds, temp, wind }

class WeatherMapWidget extends StatefulWidget {
  final LatLng selectedLocation;
  final double initialZoom;

  final ForecastLayer forecastLayer;

  final bool showEvacuationCenters;
  final bool showNearestEvacuationCenters;
  final bool showGovernmentAgencies;

  final List<Map<String, dynamic>> evacuationCenters;
  final List<Map<String, dynamic>> governmentAgencies;

  final Function(LatLng point)? onMapTap;

  final double searchRadius;
  final LatLng? pinnedLocation;

  final MapController? externalMapController;

  const WeatherMapWidget({
    super.key,
    required this.selectedLocation,
    this.initialZoom = 14.0,
    this.forecastLayer = ForecastLayer.none,
    this.showEvacuationCenters = false,
    this.showNearestEvacuationCenters = false,
    this.showGovernmentAgencies = false,
    required this.evacuationCenters,
    required this.governmentAgencies,
    this.onMapTap,
    this.searchRadius = 500,
    this.pinnedLocation,
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

  // MARKERS

  Widget _buildSelectedLocationMarker() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.blue.shade700, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.my_location,
        color: Colors.blue.shade700,
        size: 20,
      ),
    );
  }

  Marker? _buildPinnedLocationMarker() {
    if (widget.pinnedLocation == null) return null;
    return Marker(
      width: 40.0,
      height: 40.0,
      point: widget.pinnedLocation!,
      builder: (context) => Container(
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

  List<Marker> _buildEvacuationCenterMarkers() {
    if (!widget.showEvacuationCenters && !widget.showNearestEvacuationCenters) {
      return [];
    }

    final hasPin = widget.pinnedLocation != null;
    var centersToShow = widget.evacuationCenters;

    // Only filter when "nearest" is enabled AND there is a pin
    if (widget.showNearestEvacuationCenters && hasPin) {
      final referencePoint = widget.pinnedLocation!;
      centersToShow = centersToShow.where((center) {
        final loc = center['location'];
        if (loc is! LatLng) return false;
        final distance = _calculateDistance(referencePoint, loc);
        return distance <= widget.searchRadius;
      }).toList();
    }

    final showAsNearest = widget.showNearestEvacuationCenters && hasPin;

    return centersToShow.map((center) {
      final loc = center['location'] as LatLng;
      return Marker(
        width: 32.0,
        height: 32.0,
        point: loc,
        builder: (context) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                showAsNearest ? Colors.purple.shade600 : Colors.green.shade600,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            showAsNearest ? Icons.near_me : Icons.home_work,
            color: Colors.white,
            size: 14,
          ),
        ),
      );
    }).toList();
  }

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
        case 'barangay_hall':
          color = Colors.purple.shade600;
          icon = Icons.account_balance;
          break;
        default:
          color = Colors.orange.shade600;
          icon = Icons.location_city;
      }

      final loc = agency['location'] as LatLng;
      return Marker(
        width: 32.0,
        height: 32.0,
        point: loc,
        builder: (context) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      );
    }).toList();
  }

  CircleMarker? _buildSearchRadiusCircle() {
    if (!widget.showNearestEvacuationCenters) return null;
    if (widget.pinnedLocation == null) return null;

    return CircleMarker(
      point: widget.pinnedLocation!,
      radius: widget.searchRadius,
      color: Colors.purple.withOpacity(0.10),
      borderColor: Colors.purple.withOpacity(0.5),
      borderStrokeWidth: 2,
    );
  }

  // UTIL

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: widget.selectedLocation,
        zoom: _currentZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        onTap: (tapPosition, point) => widget.onMapTap?.call(point),
        onMapEvent: (MapEvent event) {
          if (event is MapEventMove) {
            setState(() => _currentZoom = event.zoom);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _getMapStyleUrl(),
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.weather_app',
        ),
        if (widget.forecastLayer != ForecastLayer.none)
          TileLayer(urlTemplate: _getForecastTileUrl(widget.forecastLayer)),
        CircleLayer(
          circles: [
            if (_buildSearchRadiusCircle() != null) _buildSearchRadiusCircle()!,
          ],
        ),
        MarkerLayer(
          markers: [
            // Selected location marker (blue)
            Marker(
              width: 50,
              height: 50,
              point: widget.selectedLocation,
              builder: (_) => _buildSelectedLocationMarker(),
            ),

            // Pinned marker (purple)
            if (_buildPinnedLocationMarker() != null)
              _buildPinnedLocationMarker()!,

            // Evacuation centers
            ..._buildEvacuationCenterMarkers(),

            // Government agencies
            ..._buildGovernmentAgencyMarkers(),
          ],
        ),
      ],
    );
  }
}
