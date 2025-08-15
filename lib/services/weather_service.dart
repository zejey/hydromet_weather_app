import 'dart:convert';
import 'package:http/http.dart' as http;

// using hardcoded API key for testing purposes
const apiKey = '98b876bdda3ba2bbf68d26d48a26b4b9';

class WeatherService {
  // Fetch Current Weather by Coordinates
  Future<Map<String, dynamic>> fetchCurrentWeatherByCoords(double lat, double lon) async {
    final url = '$baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load current weather by coordinates');
    }
  }
  // Use this for Web version - Flutter Web
  //final String apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
  // This is for Netlify version - Flutter not supported
  //final String apiKey = EnvConfig.weatherApiKey;
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String geoUrl = 'https://api.openweathermap.org/geo/1.0/direct';

  // Fetch Current Weather
  Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
    final url = '$baseUrl/weather?q=$city&appid=$apiKey&units=metric';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load current weather');
    }
  }

  // Fetch Air Quality Data
  Future<Map<String, dynamic>> fetchAirPollution(double lat, double lon) async {
    final url = '$baseUrl/air_pollution?lat=$lat&lon=$lon&appid=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load air quality data');
    }
  }

  // Fetch Location Suggestions
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

    // Fetch 5-day / 3-hour forecast (24 hours worth of data)
    Future<List<Map<String, dynamic>>> fetchHourlyForecast(double lat, double lon) async {
      final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List forecasts = data['list'];
      
        // Take first 8 forecasts (24 hours with 3-hour intervals)
        // Then create hourly interpolated data for smooth graph
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
      
        return hourlyData;
      } else {
        throw Exception('Failed to load hourly forecast');
      }
    }
  }
