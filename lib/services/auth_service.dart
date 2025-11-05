import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'user_registration_service.dart';
import 'otp_api_service.dart';

/// Unified Authentication Service
/// Handles: Login sessions, MPIN storage, OTP verification
class AuthService {
  // ===== SHARED PREFERENCES KEYS (Session Management) =====
  static const String _loginKey = 'user_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _phoneKey = 'user_phone';
  static const String _userIdKey = 'user_id';
  
  // ===== SECURE STORAGE (MPIN) =====
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final UserRegistrationService _userService = UserRegistrationService();
  final OtpApiService _otpService = OtpApiService();
  
  // ===== SINGLETON PATTERN =====
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ===== CURRENT SESSION STATE =====
  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';
  String _phoneNumber = '';
  String _userId = '';

  // ===== GETTERS =====
  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get userId => _userId;

  // ===== INITIALIZATION =====
  
  /// Initialize the service by loading saved login state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _email = prefs.getString(_emailKey) ?? '';
    _phoneNumber = prefs.getString(_phoneKey) ?? '';
    _userId = prefs.getString(_userIdKey) ?? '';
  }

  // ===== SESSION MANAGEMENT (Your existing functionality) =====
  
  /// Login method (legacy - for backwards compatibility)
  Future<bool> login(String username, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (username.isNotEmpty && email.isNotEmpty) {
        _isLoggedIn = true;
        _username = username;
        _email = email;
        
        await prefs.setBool(_loginKey, true);
        await prefs.setString(_usernameKey, username);
        await prefs.setString(_emailKey, email);
        
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Login with user data from backend
  Future<bool> loginWithUserData({
    required String userId,
    required String username,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isLoggedIn = true;
      _userId = userId;
      _username = username;
      _email = email ?? '';
      _phoneNumber = phoneNumber;
      
      await prefs.setBool(_loginKey, true);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_emailKey, _email);
      await prefs.setString(_phoneKey, phoneNumber);
      
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout method
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isLoggedIn = false;
      _username = '';
      _email = '';
      _phoneNumber = '';
      _userId = '';
      
      await prefs.remove(_loginKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_phoneKey);
      await prefs.remove(_userIdKey);
      
      // Note: We keep MPIN - user can login again with same MPIN
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Check if user is logged in
  Future<bool> checkLoginStatus() async {
    await initialize();
    return _isLoggedIn;
  }

  // ===== MPIN MANAGEMENT (New functionality) =====
  
  /// Save MPIN to secure device storage
  Future<bool> saveMPIN(String phoneNumber, String mpin) async {
    if (mpin.length != 4 || !RegExp(r'^[0-9]+$').hasMatch(mpin)) {
      return false;
    }
    
    try {
      await _secureStorage.write(
        key: 'mpin_$phoneNumber',
        value: mpin,
      );
      return true;
    } catch (e) {
      print('Error saving MPIN: $e');
      return false;
    }
  }

  /// Verify MPIN locally (no server call)
  Future<bool> verifyMPIN(String phoneNumber, String mpin) async {
    if (mpin.length != 4) return false;
    
    try {
      final storedMpin = await _secureStorage.read(key: 'mpin_$phoneNumber');
      return storedMpin == mpin;
    } catch (e) {
      print('Error verifying MPIN: $e');
      return false;
    }
  }

  /// Check if user has set MPIN
  Future<bool> hasMPIN(String phoneNumber) async {
    try {
      final mpin = await _secureStorage.read(key: 'mpin_$phoneNumber');
      return mpin != null && mpin.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear MPIN (for password reset)
  Future<void> clearMPIN(String phoneNumber) async {
    await _secureStorage.delete(key: 'mpin_$phoneNumber');
  }

  /// Clear all stored data (complete app reset)
  Future<void> clearAllData() async {
    await logout();
    await _secureStorage.deleteAll();
  }

  // ===== COMPLETE LOGIN FLOW (MPIN + OTP + Backend) =====
  
  /// Step 1: Verify MPIN and send OTP
  Future<Map<String, dynamic>> loginWithMPIN({
    required String phoneNumber,
    required String mpin,
  }) async {
    // Verify MPIN locally
    final mpinValid = await verifyMPIN(phoneNumber, mpin);
    if (!mpinValid) {
      return {
        'success': false,
        'error': 'Incorrect MPIN',
        'step': 'mpin_verification'
      };
    }

    // Send OTP to server
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final otpResult = await _otpService.sendOtp(normalizedPhone);
    
    if (!otpResult['success']) {
      return {
        'success': false,
        'error': otpResult['message'] ?? 'Failed to send OTP',
        'step': 'otp_send'
      };
    }

    return {
      'success': true,
      'message': 'MPIN verified. OTP sent to your phone.',
      'step': 'otp_verification',
      'data': otpResult['data']
    };
  }

  /// Step 2: Verify OTP and complete login
  Future<Map<String, dynamic>> verifyOTPAndLogin({
    required String phoneNumber,
    required String otpCode,
  }) async {
    // Verify OTP with server
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final otpResult = await _otpService.verifyOtp(normalizedPhone, otpCode);
    
    if (!otpResult['success']) {
      return {
        'success': false,
        'error': otpResult['message'] ?? 'Invalid OTP',
        'step': 'otp_verification'
      };
    }

    // Get user data from backend
    final loginSuccess = await _userService.loginWithPhone(phoneNumber);
    
    if (!loginSuccess) {
      return {
        'success': false,
        'error': 'Login failed. Please try again.',
        'step': 'backend_login'
      };
    }

    // Get user data
    final userData = await _userService.getUserData();
    
    if (userData != null) {
      // Save session
      await loginWithUserData(
        userId: userData['id'] ?? '',
        username: '${userData['first_name']} ${userData['last_name']}',
        phoneNumber: phoneNumber,
        email: userData['email'],
      );
      
      return {
        'success': true,
        'message': 'Login successful!',
        'step': 'complete',
        'user': userData
      };
    }

    return {
      'success': false,
      'error': 'Failed to retrieve user data',
      'step': 'backend_login'
    };
  }

  // ===== MPIN RESET (Requires OTP) =====
  
  /// Reset MPIN - requires OTP verification first
  Future<Map<String, dynamic>> resetMPIN({
    required String phoneNumber,
    required String otpCode,
    required String newMpin,
  }) async {
    if (newMpin.length != 4 || !RegExp(r'^[0-9]+$').hasMatch(newMpin)) {
      return {
        'success': false,
        'error': 'MPIN must be 4 digits'
      };
    }

    // Verify OTP first
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final otpResult = await _otpService.verifyOtp(normalizedPhone, otpCode);
    
    if (!otpResult['success']) {
      return {
        'success': false,
        'error': 'Invalid OTP'
      };
    }

    // Save new MPIN
    final saved = await saveMPIN(phoneNumber, newMpin);
    
    if (!saved) {
      return {
        'success': false,
        'error': 'Failed to save new MPIN'
      };
    }

    return {
      'success': true,
      'message': 'MPIN reset successfully'
    };
  }

  // ===== USER DATA ACCESS ===== ✅ NEW METHOD
  
  /// Get current user data from backend
  Future<Map<String, dynamic>?> getUserData() async {
    return await _userService.getUserData();
  }

  // ===== HELPER METHODS =====
  
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
}

// ===== BACKWARDS COMPATIBILITY ALIAS =====
// Keep your existing AuthManager working
typedef AuthManager = AuthService;