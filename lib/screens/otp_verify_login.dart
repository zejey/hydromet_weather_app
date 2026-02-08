import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/otp_api_service.dart';
import '../services/auth_service.dart';
import '../services/user_registration_service.dart';
import '../services/user_emails_api_service.dart';
import 'email_verification_prompt_screen.dart';

class OTPVerifyLoginScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayName;

  const OTPVerifyLoginScreen({
    super.key,
    required this.phoneNumber,
    required this.displayName,
  });

  @override
  State<OTPVerifyLoginScreen> createState() => _OTPVerifyLoginScreenState();
}

class _OTPVerifyLoginScreenState extends State<OTPVerifyLoginScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  final OtpApiService _otpService = OtpApiService();
  final AuthService _authService = AuthService();
  final UserRegistrationService _userService = UserRegistrationService();
  final UserEmailsApiService _emailService = UserEmailsApiService();

  // Email validation regex (compiled once as constant)
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
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getOTPCode() {
    return _controllers.map((c) => c.text).join();
  }

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
      print('🔍 Step 1: Verifying OTP...');

      // Step 1: Verify OTP
      final otpResult =
          await _otpService.verifyOtp(widget.phoneNumber, otpCode);

      if (!otpResult['success']) {
        setState(() {
          _isLoading = false;
          _errorMessage = otpResult['message'] ?? 'Invalid OTP';
        });
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        return;
      }

      print('✅ OTP verified successfully');

      // Step 2: Auto-login (no MPIN!)
      print('🔐 Step 2: Logging in user...');
      final loginSuccess =
          await _userService.loginWithPhone(widget.phoneNumber);

      if (!loginSuccess) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed. Please try again.';
        });
        return;
      }

      // Step 3: Get user data
      print('📊 Step 3: Fetching user data...');
      final userData = await _userService.getUserData();

      if (userData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to retrieve user data.';
        });
        return;
      }

      // Step 4: Save session (30 days)
      print('💾 Step 4: Saving session...');

      // Check email verification status
      final emailService = UserEmailsApiService();
      final emailResult = await emailService.checkByPhone(widget.phoneNumber);
      
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

      print('✅ Login complete!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Login successful! Welcome back!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        // Check if email verification prompt should be shown
        if (emailResult['success'] && emailResult['data'] != null) {
          final emailData = emailResult['data'];
          final email = emailData['email'];
          final isVerified = emailData['is_verified'] ?? false;

          if (email != null && !isVerified) {
            // Email exists but not verified - show prompt
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationPromptScreen(
                  userId: userData['id'] ?? '',
                  email: email,
                  phoneNumber: widget.phoneNumber,
                ),
              ),
            );
            return;
          }
        }

        // Navigate to weather screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/weather',
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      final result = await _otpService.resendOtp(widget.phoneNumber);

      setState(() => _isResending = false);

      if (result['success']) {
        _startResendTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP resent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to resend OTP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isResending = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

Future<void> _resendViaEmail() async {
  if (_resendCountdown > 0) return;

  setState(() => _isResending = true);

  try {
    // Step 1: Check if email exists for this phone number
    final emailCheckResult =
        await _emailService.checkByPhone(widget.phoneNumber);

    if (!emailCheckResult['success']) {
      setState(() => _isResending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailCheckResult['message'] ??
                'Failed to check email status'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final emailData = emailCheckResult['data'];
    String? emailToUse = emailData?['email'];

    // Step 2: If no email exists, prompt user to enter one and attach it
    if (emailToUse == null || emailToUse.isEmpty) {
      setState(() => _isResending = false);

      final capturedEmail = await _showEmailInputDialog();
      if (capturedEmail == null || capturedEmail.isEmpty) {
        // user cancelled
        return;
      }

      // Get userId from backend using phone number (no auth required)
      final userData = await _userService.getUserByPhone(widget.phoneNumber);

      if (userData == null || userData['id'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to retrieve user data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String userId = userData['id'];

      // Attach the email to user account (unverified)
      setState(() => _isResending = true);
      final addEmailResult = await _emailService.addEmail(userId, capturedEmail);

      if (!addEmailResult['success']) {
        setState(() => _isResending = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(addEmailResult['message'] ?? 'Failed to attach email'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      emailToUse = capturedEmail;
    }

    // Step 3: Send OTP via email
    final result =
        await _otpService.sendEmailOtp(widget.phoneNumber, emailToUse);

    setState(() => _isResending = false);

    if (result['success']) {
      _startResendTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $emailToUse'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send OTP via email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    setState(() => _isResending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          builder: (context, setState) {
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
                    onChanged: (value) {
                      if (errorText != null) {
                        setState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final email = emailController.text.trim();
                    
                    // Validate email
                    if (email.isEmpty) {
                      setState(() => errorText = 'Email is required');
                      return;
                    }
                    
                    if (!_emailRegex.hasMatch(email)) {
                      setState(() => errorText = 'Please enter a valid email');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.green,
          image: DecorationImage(
            image: AssetImage('assets/b.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Back Button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 60,
                    color: Colors.green,
                  ),
                ),

                const SizedBox(height: 30),

                // OTP Form Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
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

                      // OTP Input Fields
                      // OTP Input Fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 50, // ✅ Increased from 45 to 50
                            height: 65, // ✅ Increased from 60 to 65
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22, // ✅ Slightly reduced from 24
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                height: 1.2, // ✅ Added line height control
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  // ✅ Added explicit padding
                                  vertical: 18,
                                  horizontal: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  // ✅ Added enabled state
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                isDense:
                                    true, // ✅ Added to reduce internal padding
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) =>
                                  _onDigitChanged(index, value),
                            ),
                          );
                        }),
                      ),

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
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 20),
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

                      // Verify Button
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
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend OTP
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
                              onPressed: _isResending ? null : _resendOTP,
                              child: _isResending
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
                      
                      // Resend via Email button
                      if (_resendCountdown == 0)
                        Center(
                          child: TextButton.icon(
                            onPressed: _isResending ? null : _resendViaEmail,
                            icon: const Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: Colors.blue,
                            ),
                            label: const Text(
                              'Resend via Email',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
