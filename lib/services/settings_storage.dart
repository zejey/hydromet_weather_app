import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const String notificationsKey = 'notificationsEnabled';
  static const String locationKey = 'locationEnabled';
  static const String darkModeKey = 'darkModeEnabled';
  static const String weatherAlertsKey = 'weatherAlertsEnabled';
  static const String emergencyAlertsKey = 'emergencyAlertsEnabled';
  static const String temperatureUnitKey = 'temperatureUnit';
  static const String languageKey = 'language';
  static const String alertRadiusKey = 'alertRadius';

  static Future<void> saveSettings({
    required bool notificationsEnabled,
    required bool locationEnabled,
    required bool darkModeEnabled,
    required bool weatherAlertsEnabled,
    required bool emergencyAlertsEnabled,
    required String temperatureUnit,
    required String language,
    required double alertRadius,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsKey, notificationsEnabled);
    await prefs.setBool(locationKey, locationEnabled);
    await prefs.setBool(darkModeKey, darkModeEnabled);
    await prefs.setBool(weatherAlertsKey, weatherAlertsEnabled);
    await prefs.setBool(emergencyAlertsKey, emergencyAlertsEnabled);
    await prefs.setString(temperatureUnitKey, temperatureUnit);
    await prefs.setString(languageKey, language);
    await prefs.setDouble(alertRadiusKey, alertRadius);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'notificationsEnabled': prefs.getBool(notificationsKey) ?? true,
      'locationEnabled': prefs.getBool(locationKey) ?? true,
      'darkModeEnabled': prefs.getBool(darkModeKey) ?? false,
      'weatherAlertsEnabled': prefs.getBool(weatherAlertsKey) ?? true,
      'emergencyAlertsEnabled': prefs.getBool(emergencyAlertsKey) ?? true,
      'temperatureUnit': prefs.getString(temperatureUnitKey) ?? 'Celsius',
      'language': prefs.getString(languageKey) ?? 'English',
      'alertRadius': prefs.getDouble(alertRadiusKey) ?? 5.0,
    };
  }

  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(notificationsKey);
    await prefs.remove(locationKey);
    await prefs.remove(darkModeKey);
    await prefs.remove(weatherAlertsKey);
    await prefs.remove(emergencyAlertsKey);
    await prefs.remove(temperatureUnitKey);
    await prefs.remove(languageKey);
    await prefs.remove(alertRadiusKey);
  }
}
