import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Session keys
  static const String _loginKey = 'is_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _tokenKey = 'token';
  static const String _phoneKey = 'phone_number';
  static const String _userIdKey = 'user_id';
  static const String _lastLoginKey = 'last_login_at';
  static const String _trustedPhoneKey = "trusted_device_phone";
  static const String _lastVerifiedKey = "last_otp_verified";

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Session duration: 30 days
  static const Duration sessionDuration = Duration(days: 30);

  // Session state
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

  /// Initialize - Load session from storage
  /// Initialize - Load session from storage
  Future<void> initialize() async {
    await _ensureInitialized(); // ✅ Use the new method

    _isLoggedIn = _prefs.getBool(_loginKey) ?? false;
    _username = _prefs.getString(_usernameKey) ?? '';
    _email = _prefs.getString(_emailKey) ?? '';
    _token = _prefs.getString(_tokenKey) ?? '';
    _phoneNumber = _prefs.getString(_phoneKey) ?? '';
    _userId = _prefs.getString(_userIdKey) ?? '';

    // Check if session expired (30 days)
    final lastLoginStr = _prefs.getString(_lastLoginKey);
    if (lastLoginStr != null && _isLoggedIn) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final now = DateTime.now();

      if (now.difference(lastLogin) > sessionDuration) {
        print('⏰ Session expired (> 30 days) - logging out');
        await logout();
      } else {
        final daysLeft =
            sessionDuration.inDays - now.difference(lastLogin).inDays;
        print('✅ Session valid - expires in $daysLeft days');
      }
    }

    print('🔍 Auth initialized - Logged in: $_isLoggedIn');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Check if current device is trusted for this specific phone number
  Future<bool> isDeviceTrusted(String phoneNumber) async {
    await _ensureInitialized();

    final trustedPhone = _prefs.getString(_trustedPhoneKey);
    final lastVerified = _prefs.getInt(_lastVerifiedKey);

    // Check if phone number matches
    if (trustedPhone != phoneNumber) {
      print('🔒 Different user - device not trusted for $phoneNumber');
      return false;
    }

    if (lastVerified == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceVerified = (now - lastVerified) / (1000 * 60 * 60 * 24);

    // Trust device for 30 days after last OTP verification
    if (daysSinceVerified < 30) {
      print(
          '✅ Device is trusted for $phoneNumber (verified ${daysSinceVerified.toStringAsFixed(1)} days ago)');
      return true;
    } else {
      print(
          '⏰ Device trust expired for $phoneNumber (${daysSinceVerified.toStringAsFixed(1)} days old)');
      return false;
    }
  }

  /// Mark this device as trusted for a specific phone number
  Future<void> markDeviceVerified(String phoneNumber) async {
    await _ensureInitialized();
    await _prefs.setString(_trustedPhoneKey, phoneNumber);
    await _prefs.setInt(
        _lastVerifiedKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Device marked as trusted for: $phoneNumber');
  }

  /// Clear device trust ONLY if different user is logging in
  Future<void> clearDeviceTrustIfDifferentUser(String newPhoneNumber) async {
    await _ensureInitialized();
    final trustedPhone = _prefs.getString(_trustedPhoneKey);

    if (trustedPhone != null && trustedPhone != newPhoneNumber) {
      print('🔄 Different user detected - clearing device trust');
      print('   Previous: $trustedPhone');
      print('   New: $newPhoneNumber');
      await _prefs.remove(_trustedPhoneKey);
      await _prefs.remove(_lastVerifiedKey);
    }
  }

  /// Clear device trust completely (optional - for security settings)
  Future<void> clearDeviceTrust() async {
    await _ensureInitialized();
    await _prefs.remove(_trustedPhoneKey);
    await _prefs.remove(_lastVerifiedKey);
    print('🔒 Device trust cleared completely');
  }

  /// Login with user data (saves 30-day session)
  /// Login with user data (saves 30-day session)
  Future<bool> loginWithUserData({
    required String userId,
    required String username,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      await _ensureInitialized(); // ✅ Use the new method
      final now = DateTime.now().toIso8601String();

      await _prefs.setBool(_loginKey, true);
      await _prefs.setString(_usernameKey, username);
      await _prefs.setString(_emailKey, email ?? '');
      await _prefs.setString(_tokenKey, userId);
      await _prefs.setString(_phoneKey, phoneNumber);
      await _prefs.setString(_userIdKey, userId);
      await _prefs.setString(_lastLoginKey, now);

      _isLoggedIn = true;
      _username = username;
      _email = email ?? '';
      _token = userId;
      _phoneNumber = phoneNumber;
      _userId = userId;

      final expiryDate = DateTime.parse(now).add(sessionDuration);
      print('✅ User logged in: $username ($phoneNumber)');
      print('⏰ Session valid until: $expiryDate');

      return true;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  /// Logout - Clear session
  /// Logout - Clear session (but preserve device trust for same user)
  Future<void> logout() async {
    try {
      await _ensureInitialized();

      await _prefs.remove(_loginKey);
      await _prefs.remove(_usernameKey);
      await _prefs.remove(_emailKey);
      await _prefs.remove(_tokenKey);
      await _prefs.remove(_phoneKey);
      await _prefs.remove(_userIdKey);
      await _prefs.remove(_lastLoginKey);

      // Note: We DON'T clear device trust here!
      // Device trust persists for the same user

      _isLoggedIn = false;
      _username = '';
      _email = '';
      _token = '';
      _phoneNumber = '';
      _userId = '';

      print('✅ User logged out (device trust preserved)');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// Check if session is still valid
  /// Check if session is still valid
  Future<bool> isSessionValid() async {
    await _ensureInitialized();
    final lastLoginStr = _prefs.getString(_lastLoginKey);

    if (lastLoginStr == null) return false;

    final lastLogin = DateTime.parse(lastLoginStr);
    final now = DateTime.now();

    return now.difference(lastLogin) <= sessionDuration;
  }

  /// Get session expiry date
  Future<DateTime?> getSessionExpiry() async {
    await _ensureInitialized();
    final lastLoginStr = _prefs.getString(_lastLoginKey);

    if (lastLoginStr == null) return null;

    final lastLogin = DateTime.parse(lastLoginStr);
    return lastLogin.add(sessionDuration);
  }

  /// Get days until session expires
  Future<int> getDaysUntilExpiry() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return 0;

    final now = DateTime.now();
    final difference = expiry.difference(now);

    return difference.inDays;
  }
}

// Backwards compatibility alias
typedef AuthManager = AuthService;
