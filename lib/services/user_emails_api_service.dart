import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// User Emails API Service
/// Handles email attachment and management for users
class UserEmailsApiService {
  /// Add email to user account
  ///
  /// Parameters:
  /// - userId: The user's ID
  /// - email: Email address to attach
  ///
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with email data
  Future<Map<String, dynamic>> addEmail(String userId, String email) async {
    try {
      print('📧 Adding email to user $userId: $email');

      final response = await http
          .post(
        Uri.parse('${ApiConfig.userEmailsBase}/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'is_primary': true,
        }),
      )
          .timeout(
        ApiConfig.timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('📡 Add email status: ${response.statusCode}');
      print('📡 Add email body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Email added successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['message'] ?? 'Failed to add email',
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

  /// Check user email status by phone number
  ///
  /// Parameters:
  /// - phone: Phone number to check
  ///
  /// Returns:
  /// - success: bool
  /// - message: String
  /// - data: Map with email status (email, is_verified, is_primary)
  Future<Map<String, dynamic>> checkByPhone(String phone) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phone);
      print('📱 Checking email for phone: $normalizedPhone');

      final response = await http
          .get(
        Uri.parse('${ApiConfig.userEmailsBase}/check-phone/$normalizedPhone'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(
        ApiConfig.timeout,
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('📡 Check email status: ${response.statusCode}');
      print('📡 Check email body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Email status retrieved',
          'data': data,
        };
      } else if (response.statusCode == 404) {
        return {
          'success': true,
          'message': 'No email found',
          'data': {'email': null, 'is_verified': false, 'is_primary': false},
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to check email',
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

  /// Normalize phone number to 639XXXXXXXXX format
  String _normalizePhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('09') && phone.length == 11) {
      return '63${phone.substring(1)}';
    }

    if (phone.startsWith('63') && phone.length == 12) {
      return phone;
    }

    if (phone.startsWith('9') && phone.length == 10) {
      return '63$phone';
    }

    return phone;
  }
}
