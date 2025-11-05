import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegistrationCreateMPINScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayName;

  const RegistrationCreateMPINScreen({
    super.key,
    required this.phoneNumber,
    required this.displayName,
  });

  @override
  State<RegistrationCreateMPINScreen> createState() =>
      _RegistrationCreateMPINScreenState();
}

class _RegistrationCreateMPINScreenState
    extends State<RegistrationCreateMPINScreen> {
  final AuthService _authService = AuthService();

  String _mpin = '';
  String _confirmMpin = '';
  bool _isCreatingMpin = true; // true = create, false = confirm
  bool _isLoading = false;
  String? _errorMessage;

  void _onKeyTap(String value) {
    setState(() {
      if (_isCreatingMpin) {
        if (_mpin.length < 4) {
          _mpin += value;
          _errorMessage = null;

          // Auto-proceed to confirm when 4 digits entered
          if (_mpin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isCreatingMpin = false;
                });
              }
            });
          }
        }
      } else {
        if (_confirmMpin.length < 4) {
          _confirmMpin += value;
          _errorMessage = null;

          // Auto-verify when 4 digits entered
          if (_confirmMpin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _verifyAndSaveMPIN();
              }
            });
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_isCreatingMpin) {
        if (_mpin.isNotEmpty) {
          _mpin = _mpin.substring(0, _mpin.length - 1);
          _errorMessage = null;
        }
      } else {
        if (_confirmMpin.isNotEmpty) {
          _confirmMpin = _confirmMpin.substring(0, _confirmMpin.length - 1);
          _errorMessage = null;
        }
      }
    });
  }

  void _onBack() {
    if (!_isCreatingMpin) {
      // Go back to creating MPIN
      setState(() {
        _isCreatingMpin = true;
        _confirmMpin = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyAndSaveMPIN() async {
    if (_mpin != _confirmMpin) {
      setState(() {
        _errorMessage = 'MPINs do not match. Please try again.';
        _confirmMpin = '';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save MPIN to secure storage
      final saved = await _authService.saveMPIN(widget.phoneNumber, _mpin);

      setState(() => _isLoading = false);

      if (saved) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('MPIN created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Wait a moment then navigate to login
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to login screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/', // Your login route
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to save MPIN. Please try again.';
          _confirmMpin = '';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
        _confirmMpin = '';
      });
    }
  }

  Widget _buildPinDots(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          // Row 4: back arrow, 0, backspace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NumberButton(
                onTap: _isCreatingMpin ? () {} : _onBack,
                child: Icon(
                  Icons.arrow_back,
                  color: _isCreatingMpin ? Colors.transparent : Colors.green,
                  size: 28,
                ),
              ),
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
                child:
                    const Icon(Icons.backspace, color: Colors.green, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isCreatingMpin ? _mpin : _confirmMpin;

    return WillPopScope(
      onWillPop: () async {
        if (!_isCreatingMpin) {
          _onBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _isCreatingMpin
                            ? () => Navigator.pop(context)
                            : _onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Text(
                        _isCreatingMpin ? 'Create MPIN' : 'Confirm MPIN',
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

                  // Success Icon
                  Container(
                    width: 100,
                    height: 100,
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
                      Icons.check_circle_outline,
                      size: 50,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // MPIN Card
                  Expanded(
                    child: Container(
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
                        children: [
                          Text(
                            _isCreatingMpin
                                ? 'Create Your MPIN'
                                : 'Confirm Your MPIN',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isCreatingMpin
                                ? 'Enter a 4-digit PIN for quick login'
                                : 'Re-enter your 4-digit PIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // PIN Dots
                          _buildPinDots(currentPin),

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

                          const SizedBox(height: 30),

                          // Number Pad
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            color: Colors.green),
                                        SizedBox(height: 16),
                                        Text(
                                          'Setting up your MPIN...',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildNumberPad(),
                          ),

                          const SizedBox(height: 16),

                          // Info Text
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Keep your MPIN secure. You\'ll use it for quick login.',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
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
                ],
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
          width: 65,
          height: 65,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
