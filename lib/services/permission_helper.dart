import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionHelper {
  /// Show permission dialog
  static Future<void> showPermissionDialog(BuildContext context) async {
    final notificationGranted = await Permission.notification.isGranted;
    final locationGranted = await Permission.location.isGranted;

    if (notificationGranted && locationGranted) {
      return; // All permissions granted
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.blue),
              SizedBox(width: 12),
              Text('Permissions Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HydroMet needs the following permissions to work properly:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.notifications,
                title: 'Notifications',
                description: 'Receive weather alerts and hazard warnings',
                granted: notificationGranted,
              ),
              const SizedBox(height: 12),
              _buildPermissionItem(
                icon: Icons.location_on,
                title: 'Location',
                description: 'Get weather for your current location',
                granted: locationGranted,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await requestAllPermissions(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Grant Permissions'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: granted ? Colors.green : Colors.orange,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (granted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 16)
                  else
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                ],
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Request all permissions
  static Future<void> requestAllPermissions(BuildContext context) async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    
    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      if (!context.mounted) return;
      _showPermissionDeniedDialog(
        context,
        'Notification',
        'You won\'t receive weather alerts',
      );
    }

    // Request location permission
    final locationStatus = await Permission.location.request();
    
    if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
      if (!context.mounted) return;
      _showPermissionDeniedDialog(
        context,
        'Location',
        'You can still use San Pedro as default location',
      );
    }
  }

  static void _showPermissionDeniedDialog(
    BuildContext context,
    String permissionName,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'You can enable this in Settings > Apps > HydroMET PH > Permissions',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check if all permissions are granted
  static Future<bool> checkAllPermissions() async {
    final notificationGranted = await Permission.notification.isGranted;
    final locationGranted = await Permission.location.isGranted;
    
    return notificationGranted && locationGranted;
  }

  /// Show permission status in settings
  static Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'notification': await Permission.notification.isGranted,
      'location': await Permission.location.isGranted,
    };
  }
}