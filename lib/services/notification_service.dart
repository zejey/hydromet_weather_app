import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _apiUrl =
      'https://caring-kindness-production.up.railway.app/api/notifications/';
  static const _pollInterval = Duration(minutes: 5);

  final StreamController<List<Map<String, dynamic>>> _controller =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  List<Map<String, dynamic>> _lastNotifications = [];
  Timer? _timer;
  bool _initialized = false;

  /// Stream of notifications fetched from the backend API.
  /// Polling starts automatically on first access and repeats every 5 minutes.
  Stream<List<Map<String, dynamic>>> get notificationsStream {
    _ensurePolling();
    return _controller.stream;
  }

  void _ensurePolling() {
    if (_initialized) return;
    _initialized = true;
    _fetch();
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  /// Forces an immediate fetch from the backend.
  Future<void> refresh() async {
    _ensurePolling();
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body) as List<dynamic>;
        final notifications = data
            .map((item) => <String, dynamic>{
                  'id': item['id'] ?? '',
                  'title': item['title'] ?? '',
                  'body': item['message'] ?? '',
                  'timestamp': item['date_time'] ?? '',
                  'type': item['type'] ?? 'weather_alert',
                })
            .toList();
        _lastNotifications = notifications;
        if (!_controller.isClosed) {
          _controller.add(notifications);
        }
      } else {
        // On HTTP error, re-emit last known notifications so the UI stays intact.
        if (_lastNotifications.isNotEmpty && !_controller.isClosed) {
          _controller.add(_lastNotifications);
        }
      }
    } catch (e) {
      // On any exception, re-emit last known notifications so the UI stays intact.
      // ignore: avoid_print
      print('[NotificationService] Fetch error: $e');
      if (_lastNotifications.isNotEmpty && !_controller.isClosed) {
        _controller.add(_lastNotifications);
      }
    }
  }

  void _dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
