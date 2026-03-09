import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';
import 'connectivity_service.dart';

class WeatherService {
  // ✅ Use your Railway deployed backend
  static const String baseUrl = 'https://caring-kindness-production.up.railway.app/api/weather';
  final CacheService _cacheService = CacheService();
  final ConnectivityService _connectivityService = ConnectivityService(); 
  // For local development, uncomment this:
  // static const String baseUrl = 'http://10.0.2.2:8000/api/weather'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api/weather'; // iOS simulator

  // Fetch Current Weather by Coordinates
  Future<Map<String, dynamic>> fetchCurrentWeatherByCoords(double lat, double lon) async {
    try {
      final isOnline = await _connectivityService.isOnline();
      
      // If offline, return cached data
      if (!isOnline) {
        print('📴 Offline - loading from cache');
        final cachedData = await _cacheService.getCachedWeatherData();
        
        if (cachedData != null) {
          return cachedData;
        } else {
          throw Exception('No internet connection and no cached data available');
        }
      }
      
      // If online, fetch from API
      final url = '$baseUrl/current?lat=$lat&lon=$lon&units=metric';
      print('🌤️ Fetching weather from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('✅ Weather data fetched successfully');
          
          // Cache the data
          await _cacheService.cacheWeatherData(jsonData['data']);
          
          return jsonData['data'];
        } else {
          throw Exception('Invalid response format from backend');
        }
      } else {
        // If API fails, try cache
        print('⚠️ API request failed, trying cache...');
        final cachedData = await _cacheService.getCachedWeatherData();
        
        if (cachedData != null) {
          return cachedData;
        } else {
          throw Exception('Failed to load weather: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Error fetching current weather: $e');
      
      // Try cache as fallback
      final cachedData = await _cacheService.getCachedWeatherData();
      if (cachedData != null) {
        print('📦 Returning cached data due to error');
        return cachedData;
      }
      
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
      final isOnline = await _connectivityService.isOnline();
      
      if (!isOnline) {
        final cachedData = await _cacheService.getCachedAirData();
        if (cachedData != null) return cachedData;
        throw Exception('No internet connection');
      }
      
      final url = '$baseUrl/air-quality?lat=$lat&lon=$lon';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          await _cacheService.cacheAirData(jsonData['data']);
          return jsonData['data'];
        }
      }
      
      throw Exception('Failed to load air quality');
    } catch (e) {
      final cachedData = await _cacheService.getCachedAirData();
      if (cachedData != null) return cachedData;
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
      final isOnline = await _connectivityService.isOnline();
      
      if (!isOnline) {
        final cachedData = await _cacheService.getCachedForecastData();
        if (cachedData != null) return cachedData;
        throw Exception('No internet connection');
      }
      
      final url = '$baseUrl/forecast?lat=$lat&lon=$lon&units=metric&cnt=24';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] != true || jsonData['data'] == null) {
          throw Exception('Invalid response format from backend');
        }

        final data = jsonData['data'];
        final List forecasts = data['list'];
        
        List<Map<String, dynamic>> hourlyData = [];
        
        // Process forecast data (your existing logic)
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
        
        final available3HourForecasts = forecasts.take(8).toList();
        
        for (int hour = 1; hour <= 23; hour++) {
          final forecastIndex = (hour / 3).floor();
          final nextForecastIndex = ((hour / 3).floor() + 1).clamp(0, available3HourForecasts.length - 1);
          
          if (forecastIndex < available3HourForecasts.length) {
            final currentForecast = available3HourForecasts[forecastIndex];
            final nextForecast = available3HourForecasts[nextForecastIndex];
            
            final progress = (hour % 3) / 3.0;
            final currentTempRaw = currentForecast['main']?['temp'];
            final nextTempRaw = nextForecast['main']?['temp'];
            final currentTempConverted = currentTempRaw is num ? currentTempRaw.toDouble() : double.nan;
            final currentTemp = currentTempConverted.isFinite ? currentTempConverted : 0.0;
            final nextTempConverted = nextTempRaw is num ? nextTempRaw.toDouble() : double.nan;
            final nextTemp = nextTempConverted.isFinite ? nextTempConverted : currentTemp;
            final interpolatedTemp = currentTemp + (nextTemp - currentTemp) * progress;
            
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
        
        // Cache the data
        await _cacheService.cacheForecastData(hourlyData);
        
        return hourlyData;
      }
      
      throw Exception('Failed to load forecast');
    } catch (e) {
      final cachedData = await _cacheService.getCachedForecastData();
      if (cachedData != null) return cachedData;
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