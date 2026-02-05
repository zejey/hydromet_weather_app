import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Email Verification API Service
/// Handles email OTP sending and verification
class EmailVerificationApiService {
  /// Send email verification OTP
  ///
  /// Parameters:
  /// - userId: The user's ID
  /// - email: Email address to verify
  ///
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with OTP data
  Future<Map<String, dynamic>> send(String userId, String email) async {
    try {
      print('📧 Sending email verification OTP to: $email');

      final response = await http
          .post(
        Uri.parse(ApiConfig.emailVerificationSend),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
        }),
      )
          .timeout(
        ApiConfig.timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('📡 Send email OTP status: ${response.statusCode}');
      print('📡 Send email OTP body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Verification email sent successfully',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Failed to send verification email',
          'data': null,
        };
      }
    } on http.ClientException catch (e) {
      print('❌ Network error: ${e.message}');
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'data': null,
      };
    } catch (e) {
      print('❌ Exception: ${e.toString()}');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Verify email OTP code
  ///
  /// Parameters:
  /// - userId: The user's ID
  /// - email: Email address being verified
  /// - otpCode: 6-digit OTP code
  ///
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with verification data
  Future<Map<String, dynamic>> verify(
      String userId, String email, String otpCode) async {
    try {
      // Validate OTP code format
      if (otpCode.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otpCode)) {
        return {
          'success': false,
          'message': 'OTP must be 6 digits',
          'data': null,
        };
      }

      print('🔍 Verifying email OTP for: $email');

      final response = await http
          .post(
        Uri.parse(ApiConfig.emailVerificationVerify),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'otp_code': otpCode,
        }),
      )
          .timeout(
        ApiConfig.timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('📡 Verify email OTP status: ${response.statusCode}');
      print('📡 Verify email OTP body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Email verified successfully',
          'data': data['data'],
        };
      } else {
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
}
