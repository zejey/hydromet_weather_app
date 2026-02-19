import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../widgets/weather/weather_map_widget.dart';
import 'package:flutter_map/flutter_map.dart';

class MapTabScreen extends StatefulWidget {
  const MapTabScreen({super.key});

  @override
  State<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends State<MapTabScreen>
    with WidgetsBindingObserver {
  static const String _apiBaseUrl =
      "https://caring-kindness-production.up.railway.app";

  LatLng _selectedLocation = LatLng(14.3583, 121.0167);
  LatLng? _pinnedLocation;

  ForecastLayer _currentLayer = ForecastLayer.none;
  bool _showEvacuationCenters = false;
  bool _showNearestEvacuationCenters = false;
  bool _showGovernmentAgencies = false;
  final MapController _mapController = MapController();

  bool _isMapDataLoading = false;

  List<Map<String, dynamic>> _evacuationCenters = [];
  List<Map<String, dynamic>> _governmentAgencies = [];

  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapData();
    _updateLocationAndCenter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateLocationAndCenter();
    }
  }

  void _centerOn(LatLng point) {
    setState(() => _selectedLocation = point);
    _mapController.move(point, 14.0);
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _updateLocationAndCenter({bool startStream = true}) async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    // 1) last known (fast)
    final last = await Geolocator.getLastKnownPosition();
    if (last != null && mounted) {
      _centerOn(LatLng(last.latitude, last.longitude));
    }

    // 2) fresh current position (more accurate)
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;
      _centerOn(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // ignore: if GPS is slow, we still have last known
    }

    // 3) optional live updates while on the map screen
    if (!startStream) return;

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // keeps battery reasonable
        distanceFilter: 25, // only update every 25m
      ),
    ).listen((p) {
      if (!mounted) return;
      _centerOn(LatLng(p.latitude, p.longitude));
    });
  }

  Future<void> _loadMapData() async {
    try {
      setState(() => _isMapDataLoading = true);

      final evacRes = await http.get(
        Uri.parse('$_apiBaseUrl/api/evacuation-centers/'),
      );

      if (evacRes.statusCode == 200) {
        final evacList = jsonDecode(evacRes.body) as List<dynamic>;
        _evacuationCenters = evacList.map<Map<String, dynamic>>((e) {
          final m = e as Map<String, dynamic>;
          final lat = (m['lat'] as num).toDouble();
          final lng = (m['lng'] as num).toDouble();
          return {
            ...m,
            'location': LatLng(lat, lng),
          };
        }).toList();
      } else {
        debugPrint(
          'Evacuation centers error: ${evacRes.statusCode} ${evacRes.body}',
        );
      }

      final govRes = await http.get(
        Uri.parse('$_apiBaseUrl/api/government-agencies/'),
      );

      if (govRes.statusCode == 200) {
        final govList = jsonDecode(govRes.body) as List<dynamic>;
        _governmentAgencies = govList.map<Map<String, dynamic>>((e) {
          final m = e as Map<String, dynamic>;
          final loc = m['location'] as Map<String, dynamic>;
          final lat = (loc['latitude'] as num).toDouble();
          final lng = (loc['longitude'] as num).toDouble();
          return {
            ...m,
            'location': LatLng(lat, lng),
          };
        }).toList();
      } else {
        debugPrint(
          'Government agencies error: ${govRes.statusCode} ${govRes.body}',
        );
      }

      if (!mounted) return;
      setState(() => _isMapDataLoading = false);
    } catch (e) {
      debugPrint('Map data fetch failed: $e');
      if (!mounted) return;
      setState(() => _isMapDataLoading = false);
    }
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _pinnedLocation = point;

      // Optional: auto-enable nearest once pinned so user sees results immediately
      _showNearestEvacuationCenters = true;
      _showEvacuationCenters = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location pinned: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.map, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Weather Map',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isMapDataLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactToggle(
    String label,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? color.withOpacity(0.5) : Colors.grey.shade200,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                  color: value ? color : Colors.black87,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticControlsPanelInline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.layers, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  const Text(
                    'Map Controls',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentLayer = ForecastLayer.none;
                        _showEvacuationCenters = false;
                        _showNearestEvacuationCenters = false;
                        _showGovernmentAgencies = false;
                        _pinnedLocation = null;
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Weather overlay chips (you can remove these if you don’t want any overlay)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLayerChip(
                      'None', ForecastLayer.none, Icons.layers_clear),
                  _buildLayerChip(
                      'Rain', ForecastLayer.precipitation, Icons.water_drop),
                  _buildLayerChip('Clouds', ForecastLayer.clouds, Icons.cloud),
                ],
              ),

              const SizedBox(height: 12),

              _buildCompactToggle(
                'Evacuation Centers',
                Icons.home_work,
                Colors.green,
                _showEvacuationCenters,
                (val) => setState(() => _showEvacuationCenters = val),
              ),
              _buildCompactToggle(
                'Nearest Centers (pin required)',
                Icons.near_me,
                Colors.purple,
                _showNearestEvacuationCenters,
                (val) => setState(() => _showNearestEvacuationCenters = val),
              ),
              _buildCompactToggle(
                'Government Agencies',
                Icons.account_balance,
                Colors.blue,
                _showGovernmentAgencies,
                (val) => setState(() => _showGovernmentAgencies = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerChip(String label, ForecastLayer layer, IconData icon) {
    final isSelected = _currentLayer == layer;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentLayer = selected ? layer : ForecastLayer.none;
        });
      },
      selectedColor: Colors.green.shade600,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: WeatherMapWidget(
                externalMapController: _mapController,
                selectedLocation: _selectedLocation,
                initialZoom: 14.0,
                forecastLayer: _currentLayer,
                showEvacuationCenters: _showEvacuationCenters,
                showNearestEvacuationCenters: _showNearestEvacuationCenters,
                showGovernmentAgencies: _showGovernmentAgencies,
                evacuationCenters: _evacuationCenters,
                governmentAgencies: _governmentAgencies,
                pinnedLocation: _pinnedLocation,
                searchRadius: 500,
                onMapTap: _handleMapTap,
              ),
            ),
            _buildStaticControlsPanelInline(),
          ],
        ),
      ),
    );
  }
}
