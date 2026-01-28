import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device is online
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      // Check if connected (not none)
      final isConnected = result.contains(ConnectivityResult.mobile) ||
                         result.contains(ConnectivityResult.wifi) ||
                         result.contains(ConnectivityResult.ethernet);
      
      print(isConnected ? '🌐 Online' : '📴 Offline');
      return isConnected;
    } catch (e) {
      print('❌ Connectivity check failed: $e');
      return false;
    }
  }

  /// Stream connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Get connection type
  Future<String> getConnectionType() async {
    final result = await _connectivity.checkConnectivity();
    
    if (result.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (result.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (result.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return 'Offline';
  }
}