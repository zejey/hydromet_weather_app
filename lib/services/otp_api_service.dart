import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpApiService {
  // ⚠️ CHANGE THIS TO YOUR ACTUAL BACKEND URL
// For local testing (Android emulator)
  static const String baseUrl = 'http://10.0.2.2:5000/api/otp';
  
  static final OtpApiService _instance = OtpApiService._internal();
  factory OtpApiService() => _instance;
  OtpApiService._internal();

  /// Send OTP to phone number
  /// Returns: {success: bool, message: String, data: {...}}
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      // Format phone number to Philippine format (639XXXXXXXXX)
      String formattedPhone = _formatPhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': formattedPhone}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'OTP sent successfully',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
          'error': data['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP code
  /// Returns: {success: bool, message: String, data: {...}}
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      String formattedPhone = _formatPhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': formattedPhone,
          'otp_code': otpCode,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'OTP verified successfully',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid OTP',
          'error': data['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Resend OTP
  /// Returns: {success: bool, message: String, data: {...}}
  Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    try {
      String formattedPhone = _formatPhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/resend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': formattedPhone}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'OTP resent successfully',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to resend OTP',
          'error': data['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Check OTP service health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Service check completed',
        'data': data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Health check failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Format phone number to Philippine format (639XXXXXXXXX)
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // If starts with 0, replace with 63
    if (cleaned.startsWith('0')) {
      return '63${cleaned.substring(1)}';
    }
    
    // If starts with 9 and length is 10, add 63
    if (cleaned.startsWith('9') && cleaned.length == 10) {
      return '63$cleaned';
    }
    
    // If already starts with 63, return as is
    if (cleaned.startsWith('63')) {
      return cleaned;
    }

    // Default: assume it starts with 09
    return '63${cleaned.substring(1)}';
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Should be 11 digits starting with 09, or 12 digits starting with 639
    if (cleaned.length == 11 && cleaned.startsWith('09')) {
      return true;
    }
    if (cleaned.length == 12 && cleaned.startsWith('63')) {
      return true;
    }
    
    return false;
  }
}
