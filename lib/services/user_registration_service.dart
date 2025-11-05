import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class UserRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⚠️ CHANGE THIS to your actual backend URL
  static const String baseUrl = 'http://your-server-ip:8000/api';

  static const String _loginKey = 'user_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _tokenKey = 'user_token';
  static const String _phoneKey = 'user_phone';
  static const String _userIdKey = 'user_id';

  static final UserRegistrationService _instance =
      UserRegistrationService._internal();

  factory UserRegistrationService() => _instance;
  UserRegistrationService._internal();

  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';
  String _token = '';
  String _phoneNumber = '';
  String _userId = '';

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  String get token => _token;
  String get phoneNumber => _phoneNumber;
  String get userId => _userId;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _email = prefs.getString(_emailKey) ?? '';
    _token = prefs.getString(_tokenKey) ?? '';
    _phoneNumber = prefs.getString(_phoneKey) ?? '';
    _userId = prefs.getString(_userIdKey) ?? '';
  }

  String _normalizePhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('09') && phone.length == 11) {
      return '63${phone.substring(1)}';
    }

    if (phone.startsWith('63') && phone.length == 12) {
      return phone;
    }

    return phone;
  }

  /// Register user in PostgreSQL only
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    String middleName = '',
    required String lastName,
    String suffix = '',
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
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(phoneNumber.trim())) {
      return {
        'success': false,
        'error': 'Please enter a valid phone number (09XXXXXXXXX)'
      };
    }

    try {
      final normalizedPhone = phoneNumber.trim();

      // Check if phone exists
      final checkResponse = await http
          .post(
            Uri.parse('$baseUrl/users/check-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': normalizedPhone}),
          )
          .timeout(const Duration(seconds: 10));

      if (checkResponse.statusCode == 200) {
        final checkData = jsonDecode(checkResponse.body);
        if (checkData['exists'] == true) {
          return {
            'success': false,
            'error': 'Phone number already registered. Please sign in.'
          };
        }
      }

      // Register in PostgreSQL
      final registerResponse = await http
          .post(
            Uri.parse('$baseUrl/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'first_name': firstName.trim(),
              'middle_name': middleName.trim(),
              'last_name': lastName.trim(),
              'suffix': suffix.trim(),
              'house_address': houseAddress.trim(),
              'barangay': barangay.trim(),
              'phone_number': normalizedPhone,
              'role': 'resident',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (registerResponse.statusCode == 201 ||
          registerResponse.statusCode == 200) {
        final userData = jsonDecode(registerResponse.body);

        return {
          'success': true,
          'message': 'Registration successful!',
          'user': userData,
        };
      } else {
        final errorData = jsonDecode(registerResponse.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Registration failed: ${e.toString()}'
      };
    }
  }

  Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final normalizedPhone = phoneNumber.trim();

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/check-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': normalizedPhone}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] == true;
      }

      return false;
    } catch (e) {
      print('Error checking phone registration: $e');
      return false;
    }
  }

  Future<bool> loginWithPhone(String phone, {String? smsToken}) async {
    try {
      final normalizedPhone = phone.trim();

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/get-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': normalizedPhone}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['user'] != null) {
          final user = data['user'];

          _isLoggedIn = true;
          _userId = user['id'] ?? '';
          _username = '${user['first_name']} ${user['last_name']}';
          _email = user['email'] ?? '';
          _token = smsToken ?? user['id'] ?? '';
          _phoneNumber = normalizedPhone;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_loginKey, true);
          await prefs.setString(_usernameKey, _username);
          await prefs.setString(_emailKey, _email);
          await prefs.setString(_tokenKey, _token);
          await prefs.setString(_phoneKey, _phoneNumber);
          await prefs.setString(_userIdKey, _userId);

          return true;
        }
      }

      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> login(String phone, [String? smsToken]) {
    return loginWithPhone(phone, smsToken: smsToken);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    _isLoggedIn = false;
    _username = '';
    _email = '';
    _token = '';
    _phoneNumber = '';
    _userId = '';

    await prefs.remove(_loginKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_userIdKey);
  }

  /// Get user data from PostgreSQL ✅ NEW METHOD
  Future<Map<String, dynamic>?> getUserData() async {
    if (!_isLoggedIn || _phoneNumber.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/users/get-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': _phoneNumber}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['user'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}
