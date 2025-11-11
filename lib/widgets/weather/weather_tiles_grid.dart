import 'package:flutter/material.dart';

class WeatherTilesGrid extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  final Map<String, dynamic>? airData;
  final bool isGuest;

  const WeatherTilesGrid({
    required this.weatherData,
    this.airData,
    this.isGuest = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _buildWeatherTile(
        "Feels Like",
        "${weatherData['main']['feels_like'].round()}°C",
        Icons.thermostat,
      ),
      _buildWeatherTile(
        "Humidity",
        "${weatherData['main']['humidity']}%",
        Icons.water_drop,
      ),
      _buildWeatherTile(
        "Wind",
        "${weatherData['wind']['speed']} m/s",
        Icons.air,
      ),
      _buildWeatherTile(
        "Pressure",
        "${weatherData['main']['pressure']} hPa",
        Icons.speed,
      ),
      _buildWeatherTile(
        "Visibility",
        "${(weatherData['visibility'] / 1000).toStringAsFixed(1)} km",
        Icons.remove_red_eye,
      ),
      _buildWeatherTile(
        "Clouds",
        "${weatherData['clouds']['all']}%",
        Icons.cloud,
      ),
    ];

    // Add Air Quality tile if available
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

    // Build grid layout
    List<Widget> rows = [];
    for (int i = 0; i < tiles.length; i += 2) {
      if (i == tiles.length - 1) {
        // Last tile (full width)
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: tiles[i],
        ));
      } else {
        // Two tiles side by side
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _buildWeatherTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.85),
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
          Icon(icon, color: Colors.black87, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getAQIInfo(int aqi) {
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
}