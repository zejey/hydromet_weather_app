import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HotlineItem {
  final String id;
  final String serviceName;
  final String phoneNumber;
  final String iconType;
  final String iconColor;
  final int priority;
  final bool isActive;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HotlineItem({
    required this.id,
    required this.serviceName,
    required this.phoneNumber,
    required this.iconType,
    required this.iconColor,
    required this.priority,
    required this.isActive,
    required this.category,
    this.createdAt,
    this.updatedAt,
  });

  factory HotlineItem.fromMap(Map<String, dynamic> map, String docId) {
    return HotlineItem(
      id: docId,
      serviceName: map['service_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      iconType: map['icon_type'] ?? 'phone',
      iconColor: map['icon_color'] ?? '#000000',
      priority: map['priority'] ?? 0,
      isActive: map['is_active'] ?? true,
      category: map['category'] ?? 'general',
      createdAt: map['created_at']?.toDate(),
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'service_name': serviceName,
      'phone_number': phoneNumber,
      'icon_type': iconType,
      'icon_color': iconColor,
      'priority': priority,
      'is_active': isActive,
      'category': category,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // Helper method to get Flutter icon from string
  IconData get icon {
    switch (iconType) {
      case 'account_balance':
        return Icons.account_balance;
      case 'warning_amber':
        return Icons.warning_amber;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'local_police':
        return Icons.local_police;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'fire_truck':
        return Icons.fire_truck;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'phone':
        return Icons.phone;
      default:
        return Icons.contact_phone;
    }
  }

  // Helper method to get Flutter color from hex string
  Color get color {
    try {
      return Color(int.parse(iconColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

class HotlinesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'emergency_hotlines';

  // Get all active hotlines ordered by priority
  Stream<List<HotlineItem>> getActiveHotlines() {
    return _firestore
        .collection(_collection)
        .where('is_active', isEqualTo: true)
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HotlineItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get hotlines by category
  Stream<List<HotlineItem>> getHotlinesByCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('is_active', isEqualTo: true)
        .where('category', isEqualTo: category)
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HotlineItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add new hotline (admin function)
  Future<void> addHotline(HotlineItem hotline) async {
    await _firestore.collection(_collection).add(hotline.toMap());
  }

  // Update hotline (admin function)
  Future<void> updateHotline(String id, HotlineItem hotline) async {
    await _firestore.collection(_collection).doc(id).update(hotline.toMap());
  }

  // Delete hotline (admin function)
  Future<void> deleteHotline(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Toggle hotline active status (admin function)
  Future<void> toggleHotlineStatus(String id, bool isActive) async {
    await _firestore.collection(_collection).doc(id).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
