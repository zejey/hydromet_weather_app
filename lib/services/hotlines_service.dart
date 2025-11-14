import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Hotline model used by the app.
/// Contains helpers for converting from API JSON and (keeps) Firestore mapping for backwards compatibility.
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

  /// Create from backend API JSON (expects ISO timestamps or null).
  factory HotlineItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parse(dynamic v) {
      if (v == null) return null;
      try {
        if (v is String) return DateTime.parse(v);
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        if (v is Map && v.containsKey('_seconds')) {
          // Firestore REST style
          return DateTime.fromMillisecondsSinceEpoch((v['_seconds'] as int) * 1000);
        }
      } catch (_) {}
      return null;
    }

    return HotlineItem(
      id: json['id']?.toString() ?? '',
      serviceName: json['service_name'] ?? json['serviceName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      iconType: json['icon_type'] ?? json['iconType'] ?? 'phone',
      iconColor: json['icon_color'] ?? json['iconColor'] ?? '#000000',
      priority: (json['priority'] is int) ? json['priority'] : int.tryParse('${json['priority']}') ?? 0,
      isActive: json['is_active'] is bool ? json['is_active'] : (json['isActive'] == 1 || json['isActive'] == true),
      category: json['category'] ?? 'general',
      createdAt: _parse(json['created_at']),
      updatedAt: _parse(json['updated_at']),
    );
  }

  /// Backwards-compatible helper if you still receive Firestore snapshot maps.
  factory HotlineItem.fromMap(Map<String, dynamic> map, String docId) {
    // Try to convert Firestore Timestamp to DateTime if available
    DateTime? parseFirestoreDate(dynamic v) {
      if (v == null) return null;
      try {
        // If it's already a DateTime
        if (v is DateTime) return v;
        // If it's a Map like {"_seconds":...}
        if (v is Map && v.containsKey('_seconds')) {
          return DateTime.fromMillisecondsSinceEpoch((v['_seconds'] as int) * 1000);
        }
        // If it has toDate (Firestore Timestamp), it will be returned as a dynamic with a method,
        // but we can't reliably call it here — keep safe fallback.
      } catch (_) {}
      return null;
    }

    final createdAt = map['created_at'] != null
        ? (map['created_at'] is String ? DateTime.tryParse(map['created_at']) : parseFirestoreDate(map['created_at']))
        : null;
    final updatedAt = map['updated_at'] != null
        ? (map['updated_at'] is String ? DateTime.tryParse(map['updated_at']) : parseFirestoreDate(map['updated_at']))
        : null;

    return HotlineItem(
      id: docId,
      serviceName: map['service_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      iconType: map['icon_type'] ?? 'phone',
      iconColor: map['icon_color'] ?? '#000000',
      priority: map['priority'] is int ? map['priority'] : int.tryParse('${map['priority']}') ?? 0,
      isActive: map['is_active'] ?? true,
      category: map['category'] ?? 'general',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convert to JSON suitable for the backend API (no server timestamp placeholders)
  Map<String, dynamic> toApiJson() {
    final m = <String, dynamic>{
      'service_name': serviceName,
      'phone_number': phoneNumber,
      'icon_type': iconType,
      'icon_color': iconColor,
      'priority': priority,
      'is_active': isActive,
      'category': category,
    };
    // created_at/updated_at are handled server-side by the backend API; include only if present
    if (createdAt != null) m['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) m['updated_at'] = updatedAt!.toIso8601String();
    return m;
  }

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

  Color get color {
    try {
      return Color(int.parse(iconColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

/// Hotlines service that talks to your backend REST API instead of Firestore.
///
/// - Replace the value of [_apiBaseUrl] with your deployed backend URL (or inject via environment).
/// - Uses the same CRUD endpoints implemented in backend/api/hotlines.py
class HotlinesService {
  // TODO: set this to your backend base URL or make configurable
  static const String _apiBaseUrl = 'https://caring-kindness-production.up.railway.app';

  // API endpoints
  Uri _hotlinesUri({bool activeOnly = true}) =>
      Uri.parse('$_apiBaseUrl/api/hotlines${activeOnly ? '?active_only=true' : ''}');

  Uri _hotlinesByCategoryUri(String category) =>
      Uri.parse('$_apiBaseUrl/api/hotlines/category/${Uri.encodeComponent(category)}');

  Uri _hotlineItemUri(String id) => Uri.parse('$_apiBaseUrl/api/hotlines/$id');

  final Duration _pollInterval;

  HotlinesService({Duration? pollInterval}) : _pollInterval = pollInterval ?? const Duration(seconds: 30);

  // ---- READ ----

  /// Fetch a list of active hotlines (one-off)
  Future<List<HotlineItem>> getActiveHotlines({Duration? cacheTtl}) async {
    final uri = _hotlinesUri(activeOnly: true);
    final resp = await http.get(uri, headers: {'Accept': 'application/json'});

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch hotlines: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final List<dynamic> body = json.decode(resp.body) as List<dynamic>;
    return body.map((e) => HotlineItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch hotlines by category (one-off)
  Future<List<HotlineItem>> getHotlinesByCategory(String category) async {
    final uri = _hotlinesByCategoryUri(category);
    final resp = await http.get(uri, headers: {'Accept': 'application/json'});

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch hotlines by category: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final List<dynamic> body = json.decode(resp.body) as List<dynamic>;
    return body.map((e) => HotlineItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Stream of hotlines using polling. Useful to replace Firestore snapshots.
  /// Emits immediately and then at every [pollInterval].
  Stream<List<HotlineItem>> getActiveHotlinesStream({Duration? pollInterval}) {
    final interval = pollInterval ?? _pollInterval;
    // Create a broadcast stream controller so many listeners can subscribe.
    final controller = StreamController<List<HotlineItem>>.broadcast();
    Timer? timer;

    Future<void> fetchAndAdd() async {
      try {
        final items = await getActiveHotlines();
        if (!controller.isClosed) controller.add(items);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    // Start immediately
    fetchAndAdd();

    timer = Timer.periodic(interval, (_) => fetchAndAdd());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  // ---- WRITE: Admin functions ----

  /// Add a new hotline via API (admin)
  Future<HotlineItem> addHotline(HotlineItem hotline) async {
    final uri = _hotlinesUri(activeOnly: false);
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(hotline.toApiJson()),
    );

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('Failed to create hotline: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> body = json.decode(resp.body) as Map<String, dynamic>;
    return HotlineItem.fromJson(body);
  }

  /// Update existing hotline via API (admin)
  Future<HotlineItem> updateHotline(String id, HotlineItem hotline) async {
    final uri = _hotlineItemUri(id);
    final resp = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(hotline.toApiJson()),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to update hotline: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> body = json.decode(resp.body) as Map<String, dynamic>;
    return HotlineItem.fromJson(body);
  }

  /// Delete hotline via API (admin)
  Future<void> deleteHotline(String id) async {
    final uri = _hotlineItemUri(id);
    final resp = await http.delete(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete hotline: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Toggle active status via API (admin)
  Future<HotlineItem> toggleHotlineStatus(String id, bool isActive) async {
    // Reuse update endpoint to set is_active only
    final uri = _hotlineItemUri(id);
    final resp = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'is_active': isActive}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to toggle hotline status: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> body = json.decode(resp.body) as Map<String, dynamic>;
    return HotlineItem.fromJson(body);
  }
}
