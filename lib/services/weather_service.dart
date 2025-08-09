import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // 🆕 ADD THIS IMPORT for Color class

const apiKey = '98b876bdda3ba2bbf68d26d48a26b4b9';

class WeatherService {
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String geoUrl = 'https://api.openweathermap.org/geo/1.0/direct';

  // Your local REST API URL
  final String localApiUrl =
      'http://10.0.2.2:5000'; // Change to your server IP for mobile

  // Existing OpenWeatherMap methods...
  Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
    final url = '$baseUrl/weather?q=$city&appid=$apiKey&units=metric';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load current weather');
    }
  }

  Future<Map<String, dynamic>> fetchAirPollution(double lat, double lon) async {
    final url = '$baseUrl/air_pollution?lat=$lat&lon=$lon&appid=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load air quality data');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLocationSuggestions(
      String city) async {
    final url = '$geoUrl?q=$city&limit=5&appid=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to load location suggestions');
    }
  }

  Future<Map<String, dynamic>> fetchWeatherByCoords(
      double lat, double lon) async {
    final url = '$baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load weather by coordinates');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHourlyForecast(
      double lat, double lon) async {
    final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List forecasts = data['list'];
      return forecasts
          .take(8)
          .map<Map<String, dynamic>>((item) => {
                'time': item['dt_txt'],
                'temp': item['main']['temp'],
                'icon': item['weather'][0]['icon'],
                'humidity': item['main']['humidity'],
              })
          .toList();
    } else {
      throw Exception('Failed to load hourly forecast');
    }
  }

  // 🆕 NEW: Hazard Prediction Methods

  /// Check if local API is available
  Future<bool> checkLocalApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$localApiUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5)); // Add timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Local API not available: $e');
      return false;
    }
  }

  /// Get current hazard level prediction
  Future<Map<String, dynamic>?> fetchHazardPrediction(
      Map<String, dynamic> weatherData) async {
    try {
      // Convert OpenWeatherMap data to your API format
      final requestData = {
        'date': DateTime.now().toIso8601String().substring(0, 10), // YYYY-MM-DD
        'tavg': weatherData['main']['temp'].toDouble(),
        'tmin': weatherData['main']['temp_min']?.toDouble() ??
            weatherData['main']['temp'].toDouble() - 5,
        'tmax': weatherData['main']['temp_max']?.toDouble() ??
            weatherData['main']['temp'].toDouble() + 5,
        'prcp': _getPrecipitation(weatherData),
        'wspd': _convertWindSpeed(
            weatherData['wind']['speed']), // Convert m/s to km/h
        'pres': weatherData['main']['pressure'].toDouble(),
        'wdir': weatherData['wind']['deg']?.toDouble() ?? 180.0,
        'wpgt': _getWindGust(weatherData),
      };

      print('Sending hazard prediction request: $requestData'); // Debug log

      final response = await http
          .post(
            Uri.parse('$localApiUrl/predict/single'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('Hazard prediction response: $result'); // Debug log
        return result;
      } else {
        print(
            'Hazard prediction failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching hazard prediction: $e');
      return null;
    }
  }

  /// Get 7-day hazard forecast
  Future<Map<String, dynamic>?> fetchHazardForecast(
      Map<String, dynamic> currentWeather) async {
    try {
      final requestData = {
        'days_ahead': 7,
        'current_weather': {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'tavg': currentWeather['main']['temp'].toDouble(),
          'tmin': currentWeather['main']['temp_min']?.toDouble() ??
              currentWeather['main']['temp'].toDouble() - 5,
          'tmax': currentWeather['main']['temp_max']?.toDouble() ??
              currentWeather['main']['temp'].toDouble() + 5,
          'prcp': _getPrecipitation(currentWeather),
          'wspd': _convertWindSpeed(currentWeather['wind']['speed']),
          'pres': currentWeather['main']['pressure'].toDouble(),
          'wdir': currentWeather['wind']['deg']?.toDouble() ?? 180.0,
          'wpgt': _getWindGust(currentWeather),
        }
      };

      print('Sending hazard forecast request: $requestData'); // Debug log

      final response = await http
          .post(
            Uri.parse('$localApiUrl/predict/forecast'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('Hazard forecast response received'); // Debug log
        return result;
      } else {
        print(
            'Hazard forecast failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching hazard forecast: $e');
      return null;
    }
  }

  /// Train model with local data (admin function)
  Future<Map<String, dynamic>?> trainModel(String csvFilePath) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$localApiUrl/train'));
      request.files.add(await http.MultipartFile.fromPath('file', csvFilePath));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        print('Model training failed: $responseData');
        return null;
      }
    } catch (e) {
      print('Error training model: $e');
      return null;
    }
  }

  // Helper methods for data conversion
  double _getPrecipitation(Map<String, dynamic> weatherData) {
    if (weatherData.containsKey('rain')) {
      return weatherData['rain']['1h']?.toDouble() ?? 0.0;
    } else if (weatherData.containsKey('snow')) {
      return weatherData['snow']['1h']?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  double _convertWindSpeed(double windSpeedMs) {
    // Convert m/s to km/h
    return windSpeedMs * 3.6;
  }

  double _getWindGust(Map<String, dynamic> weatherData) {
    if (weatherData['wind']?.containsKey('gust') == true) {
      return _convertWindSpeed(weatherData['wind']['gust'].toDouble());
    }
    // If no gust data, estimate as 1.5x wind speed
    return _convertWindSpeed(weatherData['wind']['speed'].toDouble()) * 1.5;
  }

  // Get hazard level color
  Color getHazardColor(int hazardLevel) {
    switch (hazardLevel) {
      case 0:
        return Colors.green; // No Risk
      case 1:
        return Colors.yellow; // Low Risk
      case 2:
        return Colors.orange; // Moderate Risk
      case 3:
        return Colors.red; // High Risk
      case 4:
        return Colors.purple; // Extreme Risk
      default:
        return Colors.grey;
    }
  }

  // Get hazard level description
  String getHazardDescription(int hazardLevel) {
    switch (hazardLevel) {
      case 0:
        return 'No Risk';
      case 1:
        return 'Low Risk';
      case 2:
        return 'Moderate Risk';
      case 3:
        return 'High Risk';
      case 4:
        return 'Extreme Risk';
      default:
        return 'Unknown';
    }
  }

  // Get hazard level icon
  IconData getHazardIcon(int hazardLevel) {
    switch (hazardLevel) {
      case 0:
        return Icons.check_circle;
      case 1:
        return Icons.info;
      case 2:
        return Icons.warning_amber;
      case 3:
        return Icons.warning;
      case 4:
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  // Get risk factors text
  String getHazardRiskFactors(Map<String, dynamic>? hazardData) {
    if (hazardData == null) return 'No risk factors available';

    // You can customize this based on your API response structure
    final riskFactors = hazardData['risk_factors'] as List<dynamic>?;
    if (riskFactors != null && riskFactors.isNotEmpty) {
      return riskFactors.join(', ');
    }

    return 'Standard weather monitoring recommended';
  }
}
