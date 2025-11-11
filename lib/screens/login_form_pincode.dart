import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_registration_service.dart';

class LoginMPINScreen extends StatefulWidget {
  final String phoneNumber;

  const LoginMPINScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<LoginMPINScreen> createState() => _LoginMPINScreenState();
}

class _LoginMPINScreenState extends State<LoginMPINScreen> {
  String _mpin = '';
  bool _isLoading = false;
  String? _mpinErrorText;
  late String _currentPhoneNumber;

  @override
  void initState() {
    super.initState();
    _currentPhoneNumber = widget.phoneNumber;
  }

  void _onKeyTap(String value) {
    if (_mpin.length < 4) {
      setState(() {
        _mpin += value;
        _mpinErrorText = null;
      });

      // Auto-submit when 4 digits entered
      if (_mpin.length == 4) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _verifyMPIN();
        });
      }
    }
  }

  void _onBackspace() {
    if (_mpin.isNotEmpty) {
      setState(() {
        _mpin = _mpin.substring(0, _mpin.length - 1);
        _mpinErrorText = null;
      });
    }
  }

  void _verifyMPIN() async {
    if (_mpin.isEmpty || _mpin.length != 4) {
      setState(() => _mpinErrorText = 'MPIN must be exactly 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final userService = UserRegistrationService();

      // ✅ STEP 1: Check if user exists in backend
      print('🔍 Checking if user exists: $_currentPhoneNumber');
      final userExists =
          await userService.isPhoneRegistered(_currentPhoneNumber);

      if (!userExists) {
        setState(() {
          _isLoading = false;
          _mpinErrorText = 'User not found. Please register.';
          _mpin = '';
        });

        // ✅ Clear local MPIN since user doesn't exist
        await authService.clearMPIN(_currentPhoneNumber);
        print('🗑️ Cleared local MPIN for non-existent user');

        // Show register dialog after delay
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pop(context); // Go back to login screen

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Not Found'),
              content: const Text(
                'This account has been removed or doesn\'t exist. Please register again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/register');
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Register',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ✅ STEP 2: Verify MPIN locally (only if user exists)
      print('✅ User exists, verifying MPIN...');
      final result = await authService.loginWithMPIN(
        phoneNumber: _currentPhoneNumber,
        mpin: _mpin,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        if (result['skip_otp'] == true) {
          // Login directly without OTP
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Welcome back! (Trusted device)'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushNamedAndRemoveUntil(
                context, '/weather', (route) => false);
          }
        } else {
          // OTP required
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('MPIN verified! Please enter OTP for security.'),
                backgroundColor: Colors.orange,
              ),
            );

            Navigator.pushNamed(
              context,
              '/verify-otp',
              arguments: {
                'phoneNumber': _currentPhoneNumber,
                'fromLogin': true,
              },
            );
          }
        }
      } else {
        setState(() {
          _mpinErrorText = result['error'] ?? 'Login failed';
          _mpin = '';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _mpinErrorText = 'Error: ${e.toString()}';
        _mpin = '';
      });
    }
  }

  void _changePhoneNumber() {
    TextEditingController phoneController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Change Phone Number',
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '+63',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: InputDecoration(
                            hintText: '9XXXXXXXXX',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            counterText: '',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                              borderSide:
                                  BorderSide(color: Colors.green, width: 2),
                            ),
                            errorText: errorMessage,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              errorMessage = _validatePhoneNumber(value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: errorMessage == null &&
                          phoneController.text.length == 10
                      ? () {
                          setState(() {
                            _currentPhoneNumber = '09${phoneController.text}';
                            _mpin = ''; // Clear MPIN when changing phone
                            _mpinErrorText = null;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Phone number updated to 09${phoneController.text}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Update',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _validatePhoneNumber(String value) {
    if (value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 10) {
      return 'Must be exactly 10 digits';
    }
    if (!value.startsWith('9')) {
      return 'Must start with 9';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Only numbers allowed';
    }
    return null;
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < _mpin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled ? Colors.green : Colors.transparent,
            border: Border.all(color: Colors.green, width: 2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton(
              child: const Text('1',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('1'),
            ),
            _NumberButton(
              child: const Text('2',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('2'),
            ),
            _NumberButton(
              child: const Text('3',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('3'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton(
              child: const Text('4',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('4'),
            ),
            _NumberButton(
              child: const Text('5',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('5'),
            ),
            _NumberButton(
              child: const Text('6',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('6'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton(
              child: const Text('7',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('7'),
            ),
            _NumberButton(
              child: const Text('8',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('8'),
            ),
            _NumberButton(
              child: const Text('9',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('9'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 4: empty, 0, backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 60, height: 60),
            _NumberButton(
              child: const Text('0',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              onTap: () => _onKeyTap('0'),
            ),
            _NumberButton(
              onTap: _onBackspace,
              child: const Icon(Icons.backspace, color: Colors.green, size: 28),
            ),
          ],
        ),
      ],
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
            // ← FIX 1: Added scrollview
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              // ← FIX 2: Added constraint
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                // ← FIX 3: Added intrinsic height
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 5),

                      // Header
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

                      const SizedBox(height: 5),

                      // Logo
                      Container(
                        width: 300,
                        height: 180,
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
                                        color: Colors.white,
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

                      const SizedBox(height: 10),

                      // MPIN Container
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                            mainAxisSize:
                                MainAxisSize.min, // ← FIX 4: Changed to min
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
                              const SizedBox(height: 16),

                              // Phone Number Display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                      color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone,
                                        color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentPhoneNumber,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _changePhoneNumber,
                                      child: const Icon(Icons.edit,
                                          color: Colors.green, size: 16),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // MPIN Input
                              const Text(
                                'Enter your 4-digit MPIN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),

                              _buildPinDots(),

                              if (_mpinErrorText != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _mpinErrorText!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Number Pad
                              _buildNumberPad(),

                              const SizedBox(height: 16),

                              // Sign In Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyMPIN,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10), // ← FIX 5: Bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NumberButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
