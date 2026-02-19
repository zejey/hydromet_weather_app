import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/user_profile_api_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  final AuthService _authService = AuthService();
  final UserProfileApiService _profileApi = UserProfileApiService();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isInitialLoadDone = false;

  // backend fields we must preserve on update
  String _userId = '';
  String _role = 'user';
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _houseAddressController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    setState(() => _isLoading = true);

    await _authService.initialize();
    final userId = _authService.userId;

    if (userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isInitialLoadDone = true;
      });
      _showSnackBar('No user session found. Please log in again.');
      return;
    }

    _userId = userId;

    // Load cache first (fast)
    await _loadFromCache();

    // Load backend (source of truth)
    try {
      final user = await _profileApi.fetchUser(_userId);
      _applyUserJson(user);
      await _saveToCache();
    } catch (e) {
      debugPrint('Profile fetch failed: $e');
      _showSnackBar('Could not load profile from server. Showing saved data.');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isInitialLoadDone = true;
    });
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _firstNameController.text = prefs.getString('firstName') ?? '';
    _middleNameController.text = prefs.getString('middleName') ?? '';
    _lastNameController.text = prefs.getString('lastName') ?? '';
    _mobileController.text = prefs.getString('mobile') ?? '';
    _houseAddressController.text = prefs.getString('house_address') ?? '';
    _barangayController.text = prefs.getString('barangay') ?? '';
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', _firstNameController.text.trim());
    await prefs.setString('middleName', _middleNameController.text.trim());
    await prefs.setString('lastName', _lastNameController.text.trim());
    await prefs.setString('mobile', _mobileController.text.trim());
    await prefs.setString('house_address', _houseAddressController.text.trim());
    await prefs.setString('barangay', _barangayController.text.trim());
  }

  void _applyUserJson(Map<String, dynamic> user) {
    _firstNameController.text = (user['first_name'] ?? '').toString();
    _middleNameController.text = (user['middle_name'] ?? '').toString();
    _lastNameController.text = (user['last_name'] ?? '').toString();
    _mobileController.text = (user['phone_number'] ?? '').toString();
    _houseAddressController.text = (user['house_address'] ?? '').toString();
    _barangayController.text = (user['barangay'] ?? '').toString();

    _role = (user['role'] ?? 'user').toString();
    _isVerified = (user['is_verified'] ?? false) == true;
  }

  Future<void> _saveProfile() async {
    if (_userId.isEmpty) {
      _showSnackBar('No user session found.');
      return;
    }

    if (_firstNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your first name');
      return;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your last name');
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      _showSnackBar('Please enter your mobile number');
      return;
    }
    if (_mobileController.text.trim().length < 10) {
      _showSnackBar('Please enter a valid mobile number');
      return;
    }
    if (_houseAddressController.text.trim().isEmpty) {
      _showSnackBar('Please enter your house address');
      return;
    }
    if (_barangayController.text.trim().isEmpty) {
      _showSnackBar('Please enter your barangay');
      return;
    }

    setState(() => _isLoading = true);

    final payload = <String, dynamic>{
      "first_name": _firstNameController.text.trim(),
      "middle_name": _middleNameController.text.trim().isEmpty
          ? null
          : _middleNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "suffix": null,
      "house_address": _houseAddressController.text.trim(),
      "barangay": _barangayController.text.trim(),
      "phone_number": _mobileController.text.trim(),
      "role": _role,
      "is_verified": _isVerified,
    };

    try {
      final updated = await _profileApi.updateUser(_userId, payload);
      _applyUserJson(updated);
      await _saveToCache();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
      _showSnackBar('Profile updated successfully!');
    } catch (e) {
      debugPrint('Profile update failed: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update profile. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Optionally show a light loading overlay during the initial load
    final showBlockingLoader = !_isInitialLoadDone && _isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF6FBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset('assets/b.jpg', fit: BoxFit.cover),
          ),
          SizedBox.expand(
            child: Container(
              color: Colors.black.withOpacity(0.25),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF13b464)),
                        SizedBox(width: 8),
                        Text(
                          'Profile Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13b464),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _profileFieldCard('First Name', _firstNameController,
                        enabled: _isEditing),
                    const SizedBox(height: 12),
                    _profileFieldCard('Middle Name', _middleNameController,
                        enabled: _isEditing),
                    const SizedBox(height: 12),
                    _profileFieldCard('Last Name', _lastNameController,
                        enabled: _isEditing),
                    const SizedBox(height: 12),
                    _profileFieldCard(
                      'Mobile Number',
                      _mobileController,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _profileFieldCard(
                      'House Address',
                      _houseAddressController,
                      enabled: _isEditing,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _profileFieldCard(
                      'Barangay',
                      _barangayController,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13b464),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : (_isEditing
                                    ? _saveProfile
                                    : () => setState(() => _isEditing = true)),
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
                                    _isEditing ? 'Save Changes' : 'Edit',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showBlockingLoader)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileFieldCard(
    String label,
    TextEditingController controller, {
    bool enabled = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 16,
          color: enabled ? Colors.black87 : Colors.grey.shade600,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
