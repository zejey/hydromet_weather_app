import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const String _baseUrl =
      'https://caring-kindness-production.up.railway.app';

  // Poll every 5 minutes
  static const Duration _pollInterval = Duration(minutes: 5);

  final StreamController<List<Map<String, dynamic>>> _controller =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Timer? _timer;
  List<Map<String, dynamic>> _lastNotifications = [];

  /// Stream notifications for in-app display (available to ALL users)
  Stream<List<Map<String, dynamic>>> userNotificationsStream() {
    // Start polling if not already running
    _startPolling();
    return _controller.stream;
  }

  void _startPolling() {
    if (_timer != null && _timer!.isActive) return;

    // Fetch immediately on first call
    _fetchAndEmit();

    // Then poll every 5 minutes
    _timer = Timer.periodic(_pollInterval, (_) => _fetchAndEmit());
  }

  Future<void> _fetchAndEmit() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/notifications/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);

        final notifications = raw.map((n) {
          return {
            'id': n['id'] ?? '',
            'title': n['title'] ?? '',
            'body': n['message'] ?? '',
            'timestamp': n['date_time'] ?? '',
            'type': n['type'] ?? 'weather_alert',
          };
        }).toList();

        _lastNotifications = notifications;
        _controller.add(notifications);
      }
    } catch (e) {
      // On error, re-emit last known notifications so UI doesn't break
      // ignore: avoid_print
      print('NotificationService: fetch error: $e');
      if (_lastNotifications.isNotEmpty) {
        _controller.add(_lastNotifications);
      }
    }
  }

  /// Force refresh (call this when the notification bell is tapped)
  Future<void> refresh() => _fetchAndEmit();

  /// Stop polling (call this in dispose())
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  /// Check if user can receive SMS alerts (registered users only)
  Future<bool> canReceiveSMSAlerts() async {
    // SMS is handled server-side — this just returns true for UI purposes
    return true;
  }

  /// Show notification with info about SMS capability
  Future<Map<String, dynamic>> getNotificationCapabilities() async {
    return {
      'in_app': true,
      'sms': true,
      'is_guest': false,
    };
  }
}
