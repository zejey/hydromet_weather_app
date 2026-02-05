/// API Configuration
/// Centralized API base URL and endpoints for the HydroMet Weather App
class ApiConfig {
  // Base API URL
  static const String baseUrl =
      'https://caring-kindness-production.up.railway.app/api';

  // OTP endpoints
  static const String otpBase = '$baseUrl/otp';
  static const String otpSend = '$otpBase/send';
  static const String otpResend = '$otpBase/resend';
  static const String otpVerify = '$otpBase/verify';
  static const String otpSendRegistration = '$otpBase/send-registration';
  static const String otpSendEmail = '$otpBase/send-email';

  // User endpoints
  static const String usersBase = '$baseUrl/users';
  static const String usersCreate = '$usersBase/';
  static const String usersCheckUser = '$usersBase/check-user';
  static const String usersGetUser = '$usersBase/get-user';

  // User emails endpoints
  static const String userEmailsBase = '$baseUrl/user-emails';

  // Email verification endpoints
  static const String emailVerificationBase = '$baseUrl/email-verification';
  static const String emailVerificationSend = '$emailVerificationBase/send';
  static const String emailVerificationVerify = '$emailVerificationBase/verify';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
}
