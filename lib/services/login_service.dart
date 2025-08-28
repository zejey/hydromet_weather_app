import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_registration_service.dart'; // <-- Make sure this is imported

class LoginService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  String? _verificationId;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get token => _token;
  String get phoneNumber => _phoneNumber;
  String? get verificationId => _verificationId;

  /// Initialize login state from SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_loginKey) ?? false;
    _username = prefs.getString(_usernameKey) ?? '';
    _token = prefs.getString(_tokenKey) ?? '';
    _phoneNumber = prefs.getString(_phoneKey) ?? '';
  }

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOTP(
    String phoneNumber, {
    Function(String verificationId)? onCodeSent,
    Function(String error)? onError,
    Function()? onTimeout,
  }) async {
    try {
      // Format phone number for Firebase (ensure it starts with +63 for Philippines)
      String formattedPhone = _formatPhoneNumber(phoneNumber);

      // Check if user exists in Firestore first
      final userExists = await findUserByPhone(phoneNumber);
      if (userExists == null) {
        return {
          'success': false,
          'error': 'Phone number not registered. Please register first.',
          'action': 'register'
        };
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          try {
            await _auth.signInWithCredential(credential);
            // If successful, proceed with login
            final result = await _completeLogin(phoneNumber);
            if (result['success']) {
              // Handle auto-verification success
              print('Auto-verification successful');
            }
          } catch (e) {
            print('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = 'Verification failed';
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later';
              break;
            case 'quota-exceeded':
              errorMessage = 'SMS quota exceeded. Please try again later';
              break;
            default:
              errorMessage = e.message ?? 'Verification failed';
          }
          onError?.call(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent?.call(verificationId);
        },
        timeout: const Duration(seconds: 60),
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          onTimeout?.call();
        },
      );

      return {
        'success': true,
        'message': 'OTP sent successfully',
        'verificationId': _verificationId,
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to send OTP: ${e.toString()}'};
    }
  }

  /// Verify OTP and complete login
  Future<Map<String, dynamic>> verifyOTP(
      String phoneNumber, String otpCode) async {
    try {
      if (_verificationId == null) {
        return {
          'success': false,
          'error': 'No verification ID found. Please request OTP again.'
        };
      }

      // Create credential with verification ID and OTP code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      // Sign in with credential
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // OTP verification successful, now complete the login process
        return await _completeLogin(phoneNumber);
      } else {
        return {'success': false, 'error': 'Authentication failed'};
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Invalid OTP';
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP code. Please check and try again';
          break;
        case 'session-expired':
          errorMessage = 'OTP has expired. Please request a new one';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later';
          break;
        default:
          errorMessage = e.message ?? 'OTP verification failed';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {
        'success': false,
        'error': 'OTP verification failed: ${e.toString()}'
      };
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
      final firebaseUser = _auth.currentUser;

      // Set login state
      _isLoggedIn = true;
      _username = '${userData['first_name']} ${userData['last_name']}';
      _token = firebaseUser?.uid ?? '';
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
          'firebase_uid': firebaseUser?.uid,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Login completion failed: ${e.toString()}'
      };
    }
  }

  /// Format phone number for Firebase Auth (Philippine format)
  String _formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // If it starts with 09, replace with +639
    if (cleaned.startsWith('09')) {
      return '+63${cleaned.substring(1)}';
    }
    // If it starts with 9, add +63
    else if (cleaned.startsWith('9') && cleaned.length == 10) {
      return '+63$cleaned';
    }
    // If it already starts with 63, add +
    else if (cleaned.startsWith('63')) {
      return '+$cleaned';
    }
    // If it already starts with +63, return as is
    else if (phoneNumber.startsWith('+63')) {
      return phoneNumber;
    }

    // Default: assume it's a Philippine number starting with 09
    return '+63${cleaned.substring(1)}';
  }

  /// Login with phone number (legacy method - now redirects to OTP)
  Future<Map<String, dynamic>> loginByPhone(String phoneNumber,
      {String? smsToken}) async {
    // If smsToken is provided, verify it as OTP
    if (smsToken != null && smsToken.isNotEmpty) {
      return await verifyOTP(phoneNumber, smsToken);
    }

    // Otherwise, send OTP
    return await sendOTP(phoneNumber);
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

  /// Login with user ID (for internal use)
  Future<Map<String, dynamic>> loginUser(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return {'success': false, 'error': 'User not found'};
      }

      final userData = userDoc.data()!;

      _isLoggedIn = true;
      _username = '${userData['first_name']} ${userData['last_name']}';
      _phoneNumber = uid; // In this case, uid is the phone number

      await _saveLoginState();

      // Sync login state with UserRegistrationService
      await UserRegistrationService().login(uid);

      return {
        'success': true,
        'message': 'Login successful!',
        'user': userData
      };
    } catch (e) {
      return {'success': false, 'error': 'Login failed: ${e.toString()}'};
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
        await logout(); // User was deleted, log them out
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

    // Sign out from Firebase Auth
    await _auth.signOut();

    _isLoggedIn = false;
    _username = '';
    _token = '';
    _phoneNumber = '';
    _verificationId = null;

    await prefs.remove(_loginKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_phoneKey);

    // Sync logout state with UserRegistrationService
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

  // Legacy methods for compatibility
  @deprecated
  Future<bool> loginWithPhone(String phone, {String? smsToken}) async {
    final result = await loginByPhone(phone, smsToken: smsToken);
    return result['success'] ?? false;
  }

  @deprecated
  Future<bool> login(String phone, [String? smsToken]) {
    return loginWithPhone(phone, smsToken: smsToken);
  }
}
