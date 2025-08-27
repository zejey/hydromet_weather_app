import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('notifications');

  // Stream notifications in real time, latest first
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
}
