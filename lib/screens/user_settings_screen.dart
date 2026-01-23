import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/settings_storage.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({Key? key}) : super(key: key);

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  bool _weatherAlertsEnabled = true;
  bool _emergencyAlertsEnabled = true;
  String _temperatureUnit = 'Celsius';
  String _language = 'English';
  double _alertRadius = 5.0;
  final AuthManager _authManager = AuthManager();
  
  bool _isLoggedIn = false;
  bool _isLoading = true; // ✅ Add loading state

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  // ✅ New initialization method
  Future<void> _initializeAuth() async {
    await _authManager.initialize(); // Make sure auth is initialized
    await _checkLoginStatus();
    await _loadSettings();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (mounted) {
      setState(() {
        _isLoggedIn = _authManager.isLoggedIn;
      });
      
      print('🔐 Login status: $_isLoggedIn');
      print('🔐 Username: ${_authManager.username}');
      print('🔐 Phone: ${_authManager.phoneNumber}');
    }
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsStorage.loadSettings();
    if (mounted) {
      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;
        _locationEnabled = settings['locationEnabled'] ?? true;
        _darkModeEnabled = settings['darkModeEnabled'] ?? false;
        _weatherAlertsEnabled = settings['weatherAlertsEnabled'] ?? true;
        _emergencyAlertsEnabled = settings['emergencyAlertsEnabled'] ?? true;
        _temperatureUnit = settings['temperatureUnit'] ?? 'Celsius';
        _language = settings['language'] ?? 'English';
        _alertRadius = settings['alertRadius'] ?? 5.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading spinner while checking auth
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/b.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // Show login required screen
    if (!_isLoggedIn) {
        // Show settings screen (logged in)
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/b.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'User Settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Settings Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade600, Colors.green.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _authManager.username,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _authManager.phoneNumber,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        // Notifications Section
                        _buildSectionHeader('🔔 Notifications'),
                        _buildSwitchTile(
                          'Enable Notifications',
                          'Receive weather updates and alerts',
                          _notificationsEnabled,
                          (value) => setState(() => _notificationsEnabled = value),
                        ),
                        _buildSwitchTile(
                          'Weather Alerts',
                          'Get notified about severe weather conditions',
                          _weatherAlertsEnabled,
                          (value) => setState(() => _weatherAlertsEnabled = value),
                        ),
                        _buildSwitchTile(
                          'Emergency Alerts',
                          'Critical emergency notifications',
                          _emergencyAlertsEnabled,
                          (value) => setState(() => _emergencyAlertsEnabled = value),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Location Section
                        _buildSectionHeader('📍 Location'),
                        _buildSwitchTile(
                          'Location Services',
                          'Allow app to access your location',
                          _locationEnabled,
                          (value) => setState(() => _locationEnabled = value),
                        ),
                        _buildSliderTile(
                          'Alert Radius',
                          'Receive alerts within ${_alertRadius.toInt()} km',
                          _alertRadius,
                          1.0,
                          20.0,
                          (value) => setState(() => _alertRadius = value),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Display Section
                        _buildSectionHeader('🎨 Display'),
                        _buildSwitchTile(
                          'Dark Mode',
                          'Use dark theme for better visibility at night',
                          _darkModeEnabled,
                          (value) => setState(() => _darkModeEnabled = value),
                        ),
                        _buildDropdownTile(
                          'Temperature Unit',
                          _temperatureUnit,
                          ['Celsius', 'Fahrenheit'],
                          (value) => setState(() => _temperatureUnit = value!),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Language Section
                        _buildSectionHeader('🌐 Language'),
                        _buildDropdownTile(
                          'Language',
                          _language,
                          ['English', 'Filipino', 'Tagalog'],
                          (value) => setState(() => _language = value!),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Save Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _resetSettings(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.red, width: 2),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // About Section
                        _buildInfoCard(),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show settings screen (your existing code)
    return Theme(
      data: _darkModeEnabled
          ? ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black)
          : ThemeData.light(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/b.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'User Settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Settings Content
                  Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _darkModeEnabled 
                          ? Colors.grey[850]!.withOpacity(0.95) 
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info at top
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Colors.green, size: 32),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _authManager.username,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _authManager.phoneNumber,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Notifications Section
                          _buildSectionHeader('🔔 Notifications'),
                          _buildSwitchTile(
                            'Enable Notifications',
                            'Receive weather updates and alerts',
                            _notificationsEnabled,
                            (value) => setState(() => _notificationsEnabled = value),
                          ),
                          _buildSwitchTile(
                            'Weather Alerts',
                            'Get notified about severe weather conditions',
                            _weatherAlertsEnabled,
                            (value) => setState(() => _weatherAlertsEnabled = value),
                          ),
                          _buildSwitchTile(
                            'Emergency Alerts',
                            'Critical emergency notifications',
                            _emergencyAlertsEnabled,
                            (value) => setState(() => _emergencyAlertsEnabled = value),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Location Section
                          _buildSectionHeader('📍 Location'),
                          _buildSwitchTile(
                            'Location Services',
                            'Allow app to access your location',
                            _locationEnabled,
                            (value) => setState(() => _locationEnabled = value),
                          ),
                          _buildSliderTile(
                            'Alert Radius',
                            'Receive alerts within ${_alertRadius.toInt()} km',
                            _alertRadius,
                            1.0,
                            20.0,
                            (value) => setState(() => _alertRadius = value),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Display Section
                          _buildSectionHeader('🎨 Display'),
                          _buildSwitchTile(
                            'Dark Mode',
                            'Use dark theme for better visibility at night',
                            _darkModeEnabled,
                            (value) => setState(() => _darkModeEnabled = value),
                          ),
                          _buildDropdownTile(
                            'Temperature Unit',
                            _temperatureUnit,
                            ['Celsius', 'Fahrenheit'],
                            (value) => setState(() => _temperatureUnit = value!),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Language Section
                          _buildSectionHeader('🌐 Language'),
                          _buildDropdownTile(
                            'Language',
                            _language,
                            ['English', 'Filipino', 'Tagalog'],
                            (value) => setState(() => _language = value!),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save Settings',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _resetSettings(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reset to Default',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // About Section
                          _buildInfoCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        shadows: [
          Shadow(
            color: Colors.white54,
            offset: Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    ),
  );
}

Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}

Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, Function(double) onChanged) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.green,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: Colors.green,
            overlayColor: Colors.green.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDropdownTile(String title, String value, List<String> items, Function(String?) onChanged) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

Widget _buildInfoCard() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 28),
            const SizedBox(width: 12),
            const Text(
              'About HydroMet San Pedro',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Weather monitoring and emergency alert system for San Pedro City.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.email_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'support@hydromet.gov.ph',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Future<void> _saveSettings() async {
    await SettingsStorage.saveSettings(
      notificationsEnabled: _notificationsEnabled,
      locationEnabled: _locationEnabled,
      darkModeEnabled: _darkModeEnabled,
      weatherAlertsEnabled: _weatherAlertsEnabled,
      emergencyAlertsEnabled: _emergencyAlertsEnabled,
      temperatureUnit: _temperatureUnit,
      language: _language,
      alertRadius: _alertRadius,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Settings'),
          content: const Text('Are you sure you want to reset all settings to default values?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await SettingsStorage.resetSettings();
                setState(() {
                  _notificationsEnabled = true;
                  _locationEnabled = true;
                  _darkModeEnabled = false;
                  _weatherAlertsEnabled = true;
                  _emergencyAlertsEnabled = true;
                  _temperatureUnit = 'Celsius';
                  _language = 'English';
                  _alertRadius = 5.0;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to default values'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
