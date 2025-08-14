import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SafetyCategory {
  final String id;
  final String name;
  final String icon;
  final List<String> gradientColors;
  final int order;
  final bool isActive;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SafetyCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.order,
    required this.isActive,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory SafetyCategory.fromMap(Map<String, dynamic> map, String docId) {
    return SafetyCategory(
      id: docId,
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'info',
      gradientColors:
          List<String>.from(map['gradient_colors'] ?? ['#2196F3', '#1976D2']),
      order: map['order'] ?? 0,
      isActive: map['is_active'] ?? true,
      description: map['description'] ?? '',
      createdAt: map['created_at']?.toDate(),
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'gradient_colors': gradientColors,
      'order': order,
      'is_active': isActive,
      'description': description,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // Helper method to get Flutter icon from string
  IconData get iconData {
    switch (icon) {
      case 'air':
        return Icons.air;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'water':
        return Icons.water;
      case 'storm':
        return Icons.storm;
      case 'thermostat':
        return Icons.thermostat;
      case 'umbrella':
        return Icons.umbrella;
      case 'flash_on':
        return Icons.flash_on;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'cloud':
        return Icons.cloud;
      default:
        return Icons.info;
    }
  }

  // Helper method to get Flutter colors from hex strings
  List<Color> get colors {
    return gradientColors.map((hex) {
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (e) {
        return Colors.blue;
      }
    }).toList();
  }
}

class SafetyTip {
  final String id;
  final String categoryId;
  final String range;
  final String level;
  final String color;
  final String description;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SafetyTip({
    required this.id,
    required this.categoryId,
    required this.range,
    required this.level,
    required this.color,
    required this.description,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory SafetyTip.fromMap(Map<String, dynamic> map, String docId) {
    return SafetyTip(
      id: docId,
      categoryId: map['category_id'] ?? '',
      range: map['range'] ?? '',
      level: map['level'] ?? '',
      color: map['color'] ?? '#2196F3',
      description: map['description'] ?? '',
      order: map['order'] ?? 0,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at']?.toDate(),
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'range': range,
      'level': level,
      'color': color,
      'description': description,
      'order': order,
      'is_active': isActive,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // Helper method to get Flutter color from hex string
  Color get colorData {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

class PreventiveMeasure {
  final String id;
  final String categoryId;
  final String number;
  final String title;
  final String description;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PreventiveMeasure({
    required this.id,
    required this.categoryId,
    required this.number,
    required this.title,
    required this.description,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory PreventiveMeasure.fromMap(Map<String, dynamic> map, String docId) {
    return PreventiveMeasure(
      id: docId,
      categoryId: map['category_id'] ?? '',
      number: map['number'] ?? '01',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      order: map['order'] ?? 0,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at']?.toDate(),
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'number': number,
      'title': title,
      'description': description,
      'order': order,
      'is_active': isActive,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}

class SafetyTipsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all active categories ordered by priority
  Stream<List<SafetyCategory>> getActiveCategories() {
    return _firestore
        .collection('safety_categories')
        .where('is_active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SafetyCategory.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get tips for a specific category
  Stream<List<SafetyTip>> getTipsForCategory(String categoryId) {
    return _firestore
        .collection('safety_tips')
        .where('category_id', isEqualTo: categoryId)
        .where('is_active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SafetyTip.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get preventive measures for a specific category
  Stream<List<PreventiveMeasure>> getPreventiveMeasuresForCategory(
      String categoryId) {
    return _firestore
        .collection('preventive_measures')
        .where('category_id', isEqualTo: categoryId)
        .where('is_active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PreventiveMeasure.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Admin functions for managing content
  Future<void> addCategory(SafetyCategory category) async {
    await _firestore.collection('safety_categories').add(category.toMap());
  }

  Future<void> updateCategory(String id, SafetyCategory category) async {
    await _firestore
        .collection('safety_categories')
        .doc(id)
        .update(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('safety_categories').doc(id).delete();
  }

  Future<void> addSafetyTip(SafetyTip tip) async {
    await _firestore.collection('safety_tips').add(tip.toMap());
  }

  Future<void> updateSafetyTip(String id, SafetyTip tip) async {
    await _firestore.collection('safety_tips').doc(id).update(tip.toMap());
  }

  Future<void> deleteSafetyTip(String id) async {
    await _firestore.collection('safety_tips').doc(id).delete();
  }

  Future<void> addPreventiveMeasure(PreventiveMeasure measure) async {
    await _firestore.collection('preventive_measures').add(measure.toMap());
  }

  Future<void> updatePreventiveMeasure(
      String id, PreventiveMeasure measure) async {
    await _firestore
        .collection('preventive_measures')
        .doc(id)
        .update(measure.toMap());
  }

  Future<void> deletePreventiveMeasure(String id) async {
    await _firestore.collection('preventive_measures').doc(id).delete();
  }
}
