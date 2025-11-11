import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('notifications');
  final AuthService _authService = AuthService();

  /// Stream notifications for in-app display (available to ALL users)
  Stream<List<Map<String, dynamic>>> userNotificationsStream() {
    return _collection
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'title': data['title'] ?? '',
                'body': data['message'] ?? '',
                'timestamp':
                    (data['dateTime'] as Timestamp).toDate().toString(),
                'type': data['type'] ?? 'Info',
              };
            }).toList());
  }

  /// Check if user can receive SMS alerts (registered users only)
  Future<bool> canReceiveSMSAlerts() async {
    await _authService.initialize();
    final isRegistered = _authService.isLoggedIn;

    print(isRegistered
        ? '✅ User registered - SMS alerts enabled for ${_authService.phoneNumber}'
        : '❌ Guest mode - SMS alerts disabled');

    return isRegistered;
  }

  /// Show notification with info about SMS capability
  Future<Map<String, dynamic>> getNotificationCapabilities() async {
    await _authService.initialize();

    return {
      'in_app': true, // Always available
      'sms': _authService.isLoggedIn, // Only for registered users
      'phone_number': _authService.phoneNumber,
      'is_guest': !_authService.isLoggedIn,
    };
  }
}
