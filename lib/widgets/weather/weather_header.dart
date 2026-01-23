import 'package:flutter/material.dart';

class WeatherHeader extends StatelessWidget {
  final bool isGuest;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;  // ✅ Make nullable

  const WeatherHeader({
    super.key,
    required this.isGuest,
    this.onNotificationTap,
    this.onMenuTap,  // ✅ Optional now
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children:  [
        // Notification button (left)
        if (onNotificationTap != null)  // ✅ Only show if callback provided
          Container(
            decoration: BoxDecoration(
              color: Colors.white. withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onNotificationTap,
              icon: const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        
        const Spacer(),
        
        // App Title/Logo (center)
        const Text(
          'HydroMet',
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
        
        const Spacer(),
        
        // Menu button (right) - only show if callback provided
        if (onMenuTap != null)  // ✅ Only show if callback provided
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onMenuTap,
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 28,
              ),
            ),
          )
        else
          const SizedBox(width: 48),  // ✅ Placeholder to keep title centered
      ],
    );
  }
}