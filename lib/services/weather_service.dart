import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // ✅ Use your Railway deployed backend
  static const String baseUrl = 'https://caring-kindness-production.up.railway.app/api/weather';
  
  // For local development, uncomment this:
  // static const String baseUrl = 'http://10.0.2.2:8000/api/weather'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api/weather'; // iOS simulator

  // Fetch Current Weather by Coordinates
  Future<Map<String, dynamic>> fetchCurrentWeatherByCoords(double lat, double lon) async {
    try {
      final url = '$baseUrl/current?lat=$lat&lon=$lon&units=metric';
      print('🌤️ Fetching weather from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Backend returns: { "success": true, "data": {...}, "timestamp": "..." }
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('✅ Weather data fetched successfully');
          return jsonData['data']; // Return the weather data
        } else {
          throw Exception('Invalid response format from backend');
        }
      } else {
        throw Exception('Failed to load weather: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching current weather: $e');
      rethrow;
    }
  }

  // Fetch Current Weather by City Name
  Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
    try {
      final url = '$baseUrl/current/city?city=$city&units=metric';
      print('🌤️ Fetching weather for city: $city');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('✅ Weather data for $city fetched successfully');
          return jsonData['data'];
        } else {
          throw Exception('Invalid response format from backend');
        }
      } else {
        throw Exception('Failed to load weather for city: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching weather by city: $e');
      rethrow;
    }
  }

  // Fetch Air Quality
  Future<Map<String, dynamic>> fetchAirPollution(double lat, double lon) async {
    try {
      final url = '$baseUrl/air-quality?lat=$lat&lon=$lon';
      print('🌫️ Fetching air quality data...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('✅ Air quality data fetched successfully');
          return jsonData['data'];
        } else {
          throw Exception('Invalid response format from backend');
        }
      } else {
        throw Exception('Failed to load air quality: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching air quality: $e');
      rethrow;
    }
  }

  // Fetch Location Suggestions
  Future<List<Map<String, dynamic>>> fetchLocationSuggestions(String city) async {
    try {
      final url = '$baseUrl/geocoding/search?q=$city&limit=5';
      print('🔍 Searching for location: $city');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('✅ Found ${jsonData['count']} location(s)');
          return List<Map<String, dynamic>>.from(jsonData['data']);
        } else {
          throw Exception('Invalid response format from backend');
        }
      } else {
        throw Exception('Failed to load location suggestions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching location suggestions: $e');
      rethrow;
    }
  }

  // ✅ Fetch Hourly Forecast (24 hours with interpolation)
  Future<List<Map<String, dynamic>>> fetchHourlyForecast(double lat, double lon) async {
    try {
      final url = '$baseUrl/forecast?lat=$lat&lon=$lon&units=metric&cnt=24';
      print('📅 Fetching hourly forecast...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 Forecast response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] != true || jsonData['data'] == null) {
          throw Exception('Invalid response format from backend');
        }

        final data = jsonData['data'];
        final List forecasts = data['list'];
        
        print('✅ Received ${forecasts.length} forecast points');
        
        List<Map<String, dynamic>> hourlyData = [];
        
        // Add current hour as "Now"
        if (forecasts.isNotEmpty) {
          final firstForecast = forecasts[0];
          hourlyData.add({
            'time': DateTime.now().toIso8601String(),
            'temp': firstForecast['main']['temp'],
            'icon': firstForecast['weather'][0]['icon'],
            'humidity': firstForecast['main']['humidity'],
            'wind_speed': firstForecast['wind']['speed'] ?? 0.0,
          });
        }
        
        // Generate 23 more hours of data by interpolating between 3-hour forecasts
        final available3HourForecasts = forecasts.take(8).toList();
        
        for (int hour = 1; hour <= 23; hour++) {
          final forecastIndex = (hour / 3).floor();
          final nextForecastIndex = ((hour / 3).floor() + 1).clamp(0, available3HourForecasts.length - 1);
          
          if (forecastIndex < available3HourForecasts.length) {
            final currentForecast = available3HourForecasts[forecastIndex];
            final nextForecast = available3HourForecasts[nextForecastIndex];
            
            // Interpolate temperature between forecasts
            final progress = (hour % 3) / 3.0;
            final currentTemp = currentForecast['main']['temp'].toDouble();
            final nextTemp = nextForecast['main']['temp'].toDouble();
            final interpolatedTemp = currentTemp + (nextTemp - currentTemp) * progress;
            
            // Interpolate wind speed between forecasts
            final currentWindSpeed = (currentForecast['wind']['speed'] ?? 0.0).toDouble();
            final nextWindSpeed = (nextForecast['wind']['speed'] ?? 0.0).toDouble();
            final interpolatedWindSpeed = currentWindSpeed + (nextWindSpeed - currentWindSpeed) * progress;
            
            hourlyData.add({
              'time': DateTime.now().add(Duration(hours: hour)).toIso8601String(),
              'temp': interpolatedTemp,
              'icon': currentForecast['weather'][0]['icon'],
              'humidity': currentForecast['main']['humidity'],
              'wind_speed': interpolatedWindSpeed,
            });
          }
        }
        
        print('✅ Generated ${hourlyData.length} hourly data points');
        return hourlyData;
        
      } else {
        throw Exception('Failed to load hourly forecast: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching hourly forecast: $e');
      rethrow;
    }
  }

  // ✅ Health check to verify backend connectivity
  Future<bool> checkBackendHealth() async {
    try {
      final url = '$baseUrl/health';
      print('🏥 Checking backend health...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['status'] == 'operational') {
          print('✅ Backend is healthy and operational');
          return true;
        } else {
          print('⚠️ Backend health check returned: ${jsonData['status']}');
          return false;
        }
      } else {
        print('❌ Backend health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Backend health check error: $e');
      return false;
    }
  }
}