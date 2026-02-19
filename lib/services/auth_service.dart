import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Session keys
  static const String _loginKey = 'is_logged_in';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _tokenKey =
      'token'; // ✅ real token storage (JWT) if you have one
  static const String _phoneKey = 'phone_number';
  static const String _userIdKey = 'user_id';
  static const String _lastLoginKey = 'last_login_at';
  static const String _trustedPhoneKey = "trusted_device_phone";
  static const String _lastVerifiedKey = "last_otp_verified";
  static const String _emailVerifiedKey = "email_verified";
  static const String _primaryEmailKey = "primary_email";

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
  bool _emailVerified = false;
  String _primaryEmail = '';

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  String get token => _token;
  String get phoneNumber => _phoneNumber;
  String get userId => _userId;
  bool get emailVerified => _emailVerified;
  String get primaryEmail => _primaryEmail;

  Future<void> initialize() async {
    await _ensureInitialized();

    _isLoggedIn = _prefs.getBool(_loginKey) ?? false;
    _username = _prefs.getString(_usernameKey) ?? '';
    _email = _prefs.getString(_emailKey) ?? '';
    _token = _prefs.getString(_tokenKey) ?? '';
    _phoneNumber = _prefs.getString(_phoneKey) ?? '';
    _userId = _prefs.getString(_userIdKey) ?? '';
    _emailVerified = _prefs.getBool(_emailVerifiedKey) ?? false;
    _primaryEmail = _prefs.getString(_primaryEmailKey) ?? '';

    // ✅ Optional cleanup: older versions stored userId in token
    // If token looks like UUID and we already have a userId, treat it as invalid token and clear.
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (_token.isNotEmpty && uuidRegex.hasMatch(_token)) {
      // If token equals userId or just looks like UUID, clear it
      // (We don't currently use real tokens, so this is safe.)
      await _prefs.remove(_tokenKey);
      _token = '';
      print('🧹 Cleaned legacy token value (UUID stored in token key).');
    }

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

  Future<bool> isDeviceTrusted(String phoneNumber) async {
    await _ensureInitialized();

    final trustedPhone = _prefs.getString(_trustedPhoneKey);
    final lastVerified = _prefs.getInt(_lastVerifiedKey);

    if (trustedPhone != phoneNumber) {
      print('🔒 Different user - device not trusted for $phoneNumber');
      return false;
    }

    if (lastVerified == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceVerified = (now - lastVerified) / (1000 * 60 * 60 * 24);

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

  Future<void> markDeviceVerified(String phoneNumber) async {
    await _ensureInitialized();
    await _prefs.setString(_trustedPhoneKey, phoneNumber);
    await _prefs.setInt(
        _lastVerifiedKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Device marked as trusted for: $phoneNumber');
  }

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

  Future<void> clearDeviceTrust() async {
    await _ensureInitialized();
    await _prefs.remove(_trustedPhoneKey);
    await _prefs.remove(_lastVerifiedKey);
    print('🔒 Device trust cleared completely');
  }

  /// ✅ Login with user data (saves 30-day session)
  /// token is optional and should be a REAL token (JWT) if your backend issues one.
  Future<bool> loginWithUserData({
    required String userId,
    required String username,
    required String phoneNumber,
    String? email,
    bool? emailVerified,
    String? token,
  }) async {
    try {
      await _ensureInitialized();
      final now = DateTime.now().toIso8601String();

      await _prefs.setBool(_loginKey, true);
      await _prefs.setString(_usernameKey, username);
      await _prefs.setString(_emailKey, email ?? '');
      await _prefs.setString(_phoneKey, phoneNumber);
      await _prefs.setString(_userIdKey, userId);
      await _prefs.setString(_lastLoginKey, now);
      await _prefs.setBool(_emailVerifiedKey, emailVerified ?? false);
      await _prefs.setString(_primaryEmailKey, email ?? '');

      if (token != null && token.isNotEmpty) {
        await _prefs.setString(_tokenKey, token);
        _token = token;
      } else {
        await _prefs.remove(_tokenKey);
        _token = '';
      }

      _isLoggedIn = true;
      _username = username;
      _email = email ?? '';
      _phoneNumber = phoneNumber;
      _userId = userId;
      _emailVerified = emailVerified ?? false;
      _primaryEmail = email ?? '';

      final expiryDate = DateTime.parse(now).add(sessionDuration);
      print('✅ User logged in: $username ($phoneNumber)');
      print('⏰ Session valid until: $expiryDate');

      return true;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

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
      await _prefs.remove(_emailVerifiedKey);
      await _prefs.remove(_primaryEmailKey);

      _isLoggedIn = false;
      _username = '';
      _email = '';
      _token = '';
      _phoneNumber = '';
      _userId = '';
      _emailVerified = false;
      _primaryEmail = '';

      print('✅ User logged out (device trust preserved)');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  Future<bool> isSessionValid() async {
    await _ensureInitialized();
    final lastLoginStr = _prefs.getString(_lastLoginKey);

    if (lastLoginStr == null) return false;

    final lastLogin = DateTime.parse(lastLoginStr);
    final now = DateTime.now();

    return now.difference(lastLogin) <= sessionDuration;
  }

  Future<DateTime?> getSessionExpiry() async {
    await _ensureInitialized();
    final lastLoginStr = _prefs.getString(_lastLoginKey);

    if (lastLoginStr == null) return null;

    final lastLogin = DateTime.parse(lastLoginStr);
    return lastLogin.add(sessionDuration);
  }

  Future<int> getDaysUntilExpiry() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return 0;

    final now = DateTime.now();
    final difference = expiry.difference(now);

    return difference.inDays;
  }

  Future<void> updateEmailVerificationStatus({
    required bool verified,
    String? email,
  }) async {
    await _ensureInitialized();

    await _prefs.setBool(_emailVerifiedKey, verified);
    if (email != null) {
      await _prefs.setString(_primaryEmailKey, email);
      _primaryEmail = email;
    }

    _emailVerified = verified;

    print(
      '✅ Email verification status updated: verified=$verified, email=$email',
    );
  }
}

typedef AuthManager = AuthService;
