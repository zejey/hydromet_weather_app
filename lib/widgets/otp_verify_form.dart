import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/otp_api_service.dart';
import '../services/user_emails_api_service.dart';
import '../services/user_registration_service.dart';
import '../screens/email_verification_prompt_screen.dart';

typedef OtpVerifiedCallback = Future<void> Function(Map<String, dynamic> userData);

class OtpVerifyForm extends StatefulWidget {
  final String phoneNumber;

  /// If you already have an email (e.g., from registration form), pass it here.
  /// This is optional; the form can also prompt the user for an email if needed.
  final String? initialEmail;

  /// Called after OTP verification and after user data has been fetched.
  /// The parent screen decides where to navigate next.
  final OtpVerifiedCallback onVerified;

  /// Button text customization (optional)
  final String verifyButtonText;

  const OtpVerifyForm({
    super.key,
    required this.phoneNumber,
    required this.onVerified,
    this.initialEmail,
    this.verifyButtonText = 'Verify & Continue',
  });

  @override
  State<OtpVerifyForm> createState() => _OtpVerifyFormState();
}

class _OtpVerifyFormState extends State<OtpVerifyForm> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  final OtpApiService _otpService = OtpApiService();
  final AuthService _authService = AuthService();
  final UserRegistrationService _userService = UserRegistrationService();
  final UserEmailsApiService _emailService = UserEmailsApiService();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getOTPCode() => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() => _errorMessage = null);

    if (_getOTPCode().length == 6) {
      _verifyOTP();
    }
  }

  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();

    if (otpCode.length != 6) {
      setState(() => _errorMessage = 'Please enter complete OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1) Verify OTP
      final otpResult = await _otpService.verifyOtp(widget.phoneNumber, otpCode);

      if (!otpResult['success']) {
        setState(() {
          _isLoading = false;
          _errorMessage = otpResult['message'] ?? 'Invalid OTP';
        });
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        return;
      }

      // 2) Login user (no MPIN)
      final loginSuccess = await _userService.loginWithPhone(widget.phoneNumber);
      if (!loginSuccess) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed. Please try again.';
        });
        return;
      }

      // 3) Fetch user data
      final userData = await _userService.getUserData();
      if (userData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to retrieve user data.';
        });
        return;
      }

      // 4) Save session
      final emailResult = await _emailService.checkByPhone(widget.phoneNumber);

      bool emailVerified = false;
      if (emailResult['success'] && emailResult['data'] != null) {
        emailVerified = emailResult['data']['is_verified'] ?? false;
      }

      await _authService.loginWithUserData(
        userId: userData['id'] ?? '',
        username: '${userData['first_name']} ${userData['last_name']}',
        phoneNumber: widget.phoneNumber,
        email: userData['email'] ?? '',
        emailVerified: emailVerified,
      );

      await _authService.markDeviceVerified(widget.phoneNumber);

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Optional: prompt email verification (same behavior for both flows)
      if (emailResult['success'] && emailResult['data'] != null) {
        final emailData = emailResult['data'];
        final email = emailData['email'];
        final isVerified = emailData['is_verified'] ?? false;

        if (email != null && !isVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationPromptScreen(
                userId: userData['id'] ?? '',
                email: email,
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );
          return;
        }
      }

      // Parent decides what happens next
      await widget.onVerified(userData);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _resendOtpSms() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final result = await _otpService.resendOtp(widget.phoneNumber);

      setState(() => _isResending = false);

      if (result['success']) {
        _startResendTimer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to resend OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isResending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOtpEmail() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      // 1) Check existing email by phone
      final emailCheckResult = await _emailService.checkByPhone(widget.phoneNumber);

      if (!emailCheckResult['success']) {
        setState(() => _isResending = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailCheckResult['message'] ?? 'Failed to check email status',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String? emailToUse = emailCheckResult['data']?['email'];

      // 2) If no email on record, try using initialEmail first (registration flow),
      // otherwise prompt user to input one.
      if (emailToUse == null || emailToUse.isEmpty) {
        if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
          emailToUse = widget.initialEmail!.trim();
        } else {
          setState(() => _isResending = false);
          final capturedEmail = await _showEmailInputDialog();
          if (capturedEmail == null || capturedEmail.isEmpty) {
            return; // cancelled
          }
          emailToUse = capturedEmail;
        }

        // 3) Attach email to user (needs userId)
        final userData = await _userService.getUserByPhone(widget.phoneNumber);
        if (userData == null || userData['id'] == null) {
          setState(() => _isResending = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to retrieve user data'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final String userId = userData['id'].toString();

        // Re-enter resending state
        setState(() => _isResending = true);

        final addEmailResult = await _emailService.addEmail(userId, emailToUse);

        if (!addEmailResult['success']) {
          setState(() => _isResending = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(addEmailResult['message'] ?? 'Failed to attach email'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // 4) Send OTP via email
      final result = await _otpService.sendEmailOtp(widget.phoneNumber, emailToUse);

      setState(() => _isResending = false);

      if (result['success']) {
        _startResendTimer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $emailToUse'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send OTP via email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isResending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showEmailInputDialog() async {
    final TextEditingController emailController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Enter Your Email',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please enter your email address to receive the OTP code.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'example@email.com',
                      prefixIcon: const Icon(Icons.email, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setLocalState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final email = emailController.text.trim();

                    if (email.isEmpty) {
                      setLocalState(() => errorText = 'Email is required');
                      return;
                    }

                    if (!_emailRegex.hasMatch(email)) {
                      setLocalState(() => errorText = 'Please enter a valid email');
                      return;
                    }

                    Navigator.of(context).pop(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _otpInputRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 65,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green,
              height: 1.2,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              isDense: true,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _onDigitChanged(index, value),
          ),
        );
      }),
    );
  }

  Widget _resendRow() {
    final canResend = _resendCountdown == 0 && !_isResending;

    return Column(
      children: [
        // SMS resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            if (_resendCountdown > 0)
              Text(
                'Resend in $_resendCountdown s',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              TextButton(
                onPressed: canResend ? _resendOtpSms : null,
                child: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Email resend (ALWAYS visible)
        TextButton.icon(
          onPressed: canResend ? _resendOtpEmail : null,
          icon: Icon(
            Icons.email_outlined,
            size: 18,
            color: canResend ? Colors.blue : Colors.blue.withOpacity(0.35),
          ),
          label: Text(
            _resendCountdown > 0 ? 'Resend via Email in $_resendCountdown s' : 'Resend via Email',
            style: TextStyle(
              color: canResend ? Colors.blue : Colors.blue.withOpacity(0.35),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Verify Phone Number',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the 6-digit code sent to',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.phoneNumber,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 30),

        _otpInputRow(),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.verifyButtonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        _resendRow(),
      ],
    );
  }
}
