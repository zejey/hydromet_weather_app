import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser({
    required String firstName,
    required String lastName,
    required String houseAddress,
    required String barangay,
    required String phoneNumber,
  }) async {
    await _firestore.collection('users').add({
      'first_name': firstName,
      'last_name': lastName,
      'house_address': houseAddress,
      'barangay': barangay,
      'phone_number': phoneNumber,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}