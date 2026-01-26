import 'package:flutter/material.dart';

class HourlyForecastCard extends StatelessWidget {
  final List<Map<String, dynamic>> forecast;

  const HourlyForecastCard({
    required this.forecast,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (forecast.isEmpty) return const SizedBox.shrink();

    // Get min and max temps for scaling the graph
    double minTemp = forecast
        .map((f) => (f['temp'] as num).toDouble())
        .reduce((a, b) => a < b ? a : b);
    double maxTemp = forecast
        .map((f) => (f['temp'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              const Text(
                '24-Hour Forecast',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.update, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_getUpdateTime()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: forecast.length > 24 ? 24 : forecast.length,
              itemBuilder: (context, index) {
                final item = forecast[index];
                final temp = (item['temp'] as num).toDouble();
                final time = item['time'] as String;
                final icon = item['icon'] as String;
                
                // Calculate position for line chart
                final normalizedTemp = maxTemp > minTemp
                    ? (temp - minTemp) / (maxTemp - minTemp)
                    : 0.5;

                return Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Temperature text
                      Text(
                        '${temp.round()}°',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Temperature line chart indicator
                      SizedBox(
                        height: 60,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Vertical line from bottom to temp position
                            Positioned(
                              bottom: 0,
                              left: 33,
                              child: Container(
                                width: 3,
                                height: 60 * normalizedTemp,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.blue.shade300,
                                      Colors.blue.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Temperature dot
                            Positioned(
                              bottom: (60 * normalizedTemp) - 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // ✅ Weather icon - use colored Material Icons instead
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getWeatherColor(icon).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getWeatherColor(icon).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _getWeatherIcon(icon),
                          color: _getWeatherColor(icon),
                          size: 28,
                        ),
                      ),
                      
                      const SizedBox(height: 2),
                      
                      // ✅ Time label - simplified format
                      Text(
                        _formatTime(time),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Map weather icon codes to Material Icons
  IconData _getWeatherIcon(String iconCode) {
    if (iconCode.contains('01')) return Icons.wb_sunny; // Clear sky
    if (iconCode.contains('02')) return Icons.wb_sunny_outlined; // Few clouds
    if (iconCode.contains('03')) return Icons.cloud; // Scattered clouds
    if (iconCode.contains('04')) return Icons.cloud_queue; // Broken clouds
    if (iconCode.contains('09')) return Icons.grain; // Shower rain
    if (iconCode.contains('10')) return Icons.wb_cloudy; // Rain
    if (iconCode.contains('11')) return Icons.thunderstorm; // Thunderstorm
    if (iconCode.contains('13')) return Icons.ac_unit; // Snow
    if (iconCode.contains('50')) return Icons.blur_on; // Mist
    return Icons.wb_cloudy; // Default
  }

  // ✅ Get color based on weather condition
  Color _getWeatherColor(String iconCode) {
    if (iconCode.contains('01')) return Colors.orange; // Clear - orange/yellow
    if (iconCode.contains('02')) return Colors.amber; // Few clouds - amber
    if (iconCode.contains('03')) return Colors.grey.shade600; // Clouds - grey
    if (iconCode.contains('04')) return Colors.grey.shade700; // More clouds - dark grey
    if (iconCode.contains('09')) return Colors.blue.shade600; // Shower - blue
    if (iconCode.contains('10')) return Colors.blue.shade700; // Rain - darker blue
    if (iconCode.contains('11')) return Colors.deepPurple; // Thunderstorm - purple
    if (iconCode.contains('13')) return Colors.lightBlue.shade300; // Snow - light blue
    if (iconCode.contains('50')) return Colors.blueGrey; // Mist - blue grey
    return Colors.grey.shade600; // Default
  }

  // ✅ Format time to simple hour format
  String _formatTime(String timeString) {
    try {
      // Parse ISO datetime string
      final dateTime = DateTime.parse(timeString);
      final now = DateTime.now();
      
      // Check if it's the current hour (show "Now")
      if (dateTime.hour == now.hour && dateTime.day == now.day) {
        return 'Now';
      }
      
      // Format to 12-hour time with AM/PM
      final hour = dateTime.hour;
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final period = hour >= 12 ? 'PM' : 'AM';
      
      return '$displayHour $period';
    } catch (e) {
      print('Error parsing time "$timeString": $e');
      return timeString;
    }
  }

  String _getUpdateTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}