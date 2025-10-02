
import 'package:flutter/material.dart';
import '../services/auth_service.dart';


class LoginMPINScreen extends StatefulWidget {
  @override
  State<LoginMPINScreen> createState() => _LoginMPINScreenState();
}

class _LoginMPINScreenState extends State<LoginMPINScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpinController = TextEditingController();
  bool _isLoading = false;
  String? _phoneErrorText;
  String? _mpinErrorText;

  void _verifyMPIN() async {
    final phone = _phoneController.text.trim();
    final mpin = _mpinController.text.trim();

    bool hasError = false;
    setState(() {
      _phoneErrorText = null;
      _mpinErrorText = null;
    });
    if (phone.isEmpty || phone.length != 11) {
      setState(() => _phoneErrorText = 'Please enter a valid 11-digit phone number');
      hasError = true;
    }
    if (mpin.isEmpty || mpin.length != 4) {
      setState(() => _mpinErrorText = 'MPIN must be exactly 4 digits');
      hasError = true;
    } else if (!RegExp(r'^[0-9]+$').hasMatch(mpin)) {
      setState(() => _mpinErrorText = 'MPIN must contain only digits');
      hasError = true;
    }
    if (hasError) return;
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    // TODO: Replace with your actual MPIN verification logic
    if (mpin == "1234") {
      // Set login/session flag using AuthManager
      final authManager = AuthManager();
      await authManager.login(phone, phone); // Using phone as username/email for now
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MPIN Verified!'), backgroundColor: Colors.green),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/weather', (route) => false);
    } else {
      setState(() => _mpinErrorText = 'Incorrect MPIN');
    }
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
                    const Text(
                      'MPIN Login',
                      style: TextStyle(
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
                      const Text(
                        'MPIN Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your number and 4-digit MPIN to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: InputDecoration(
                          hintText: 'Enter your 11-digit phone number',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          prefixIcon: Icon(Icons.phone, color: Colors.green),
                          counterText: '',
                          errorText: _phoneErrorText,
                        ),
                        onChanged: (_) {
                          if (_phoneErrorText != null) setState(() => _phoneErrorText = null);
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _mpinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter 4-digit MPIN',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          prefixIcon: Icon(Icons.lock, color: Colors.green),
                          counterText: '',
                          errorText: _mpinErrorText,
                        ),
                        onChanged: (_) {
                          if (_mpinErrorText != null) setState(() => _mpinErrorText = null);
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyMPIN,
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
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
