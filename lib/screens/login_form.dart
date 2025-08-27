import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weather_hybrid_app/services/auth_service.dart';
import '../services/user_registration_service.dart';
import '../services/login_service.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _smsCodeFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isResendingCode = false;
  bool _isOtpSent = false;
  String _verificationId = '';
  int _resendTimer = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    _phoneFocusNode.dispose();
    _smsCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();

    // Validate phone number
    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number', isError: true);
      return;
    }
    if (phone.length != 11) {
      _showSnackBar('Phone number must be exactly 11 digits', isError: true);
      return;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      _showSnackBar('Phone number must contain only digits', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await LoginService().sendOTP(
        phone,
        onCodeSent: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isLoading = false;
          });
          _startResendTimer();
          _showSnackBar('OTP sent successfully!');
          // Focus on SMS code field
          Future.delayed(const Duration(milliseconds: 100), () {
            _smsCodeFocusNode.requestFocus();
          });
        },
        onError: (error) {
          setState(() => _isLoading = false);
          _showSnackBar(error, isError: true);
        },
        onTimeout: () {
          setState(() => _isLoading = false);
          _showSnackBar('Request timed out. Please try again.', isError: true);
        },
      );

      if (!result['success'] && result['action'] == 'register') {
        setState(() => _isLoading = false);
        _showRegisterDialog();
      } else if (!result['success']) {
        setState(() => _isLoading = false);
        _showSnackBar(result['error'] ?? 'Failed to send OTP', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to send OTP: ${e.toString()}', isError: true);
    }
  }

  Future<void> _verifyOTP() async {
    final phone = _phoneController.text.trim();
    final code = _smsCodeController.text.trim();

    // Validate SMS code
    if (code.isEmpty) {
      _showSnackBar('Please enter the SMS code', isError: true);
      return;
    }
    if (code.length != 6) {
      _showSnackBar('Please enter a valid 6-digit SMS code', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await LoginService().verifyOTP(phone, code);

      setState(() => _isLoading = false);

      if (result['success'] && mounted) {
        _showSnackBar('Login successful!');
        await UserRegistrationService().login(phone);
        await AuthManager().initialize();
        Navigator.pushNamedAndRemoveUntil(
            context, '/weather', (route) => false);
      } else {
        _showSnackBar(result['error'] ?? 'OTP verification failed',
            isError: true);
        // Clear the SMS code field on error
        _smsCodeController.clear();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Verification failed: ${e.toString()}', isError: true);
      _smsCodeController.clear();
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() => _isResendingCode = true);

    try {
      final result = await LoginService().sendOTP(
        _phoneController.text.trim(),
        onCodeSent: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isResendingCode = false;
          });
          _startResendTimer();
          _showSnackBar('OTP resent successfully!');
        },
        onError: (error) {
          setState(() => _isResendingCode = false);
          _showSnackBar(error, isError: true);
        },
        onTimeout: () {
          setState(() => _isResendingCode = false);
          _showSnackBar('Request timed out. Please try again.', isError: true);
        },
      );

      if (!result['success']) {
        setState(() => _isResendingCode = false);
        _showSnackBar(result['error'] ?? 'Failed to resend OTP', isError: true);
      }
    } catch (e) {
      setState(() => _isResendingCode = false);
      _showSnackBar('Failed to resend OTP: ${e.toString()}', isError: true);
    }
  }

  void _startResendTimer() {
    setState(() => _resendTimer = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _resendTimer--);
        return _resendTimer > 0;
      }
      return false;
    });
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Phone Not Registered'),
          content: const Text(
            'This phone number is not registered. Would you like to register now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/register');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _changePhoneNumber() {
    setState(() {
      _isOtpSent = false;
      _smsCodeController.clear();
      _resendTimer = 0;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _phoneFocusNode.requestFocus();
    });
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Text(
                      _isOtpSent ? 'Verify OTP' : 'Sign In',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Transform.rotate(
                      angle: -1.5708,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Text(
                                'HYDROMET',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isOtpSent ? 'Verify Your Phone' : 'Welcome!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOtpSent
                            ? 'Enter the 6-digit code sent to ${_phoneController.text}'
                            : 'Enter your details to continue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Phone Number Field
                      TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        enabled: !_isOtpSent,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter your 11-digit phone number',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.green, width: 2),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          prefixIcon:
                              const Icon(Icons.phone, color: Colors.green),
                          counterText: '',
                          suffixIcon: _isOtpSent
                              ? IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.green),
                                  onPressed: _changePhoneNumber,
                                  tooltip: 'Change phone number',
                                )
                              : null,
                        ),
                      ),

                      if (_isOtpSent) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _smsCodeController,
                          focusNode: _smsCodeFocusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter 6-digit OTP code',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.green, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            prefixIcon:
                                const Icon(Icons.sms, color: Colors.green),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: (_isResendingCode || _resendTimer > 0)
                                  ? null
                                  : _resendCode,
                              child: _isResendingCode
                                  ? const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.green,
                                      ),
                                    )
                                  : Text(
                                      _resendTimer > 0
                                          ? 'Resend in ${_resendTimer}s'
                                          : 'Resend OTP',
                                      style: TextStyle(
                                        color: (_resendTimer > 0)
                                            ? Colors.grey
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_isOtpSent ? _verifyOTP : _sendOTP),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
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
                                _isOtpSent ? 'Verify OTP' : 'Send OTP',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Not registered yet? ',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'Register here',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
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
