import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

// ==================== MODELS ====================

class SafetyCategory {
  final int id;
  final String name;
  final String description;
  final String icon;
  final List<Color> colors;
  final int orderNum;
  final bool isActive;

  SafetyCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.orderNum,
    required this.isActive,
  });

  factory SafetyCategory.fromJson(Map<String, dynamic> json) {
    List<Color> parseColors(dynamic gradientColors) {
      if (gradientColors is List) {
        return gradientColors
            .map((c) => Color(int.parse(c.toString().replaceFirst('#', '0xFF'))))
            .toList();
      }
      return [Colors.green, Colors.green.shade700];
    }

    return SafetyCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'info',
      colors: parseColors(json['gradient_colors']),
      orderNum: json['order_num'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

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
      default:
        return Icons.info;
    }
  }
}

class SafetyTipDetail {
  final int id;
  final int tipId;
  final String description;
  final int orderNum;

  SafetyTipDetail({
    required this.id,
    required this.tipId,
    required this.description,
    required this.orderNum,
  });

  factory SafetyTipDetail.fromJson(Map<String, dynamic> json) {
    return SafetyTipDetail(
      id: json['id'] ?? 0,
      tipId: json['tip_id'] ?? 0,
      description: json['description'] ?? '',
      orderNum: json['order_num'] ?? 0,
    );
  }
}

class SafetyTip {
  final int id;
  final int categoryId;
  final String range;
  final String level;
  final List<String> descriptions;
  final Color colorData;
  final int orderNum;

  SafetyTip({
    required this.id,
    required this.categoryId,
    required this.range,
    required this.level,
    required this.descriptions,
    required this.colorData,
    required this.orderNum,
  });

  factory SafetyTip.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? colorStr) {
      if (colorStr == null || colorStr.isEmpty) return Colors.green;
      try {
        return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {
        return Colors.green;
      }
    }

    List<String> parseDetails(dynamic details) {
      if (details is List) {
        return details.map((d) => d['description'].toString()).toList();
      }
      return [];
    }

    return SafetyTip(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      range: json['range_label'] ?? '',
      level: json['level'] ?? '',
      descriptions: parseDetails(json['details']),
      colorData: parseColor(json['color']),
      orderNum: json['order_num'] ?? 0,
    );
  }
}

class PreventiveMeasure {
  final int id;
  final int categoryId;
  final String number;
  final String title;
  final String description;
  final int orderNum;

  PreventiveMeasure({
    required this.id,
    required this.categoryId,
    required this.number,
    required this.title,
    required this.description,
    required this.orderNum,
  });

  factory PreventiveMeasure.fromJson(Map<String, dynamic> json) {
    return PreventiveMeasure(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      number: json['number'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      orderNum: json['order_num'] ?? 0,
    );
  }
}

// ==================== SERVICE ====================

class SafetyTipsService {
  static const String _baseUrl = 'https://caring-kindness-production.up.railway.app';

  // Cache streams
  final Map<int, Stream<List<SafetyTip>>> _tipStreams = {};
  final Map<int, Stream<List<PreventiveMeasure>>> _measureStreams = {};
  Stream<List<SafetyCategory>>? _categoryStream;

  // ✅ Get all categories
  Stream<List<SafetyCategory>> getActiveCategories() {
    print('🔵 getActiveCategories() called');
    
    if (_categoryStream == null) {
      print('🆕 Creating new category stream');
      _categoryStream = _createCategoryStream().asBroadcastStream();
    } else {
      print('♻️ Reusing existing category stream');
    }
    
    return _categoryStream!;
  }

  Stream<List<SafetyCategory>> _createCategoryStream() async* {
    print('🚀 Category stream generator started');
    
    while (true) {
      try {
        print('📡 Fetching categories from API...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/api/safety/categories/'),  // ✅ WITH trailing slash
        ).timeout(const Duration(seconds: 10));

        print('📡 Categories response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Loaded ${data.length} categories');
          
          final categories = data.map((json) => SafetyCategory.fromJson(json)).toList();
          yield categories;
        } else {
          print('❌ Failed to load categories: ${response.statusCode}');
          yield [];
        }
      } catch (e) {
        print('❌ Error loading categories: $e');
        yield [];
      }

      print('⏰ Waiting 30 seconds before next fetch...');
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  // ✅ Get tips for category
  Stream<List<SafetyTip>> getTipsForCategory(int categoryId) {
    print('🔵 getTipsForCategory($categoryId) called');
    
    if (!_tipStreams.containsKey(categoryId)) {
      print('🆕 Creating new tip stream for category $categoryId');
      _tipStreams[categoryId] = _createTipStream(categoryId).asBroadcastStream();
    } else {
      print('♻️ Reusing existing tip stream for category $categoryId');
    }
    
    return _tipStreams[categoryId]!;
  }

  Stream<List<SafetyTip>> _createTipStream(int categoryId) async* {
    print('🚀 Tip stream generator started for category $categoryId');
    
    while (true) {
      try {
        print('📡 Fetching tips for category $categoryId...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/api/safety/tips/category/$categoryId'),
        ).timeout(const Duration(seconds: 10));

        print('📡 Tips response for category $categoryId: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Loaded ${data.length} tips for category $categoryId');
          
          final tips = data.map((json) => SafetyTip.fromJson(json)).toList();
          yield tips;
        } else {
          print('❌ Failed to load tips: ${response.statusCode}');
          yield [];
        }
      } catch (e) {
        print('❌ Error loading tips for category $categoryId: $e');
        yield [];
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }

  // ✅ Get preventive measures
  Stream<List<PreventiveMeasure>> getPreventiveMeasuresForCategory(int categoryId) {
    print('🔵 getPreventiveMeasuresForCategory($categoryId) called');
    
    if (!_measureStreams.containsKey(categoryId)) {
      print('🆕 Creating new measure stream for category $categoryId');
      _measureStreams[categoryId] = _createMeasureStream(categoryId).asBroadcastStream();
    } else {
      print('♻️ Reusing existing measure stream for category $categoryId');
    }
    
    return _measureStreams[categoryId]!;
  }

  Stream<List<PreventiveMeasure>> _createMeasureStream(int categoryId) async* {
    print('🚀 Measure stream generator started for category $categoryId');
    
    while (true) {
      try {
        print('📡 Fetching preventive measures for category $categoryId...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/api/safety/preventive-measures/category/$categoryId'),
        ).timeout(const Duration(seconds: 10));

        print('📡 Measures response for category $categoryId: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ Loaded ${data.length} preventive measures for category $categoryId');
          
          final measures = data.map((json) => PreventiveMeasure.fromJson(json)).toList();
          yield measures;
        } else {
          print('❌ Failed to load measures: ${response.statusCode}');
          yield [];
        }
      } catch (e) {
        print('❌ Error loading measures for category $categoryId: $e');
        yield [];
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }

  // ✅ Get specific tip by ID
  Future<SafetyTip?> getTipById(int tipId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/safety/tips/$tipId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SafetyTip.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ Error loading tip $tipId: $e');
      return null;
    }
  }

  // ✅ Get specific category by ID
  Future<SafetyCategory?> getCategoryById(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/safety/categories/$categoryId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SafetyCategory.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ Error loading category $categoryId: $e');
      return null;
    }
  }
}