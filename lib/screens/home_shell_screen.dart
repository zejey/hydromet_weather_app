import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'weather_tab_screen.dart';
import 'map_tab_screen.dart';
import 'tips_screen.dart';
import 'hotlines_screen.dart';
import 'profile_tab_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class HomeShellNavigator extends InheritedWidget {
  final Function(int) switchToTab;
  
  const HomeShellNavigator({
    super.key,
    required this.switchToTab,
    required super.child,
  });

  static HomeShellNavigator?  of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeShellNavigator>();
  }

  @override
  bool updateShouldNotify(HomeShellNavigator oldWidget) => false;
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;
  bool _isUserLoggedIn = false;
  final AuthService _authService = AuthService();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _initScreens();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuthState();
  }

  void _initScreens() {
    _screens = [
      const WeatherTabScreen(), // Weather
      const MapTabScreen(), // Map
      const TipsScreen(), // Tips
      const HotlinesScreen(), // Hotlines
      const ProfileTabScreen(), // Profile
    ];
  }

  Future<void> _checkAuthState() async {
    await _authService.initialize();
    if (mounted) {
      setState(() {
        _isUserLoggedIn = _authService.isLoggedIn;
      });
    }
  }

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  List<BottomNavigationBarItem> _getNavItems() {
    if (_isUserLoggedIn) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.wb_sunny),
          label: 'Weather',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.lightbulb_outline),
          label: 'Tips',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.phone),
          label: 'Hotlines',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      // Guest mode: Weather, Tips, Hotlines, Sign In
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.wb_sunny),
          label: 'Weather',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.lightbulb_outline),
          label: 'Tips',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.phone),
          label: 'Hotlines',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Sign In',
        ),
      ];
    }
  }

  void _onTap(int index) {
    if (!_isUserLoggedIn) {
      // Guest mode handling
      if (index == 3) {
        // Sign In button
        Navigator.pushNamed(context, '/login');
        return;
      }
      // Map guest indices to screen indices
      final guestToScreenIndex = [0, 2, 3]; // Weather, Tips, Hotlines
      setState(() {
        _currentIndex = guestToScreenIndex[index];
      });
    } else {
      // Logged-in mode
      setState(() {
        _currentIndex = index;
      });
    }
  }

  int _getCurrentNavIndex() {
    if (!_isUserLoggedIn) {
      // Map screen indices to guest nav indices
      const screenToGuestIndex = {
        0: 0, // Weather
        2: 1, // Tips
        3: 2, // Hotlines
      };
      return screenToGuestIndex[_currentIndex] ?? 0;
    }
    return _currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeShellNavigator(
        switchToTab: (index) => setState(() => _currentIndex = index),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getCurrentNavIndex(),
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: _getNavItems(),
      ),
    );
  }
}
