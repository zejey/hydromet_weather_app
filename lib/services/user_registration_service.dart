import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserRegistrationService {
  static const String _loginKey = 'user_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _tokenKey = 'user_token';

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

  final String baseUrl = 'http://10.0.2.2:8000';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _email = prefs.getString(_emailKey) ?? '';
    _token = prefs.getString(_tokenKey) ?? '';
  }

  Future<Map<String, dynamic>> registerUser({
    required String id,
    required String firstName,
    String? middleName,
    required String lastName,
    String? suffix,
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

    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id.trim(),
        'first_name': firstName.trim(),
        'middle_name': middleName?.trim(),
        'last_name': lastName.trim(),
        'suffix': suffix?.trim(),
        'house_address': houseAddress.trim(),
        'barangay': barangay.trim(),
        'phone_number': phoneNumber.trim(),
        'role': 'user',
        'is_verified': false,
      }),
    );

    print('Register response: ${response.statusCode}');
    print('Register response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message':
            'Registration successful! Please sign in to verify your account.'
      };
    } else {
      return {
        'success': false,
        'error': 'Registration failed: ${response.body}'
      };
    }
  }

  Future<bool> isPhoneRegistered(String phoneNumber) async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      final List users = jsonDecode(response.body);
      return users.any((user) => user['phone_number'] == phoneNumber.trim());
    }
    return false;
  }

  Future<bool> loginWithPhone(String phoneNumber) async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      final List users = jsonDecode(response.body);
      final user = users.firstWhere(
        (u) => u['phone_number'] == phoneNumber.trim(),
        orElse: () => null,
      );
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        _isLoggedIn = true;
        _username = '${user['first_name']} ${user['last_name']}';
        _email = user['email'] ?? '';
        _token = ''; // Optional, depends on backend

        await prefs.setBool(_loginKey, true);
        await prefs.setString(_usernameKey, _username);
        await prefs.setString(_emailKey, _email);
        await prefs.setString(_tokenKey, _token);
        return true;
      }
    }
    return false;
  }

  Future<bool> login(String phoneNumber) {
    return loginWithPhone(phoneNumber);
  }

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
}
