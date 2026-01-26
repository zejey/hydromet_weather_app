import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/weather/weather_map_widget.dart';

class MapTabScreen extends StatefulWidget {
  const MapTabScreen({Key? key}) : super(key: key);

  @override
  State<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends State<MapTabScreen> with TickerProviderStateMixin {
  LatLng _selectedLocation = LatLng(14.3583, 121.0167);
  LatLng? _pinnedLocation;
  
  ForecastLayer _currentLayer = ForecastLayer.none;
  bool _showHazardLocations = false;
  bool _showEvacuationCenters = false;
  bool _showNearestEvacuationCenters = false;
  bool _showGovernmentAgencies = false;
  bool _showRainAnimation = false;
  bool _showWindArrows = false;
  bool _showTemperatureHeatmap = false;
  
  // ✅ Control bottom sheet state
  bool _isBottomSheetExpanded = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  late AnimationController _rainController;
  late AnimationController _scaleController;
  late Animation<double> _rainAnimation;
  late Animation<double> _scaleAnimation;

  // Sample data
  final List<Map<String, dynamic>> _hazardLocations = [
    {
      'location': LatLng(14.3600, 121.0180),
      'type': 'flood',
      'severity': 'high',
      'name': 'Flood-prone Area - Barangay San Antonio',
    },
    {
      'location': LatLng(14.3550, 121.0150),
      'type': 'landslide',
      'severity': 'medium',
      'name': 'Landslide Risk Zone - Barangay Landayan',
    },
    {
      'location': LatLng(14.3620, 121.0200),
      'type': 'heat',
      'severity': 'high',
      'name': 'High Heat Index Area',
    },
  ];

  final List<Map<String, dynamic>> _evacuationCenters = [
    {
      'location': LatLng(14.3590, 121.0170),
      'name': 'San Pedro Evacuation Center 1',
      'capacity': 500,
    },
    {
      'location': LatLng(14.3570, 121.0160),
      'name': 'San Pedro Evacuation Center 2',
      'capacity': 300,
    },
    {
      'location': LatLng(14.3610, 121.0190),
      'name': 'Barangay Hall Evacuation Site',
      'capacity': 200,
    },
  ];

  final List<Map<String, dynamic>> _governmentAgencies = [
    {
      'location': LatLng(14.3595, 121.0175),
      'type': 'fire_station',
      'name': 'San Pedro Fire Station',
    },
    {
      'location': LatLng(14.3575, 121.0155),
      'type': 'police_station',
      'name': 'San Pedro Police Station',
    },
    {
      'location': LatLng(14.3585, 121.0165),
      'type': 'city_hall',
      'name': 'San Pedro City Hall',
    },
  ];

  final List<Map<String, dynamic>> _temperaturePoints = [
    {
      'location': LatLng(14.3583, 121.0167),
      'temperature': 32.0,
      'intensity': 0.8,
    },
    {
      'location': LatLng(14.3600, 121.0180),
      'temperature': 28.0,
      'intensity': 0.5,
    },
  ];

  final List<Map<String, dynamic>> _windData = [
    {
      'location': LatLng(14.3590, 121.0170),
      'speed': 12.0,
      'direction': 45.0,
    },
    {
      'location': LatLng(14.3570, 121.0160),
      'speed': 8.0,
      'direction': 90.0,
    },
  ];

  final List<LatLng> _rainParticleLocations = [
    LatLng(14.3580, 121.0165),
    LatLng(14.3585, 121.0170),
    LatLng(14.3590, 121.0175),
    LatLng(14.3595, 121.0180),
  ];

  @override
  void initState() {
    super.initState();
    
    _rainController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat();
    
    _rainAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_rainController);

    _scaleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rainController.dispose();
    _scaleController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _pinnedLocation = point;
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

  int _getActiveLayersCount() {
    int count = 0;
    if (_showHazardLocations) count++;
    if (_showEvacuationCenters) count++;
    if (_showNearestEvacuationCenters) count++;
    if (_showGovernmentAgencies) count++;
    if (_showRainAnimation) count++;
    if (_showWindArrows) count++;
    if (_showTemperatureHeatmap) count++;
    if (_currentLayer != ForecastLayer.none) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Full-screen map
          WeatherMapWidget(
            selectedLocation: _selectedLocation,
            initialZoom: 14.0,
            forecastLayer: _currentLayer,
            showHazardLocations: _showHazardLocations,
            showEvacuationCenters: _showEvacuationCenters,
            showNearestEvacuationCenters: _showNearestEvacuationCenters,
            showGovernmentAgencies: _showGovernmentAgencies,
            showRainAnimation: _showRainAnimation,
            showWindArrows: _showWindArrows,
            showTemperatureHeatmap: _showTemperatureHeatmap,
            hazardLocations: _hazardLocations,
            evacuationCenters: _evacuationCenters,
            governmentAgencies: _governmentAgencies,
            temperaturePoints: _temperaturePoints,
            windData: _windData,
            rainParticleLocations: _rainParticleLocations,
            rainAnimation: _rainAnimation,
            scaleAnimation: _scaleAnimation,
            onMapTap: _handleMapTap,
            pinnedLocation: _pinnedLocation,
            searchRadius: 500,
          ),

          // ✅ Top bar with title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
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
                    // ✅ Active layers badge
                    if (_getActiveLayersCount() > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_getActiveLayersCount()} active',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ Floating action buttons (right side)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            child: Column(
              children: [
                // Center on location
                FloatingActionButton(
                  heroTag: 'center',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _selectedLocation = LatLng(14.3583, 121.0167);
                    });
                  },
                  child: Icon(Icons.my_location, color: Colors.green.shade700),
                ),
                const SizedBox(height: 8),
                
