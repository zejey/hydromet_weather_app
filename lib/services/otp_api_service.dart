import 'dart:convert';
import 'package:http/http.dart' as http;

/// OTP API Service
/// Handles OTP sending, verification, and resending via FastAPI backend
class OtpApiService {
  // ⚠️ CHANGE THIS to your actual backend URL
  static const String baseUrl = 'http://your-server-ip:8000/api/otp';
  
  // Timeout duration for API calls
  static const Duration timeout = Duration(seconds: 30);

  /// Send OTP to phone number
  /// 
  /// Parameters:
  /// - phoneNumber: Phone number in format 09XXXXXXXXX or 639XXXXXXXXX
  /// 
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with otp_id, phone_number, expires_at, validity_minutes
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': normalizedPhone,
        }),
      ).timeout(
        timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'OTP sent successfully',
          'data': data['data'],
        };
      } else {
        // Handle error responses
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Failed to send OTP',
          'data': null,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Verify OTP code
  /// 
  /// Parameters:
  /// - phoneNumber: Phone number in format 09XXXXXXXXX or 639XXXXXXXXX
  /// - otpCode: 6-digit OTP code
  /// 
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with otp_id, phone_number, verified_at
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // Validate OTP code format
      if (otpCode.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otpCode)) {
        return {
          'success': false,
          'message': 'OTP must be 6 digits',
          'data': null,
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': normalizedPhone,
          'otp_code': otpCode,
        }),
      ).timeout(
        timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'OTP verified successfully',
          'data': data['data'],
        };
      } else {
        // Handle error responses (wrong OTP, expired, etc.)
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Invalid OTP code',
          'data': null,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Resend OTP to phone number
  /// 
  /// Parameters:
  /// - phoneNumber: Phone number in format 09XXXXXXXXX or 639XXXXXXXXX
  /// 
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with otp_id, phone_number, expires_at, validity_minutes
  Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);

      final response = await http.post(
        Uri.parse('$baseUrl/resend'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': normalizedPhone,
        }),
      ).timeout(
        timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'OTP resent successfully',
          'data': data['data'],
        };
      } else {
        // Handle error responses (rate limit, etc.)
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Failed to resend OTP',
          'data': null,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Check OTP service health
  /// 
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with service info
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(
        timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'OTP service is running',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'OTP service unavailable',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to OTP service',
        'data': null,
      };
    }
  }

  // ===== HELPER METHODS =====

  /// Normalize phone number to consistent format
  /// Converts: 09XXXXXXXXX, 639XXXXXXXXX, +639XXXXXXXXX
  /// 
  /// For backend API calls, we send 639XXXXXXXXX format
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Convert 09XXXXXXXXX to 639XXXXXXXXX
    if (phone.startsWith('09') && phone.length == 11) {
      return '63${phone.substring(1)}';
    }
    
    // Already in 639XXXXXXXXX format
    if (phone.startsWith('63') && phone.length == 12) {
      return phone;
    }
    
    // If starts with 9 and length is 10, add 63
    if (phone.startsWith('9') && phone.length == 10) {
      return '63$phone';
    }
    
    // Return as is if format is unexpected
    return phone;
  }

  /// Format phone number for display (09XXXXXXXXX format)
  String formatPhoneForDisplay(String phone) {
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Convert 639XXXXXXXXX to 09XXXXXXXXX
    if (phone.startsWith('63') && phone.length == 12) {
      return '0${phone.substring(2)}';
    }
    
    // Already in 09XXXXXXXXX format
    if (phone.startsWith('09') && phone.length == 11) {
      return phone;
    }
    
    return phone;
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check if it's 09XXXXXXXXX (11 digits)
    if (phone.startsWith('09') && phone.length == 11) {
      return true;
    }
    
    // Check if it's 639XXXXXXXXX (12 digits)
    if (phone.startsWith('63') && phone.length == 12) {
      return true;
    }
    
    return false;
  }
}