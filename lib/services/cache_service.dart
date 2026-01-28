import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _weatherCacheKey = 'cached_weather_data';
  static const String _airCacheKey = 'cached_air_data';
  static const String _forecastCacheKey = 'cached_forecast_data';
  static const String _lastUpdateKey = 'last_weather_update';
  
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Save weather data to cache
  Future<void> cacheWeatherData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherCacheKey, jsonEncode(data));
    await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    print('✅ Weather data cached');
  }

  /// Save air quality data to cache
  Future<void> cacheAirData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_airCacheKey, jsonEncode(data));
    print('✅ Air quality data cached');
  }

  /// Save forecast data to cache
  Future<void> cacheForecastData(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_forecastCacheKey, jsonEncode(data));
    print('✅ Forecast data cached');
  }

  /// Get cached weather data
  Future<Map<String, dynamic>?> getCachedWeatherData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_weatherCacheKey);
    
    if (cachedData != null) {
      print('📦 Loading weather from cache');
      return jsonDecode(cachedData) as Map<String, dynamic>;
    }
    
    return null;
  }

  /// Get cached air quality data
  Future<Map<String, dynamic>?> getCachedAirData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_airCacheKey);
    
    if (cachedData != null) {
      print('📦 Loading air quality from cache');
      return jsonDecode(cachedData) as Map<String, dynamic>;
    }
    
    return null;
  }

  /// Get cached forecast data
  Future<List<Map<String, dynamic>>?> getCachedForecastData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_forecastCacheKey);
    
    if (cachedData != null) {
      print('📦 Loading forecast from cache');
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.cast<Map<String, dynamic>>();
    }
    
    return null;
  }

  /// Check if cache is still valid
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString(_lastUpdateKey);
    
    if (lastUpdateStr == null) return false;
    
    final lastUpdate = DateTime.parse(lastUpdateStr);
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    
    final isValid = difference < _cacheDuration;
    print(isValid 
        ? '✅ Cache is valid (${difference.inMinutes} min old)'
        : '⏰ Cache expired (${difference.inMinutes} min old)');
    
    return isValid;
  }

  /// Get last update time
  Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString(_lastUpdateKey);
    
    if (lastUpdateStr != null) {
      return DateTime.parse(lastUpdateStr);
    }
    
    return null;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weatherCacheKey);
    await prefs.remove(_airCacheKey);
    await prefs.remove(_forecastCacheKey);
    await prefs.remove(_lastUpdateKey);
    print('🗑️ Cache cleared');
  }

  /// Check if any cache exists
  Future<bool> hasCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_weatherCacheKey);
  }
}