                // Toggle legend
                FloatingActionButton(
                  heroTag: 'legend',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _showLegendDialog();
                  },
                  child: Icon(Icons.info_outline, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 8),
                
                // Clear pins
                if (_pinnedLocation != null)
                  FloatingActionButton(
                    heroTag: 'clear',
                    mini: true,
                    backgroundColor: Colors.red.shade100,
                    onPressed: () {
                      setState(() {
                        _pinnedLocation = null;
                        _showNearestEvacuationCenters = false;
                      });
                    },
                    child: const Icon(Icons.clear, color: Colors.red),
                  ),
              ],
            ),
          ),

          // ✅ Draggable bottom sheet for controls
          _buildDraggableBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.15,  // Start small (just handle visible)
      minChildSize: 0.15,
      maxChildSize: 0.75,  // Can expand to 75% of screen
      snap: true,
      snapSizes: const [0.15, 0.4, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ✅ Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // ✅ Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.layers, color: Colors.green.shade700, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Map Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentLayer = ForecastLayer.none;
                          _showHazardLocations = false;
                          _showEvacuationCenters = false;
                          _showNearestEvacuationCenters = false;
                          _showGovernmentAgencies = false;
                          _showRainAnimation = false;
                          _showWindArrows = false;
                          _showTemperatureHeatmap = false;
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // ✅ Scrollable content
                Expanded(
                child: Container(
                  // Add subtle background for better text readability
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Weather Layers
                      _buildSectionTitle('🌦️ Weather Layers'),
                      const SizedBox(height: 12),
                      _buildLayerSelector(),
                      
                      const SizedBox(height: 24),
                      
                      // Markers
                      _buildSectionTitle('📍 Markers'),
                      const SizedBox(height: 12),
                      _buildCompactToggle(
                        'Hazard Locations',
                        Icons.warning,
                        Colors.red,
                        _showHazardLocations,
                        (val) => setState(() => _showHazardLocations = val),
                      ),
                      _buildCompactToggle(
                        'Evacuation Centers',
                        Icons.home_work,
                        Colors.green,
                        _showEvacuationCenters,
                        (val) => setState(() => _showEvacuationCenters = val),
                      ),
                      _buildCompactToggle(
                        'Nearest Centers',
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
                      
                      const SizedBox(height: 24),
                      
                      // Overlays
                      _buildSectionTitle('🌈 Visual Effects'),
                      const SizedBox(height: 12),
                      _buildCompactToggle(
                        'Rain Animation',
                        Icons.grain,
                        Colors.blue,
                        _showRainAnimation,
                        (val) => setState(() => _showRainAnimation = val),
                      ),
                      _buildCompactToggle(
                        'Wind Arrows',
                        Icons.air,
                        Colors.cyan,
                        _showWindArrows,
                        (val) => setState(() => _showWindArrows = val),
                      ),
                      _buildCompactToggle(
                        'Temperature Heatmap',
                        Icons.thermostat,
                        Colors.orange,
                        _showTemperatureHeatmap,
                        (val) => setState(() => _showTemperatureHeatmap = val),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Help tip
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.green.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app, color: Colors.blue.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tap anywhere on the map to pin a location',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildLayerSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLayerChip('None', ForecastLayer.none, Icons.layers_clear),
        _buildLayerChip('Rain', ForecastLayer.precipitation, Icons.water_drop),
        _buildLayerChip('Clouds', ForecastLayer.clouds, Icons.cloud),
        _buildLayerChip('Temp', ForecastLayer.temp, Icons.thermostat),
        _buildLayerChip('Wind', ForecastLayer.wind, Icons.air),
      ],
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

  Widget _buildCompactToggle(
    String label,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
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

  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.map, color: Colors.green),
            SizedBox(width: 12),
            Text('Map Legend'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(Icons.warning, Colors.red, 'Hazard Locations'),
              _buildLegendItem(Icons.home_work, Colors.green, 'Evacuation Centers'),
              _buildLegendItem(Icons.near_me, Colors.purple, 'Nearest Centers'),
              _buildLegendItem(Icons.local_fire_department, Colors.red, 'Fire Station'),
              _buildLegendItem(Icons.local_police, Colors.blue, 'Police Station'),
              _buildLegendItem(Icons.account_balance, Colors.purple, 'City Hall'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}