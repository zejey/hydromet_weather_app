import 'package:flutter/material.dart';

class WeatherInfoCard extends StatelessWidget {
  final Map<String, dynamic> weatherData;

  const WeatherInfoCard({
    required this.weatherData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // City name
          Text(
            weatherData['name'] ?? 'Unknown',
            style: const TextStyle(
              fontSize: 44,
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

          // Weather icon
          Image.network(
            "https://openweathermap.org/img/wn/${weatherData['weather'][0]['icon']}@2x.png",
            width: 100,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.wb_cloudy,
                size: 100,
                color: Colors.white,
              );
            },
          ),
          const SizedBox(height: 8),

          // Temperature
          Text(
            "${weatherData['main']['temp'].round()}°C",
            style: const TextStyle(
              fontSize: 64,
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

          // Weather description
          Text(
            weatherData['weather'][0]['description'].toString().toUpperCase(),
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
        ],
      ),
    );
  }
}
