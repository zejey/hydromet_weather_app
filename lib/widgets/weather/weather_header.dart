import 'package:flutter/material.dart';

class WeatherHeader extends StatelessWidget {
  final bool isGuest;
  final VoidCallback? onNotificationTap;
  final VoidCallback onMenuTap;

  const WeatherHeader({
    required this.isGuest,
    this.onNotificationTap,
    required this.onMenuTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Notification/Guest icon
        IconButton(
          onPressed: onNotificationTap,
          icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
        ),

        // Fixed location display bar
        Expanded(
          child: Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Icon(
                    Icons.location_pin,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'San Pedro, Laguna, Philippines',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Profile/Menu button
        IconButton(
          onPressed: onMenuTap,
          icon: Icon(
            isGuest ? Icons.menu : Icons.account_circle,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }
}
