import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_api_service.dart';
import 'user_registration_service.dart';

class LoginService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OtpApiService _otpApi = OtpApiService();

  static const String _loginKey = 'user_logged_in';
  static const String _usernameKey = 'username';
  static const String _tokenKey = 'user_token';
  static const String _phoneKey = 'user_phone';

  static final LoginService _instance = LoginService._internal();
  factory LoginService() => _instance;
  LoginService._internal();

  bool _isLoggedIn = false;
  String _username = '';
  String _token = '';
  String _phoneNumber = '';

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get token => _token;
  String get phoneNumber => _phoneNumber;

  /// Initialize login state from SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _token = prefs.getString(_tokenKey) ?? '';
    _phoneNumber = prefs.getString(_phoneKey) ?? '';
  }

  /// Send OTP to phone number using Python backend
  Future<Map<String, dynamic>> sendOTP(
    String phoneNumber, {
    Function(String message)? onCodeSent,
    Function(String error)? onError,
    Function()? onTimeout,
  }) async {
    try {
      // Validate phone number format
      if (!_otpApi.isValidPhoneNumber(phoneNumber)) {
        final error = 'Invalid phone number format. Please enter 11 digits starting with 09';
        onError?.call(error);
        return {'success': false, 'error': error};
      }

      // Check if user exists in Firestore first
      final userExists = await findUserByPhone(phoneNumber);
      if (userExists == null) {
        final error = 'Phone number not registered. Please register first.';
        onError?.call(error);
        return {
          'success': false,
          'error': error,
          'action': 'register'
        };
      }

      // Send OTP via Python backend
      final result = await _otpApi.sendOtp(phoneNumber);

      if (result['success']) {
        onCodeSent?.call(result['message']);
        return {
          'success': true,
          'message': result['message'],
          'data': result['data'],
        };
      } else {
        onError?.call(result['message']);
        return {
          'success': false,
          'error': result['message'],
        };
      }
    } catch (e) {
      final error = 'Failed to send OTP: ${e.toString()}';
      onError?.call(error);
      return {'success': false, 'error': error};
    }
  }

  /// Verify OTP and complete login using Python backend
  Future<Map<String, dynamic>> verifyOTP(String phoneNumber, String otpCode) async {
    try {
      // Verify OTP via Python backend
      final result = await _otpApi.verifyOtp(phoneNumber, otpCode);

      if (result['success']) {
        // OTP verification successful, now complete the login process
        return await _completeLogin(phoneNumber);
      } else {
        return {
          'success': false,
          'error': result['message'] ?? 'Invalid OTP'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'OTP verification failed: ${e.toString()}'
      };
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOTP(
    String phoneNumber, {
    Function(String message)? onCodeSent,
    Function(String error)? onError,
  }) async {
    try {
      final result = await _otpApi.resendOtp(phoneNumber);

      if (result['success']) {
        onCodeSent?.call(result['message']);
        return {
          'success': true,
          'message': result['message'],
          'data': result['data'],
        };
      } else {
        onError?.call(result['message']);
        return {
          'success': false,
          'error': result['message'],
        };
      }
    } catch (e) {
      final error = 'Failed to resend OTP: ${e.toString()}';
      onError?.call(error);
      return {'success': false, 'error': error};
    }
  }

  /// Complete login process after OTP verification
  Future<Map<String, dynamic>> _completeLogin(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return {
          'success': false,
          'error': 'User data not found. Please register first.',
          'action': 'register'
        };
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();

      // Set login state
      _isLoggedIn = true;
      _username = '${userData['first_name']} ${userData['last_name']}';
      _token = userDoc.id; // Use Firestore document ID as token
      _phoneNumber = phoneNumber.trim();

      // Save to SharedPreferences
      await _saveLoginState();

      // Sync login state with UserRegistrationService
      await UserRegistrationService().login(phoneNumber);

      return {
        'success': true,
        'message': 'Login successful!',
        'user': {
          'username': _username,
          'phone': _phoneNumber,
          'first_name': userData['first_name'],
          'last_name': userData['last_name'],
          'house_address': userData['house_address'],
          'barangay': userData['barangay'],
          'role': userData['role'],
          'doc_id': userDoc.id,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Login completion failed: ${e.toString()}'
      };
    }
  }

  /// Check if user exists by phone number
  Future<String?> findUserByPhone(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();
      return query.docs.isNotEmpty ? query.docs.first.id : null;
    } catch (e) {
      print('Error finding user by phone: $e');
      return null;
    }
  }

  /// Refresh user data from Firestore
  Future<Map<String, dynamic>> refreshUserData() async {
    if (!_isLoggedIn || _phoneNumber.isEmpty) {
      return {'success': false, 'error': 'User not logged in'};
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: _phoneNumber)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        await logout();
        return {'success': false, 'error': 'User account no longer exists'};
      }

      final userData = query.docs.first.data();
      _username = '${userData['first_name']} ${userData['last_name']}';

      await _saveLoginState();

      return {'success': true, 'user': userData};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to refresh user data: ${e.toString()}'
      };
    }
  }

  /// Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    _isLoggedIn = false;
    _username = '';
    _token = '';
    _phoneNumber = '';

    await prefs.remove(_loginKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_phoneKey);

    await UserRegistrationService().logout();
  }

  /// Save current login state to SharedPreferences
  Future<void> _saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginKey, _isLoggedIn);
    await prefs.setString(_usernameKey, _username);
    await prefs.setString(_tokenKey, _token);
    await prefs.setString(_phoneKey, _phoneNumber);
  }

  /// Check backend health
  Future<bool> checkBackendHealth() async {
    final result = await _otpApi.checkHealth();
    return result['success'] ?? false;
  }
}
