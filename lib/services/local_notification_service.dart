import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // ✅ iOS settings only if on iOS platform
    DarwinInitializationSettings? iosSettings;
    if (Platform.isIOS) {
      iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
    }

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print('✅ Local notifications initialized');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Show a notification immediately
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      print('⚠️ Notification permission denied');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'weather_alerts',
      'Weather Alerts',
      channelDescription: 'Notifications for weather hazards and alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4CAF50),
    );

    DarwinNotificationDetails? iosDetails;
    if (Platform.isIOS) {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );

    print('📢 Notification shown: $title');
  }

  /// Show a weather hazard notification
  Future<void> showWeatherAlert({
    required String hazardType,
    required String message,
    required String riskLevel,
  }) async {
    String emoji = _getHazardEmoji(hazardType);
    String title = '$emoji $hazardType Alert';

    await showNotification(
      title: title,
      body: message,
      payload: 'hazard:$hazardType:$riskLevel',
    );
  }

  String _getHazardEmoji(String hazardType) {
    switch (hazardType.toLowerCase()) {
      case 'tropical storm':
      case 'tropical cyclone':
        return '🌀';
      case 'flood':
      case 'flood risk':
        return '🌊';
      case 'heat wave':
      case 'extreme heat':
        return '🌡️';
      case 'thunderstorm':
        return '⛈️';
      case 'heavy rain':
        return '🌧️';
      case 'windstorm':
      case 'strong wind':
        return '💨';
      default:
        return '⚠️';
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📲 Notification tapped: ${response.payload}');
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}