import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _loginKey = 'user_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _tokenKey = 'user_token';
  static const String _usersKey = 'registered_users';

  static final UserRegistrationService _instance =
      UserRegistrationService._internal();

  factory UserRegistrationService() => _instance;
  UserRegistrationService._internal();

  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';
  String _token = '';

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  String get token => _token;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _email = prefs.getString(_emailKey) ?? '';
    _token = prefs.getString(_tokenKey) ?? '';
  }

  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String houseAddress,
    required String barangay,
    required String phoneNumber,
  }) async {
    // Input validation
    if (firstName.trim().isEmpty) {
      return {'success': false, 'error': 'Please enter your first name'};
    }
    if (lastName.trim().isEmpty) {
      return {'success': false, 'error': 'Please enter your last name'};
    }
    if (houseAddress.trim().isEmpty) {
      return {'success': false, 'error': 'Please enter your house address'};
    }
    if (phoneNumber.trim().isEmpty) {
      return {'success': false, 'error': 'Please enter your phone number'};
    }
    if (phoneNumber.trim().length < 10) {
      return {'success': false, 'error': 'Please enter a valid phone number'};
    }

    try {
      final docRef = _firestore.collection('users').doc(phoneNumber.trim());

      // Check if phone number already exists
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        return {
          'success': false,
          'error': 'Phone number already registered. Please sign in.'
        };
      }

      // Create new user document
      await docRef.set({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'house_address': houseAddress.trim(),
        'barangay': barangay.trim(),
        'phone_number': phoneNumber.trim(),
        'role': 'user',
        'created_at': FieldValue.serverTimestamp(),
        'is_verified': false, // For future OTP verification
      });

      return {
        'success': true,
        'message':
            'Registration successful! Please sign in to verify your account.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Registration failed: ${e.toString()}'
      };
    }
  }

  Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(phoneNumber.trim()).get();
      return docSnapshot.exists;
    } catch (e) {
      print('Error checking phone registration: $e');
      return false;
    }
  }

  // Register a new user
  // Future<bool> registerUser({
  //   required String firstName,
  //   required String lastName,
  //   required String phone,
  //   String email = '',
  //   String token = '',
  // }) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   List<Map<String, dynamic>> users = await _getRegisteredUsers();

  //   // Check phone uniqueness
  //   if (users.any((user) => user['phone'] == phone)) {
  //     return false;
  //   }

  //   users.add({
  //     'first_name': firstName,
  //     'last_name': lastName,
  //     'phone': phone,
  //     'email': email,
  //     'token': token,
  //   });
  //   await prefs.setString(_usersKey, jsonEncode(users));
  //   return true;
  // }

  // Check if phone is already registered
  // Future<bool> isPhoneRegistered(String phone) async {
  //   List<Map<String, dynamic>> users = await _getRegisteredUsers();
  //   return users.any((user) => user['phone'] == phone);
  // }

  // Login by phone (and optionally, token)
  Future<bool> loginWithPhone(String phone, {String? smsToken}) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _getRegisteredUsers();
    final user = users.firstWhere((u) => u['phone'] == phone, orElse: () => {});
    if (user.isNotEmpty) {
      _isLoggedIn = true;
      _username = '${user['first_name']} ${user['last_name']}';
      _email = user['email'] ?? '';
      _token = smsToken ?? user['token'] ?? '';

      await prefs.setBool(_loginKey, true);
      await prefs.setString(_usernameKey, _username);
      await prefs.setString(_emailKey, _email);
      await prefs.setString(_tokenKey, _token);
      return true;
    }
    return false;
  }

  // Alias for loginWithPhone for compatibility
  Future<bool> login(String phone, [String? smsToken]) {
    return loginWithPhone(phone, smsToken: smsToken);
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = false;
    _username = '';
    _email = '';
    _token = '';
    await prefs.remove(_loginKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_tokenKey);
  }

  // Internal: load users list
  Future<List<Map<String, dynamic>>> _getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      List<dynamic> decoded = jsonDecode(usersJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
