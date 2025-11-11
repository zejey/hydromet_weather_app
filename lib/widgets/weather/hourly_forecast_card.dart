import 'package:flutter/material.dart';
import 'temperature_graph_painter.dart';

class HourlyForecastCard extends StatefulWidget {
  final List<Map<String, dynamic>> forecast;

  const HourlyForecastCard({
    required this.forecast,
    super.key,
  });

  @override
  State<HourlyForecastCard> createState() => _HourlyForecastCardState();
}

class _HourlyForecastCardState extends State<HourlyForecastCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayData = widget.forecast.take(24).toList();
    if (displayData.isEmpty) return const SizedBox();

    final temps =
        displayData.map((e) => (e['temp']?.toDouble() ?? 0.0)).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
          // Section Title
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 8),
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

          // Temperature Graph
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                // Graph
                SizedBox(
                  height: 135,
                  child: SingleChildScrollView(
                    controller: _scrollController,
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

                // Weather Icons Row
                SizedBox(
                  height: 64,
                  child: SingleChildScrollView(
                    controller: _scrollController,
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
                                  color: Colors.black.withOpacity(0.13),
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
                    controller: _scrollController,
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
                              fontWeight:
                                  isNow ? FontWeight.bold : FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }).toList(),
                    ),
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
