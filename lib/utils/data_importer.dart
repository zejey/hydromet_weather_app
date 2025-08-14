import 'package:cloud_firestore/cloud_firestore.dart';

class DataImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> importAllData() async {
    try {
      print('🚀 Starting data import...');

      await _importCategories();
      await _importSafetyTips();
      await _importPreventiveMeasures();

      print('✅ All data imported successfully!');
    } catch (e) {
      print('❌ Error importing data: $e');
    }
  }

  static Future<void> _importCategories() async {
    final categories = {
      'air_quality': {
        'id': 'air_quality',
        'name': 'Air Quality',
        'icon': 'air',
        'gradient_colors': ['#42A5F5', '#1E88E5'],
        'order': 1,
        'is_active': true,
        'description': 'Air Quality Index (AQI) - Health Guidelines',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_index': {
        'id': 'heat_index',
        'name': 'Heat',
        'icon': 'wb_sunny',
        'gradient_colors': ['#FF9800', '#F57C00'],
        'order': 2,
        'is_active': true,
        'description': 'Heat Index - Safety Measures & Health Effects',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_safety': {
        'id': 'flood_safety',
        'name': 'Flood',
        'icon': 'water',
        'gradient_colors': ['#66BB6A', '#43A047'],
        'order': 3,
        'is_active': true,
        'description': 'Flood Safety & Emergency Response Guide',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_safety': {
        'id': 'typhoon_safety',
        'name': 'Typhoon',
        'icon': 'storm',
        'gradient_colors': ['#AB47BC', '#8E24AA'],
        'order': 4,
        'is_active': true,
        'description': 'Typhoon Safety & Preparedness Guide',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    };

    final batch = _firestore.batch();
    categories.forEach((id, data) {
      batch.set(_firestore.collection('safety_categories').doc(id), data);
    });
    await batch.commit();
    print('✅ Categories imported: ${categories.length} documents');
  }

  static Future<void> _importSafetyTips() async {
    final tips = {
      // Air Quality Tips
      'air_good': {
        'category_id': 'air_quality',
        'range': '0-50',
        'level': 'GOOD (Green)',
        'color': '#4CAF50',
        'description':
            '• Air quality is satisfying\n• Outdoor activities are safe\n• No health precautions needed',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_moderate': {
        'category_id': 'air_quality',
        'range': '51-100',
        'level': 'MODERATE (Yellow)',
        'color': '#FFEB3B',
        'description':
            '• Acceptable air quality\n• Sensitive individuals may experience minor symptoms\n• Consider reducing outdoor activities if you\'re sensitive',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_unhealthy_sensitive': {
        'category_id': 'air_quality',
        'range': '101-150',
        'level': 'UNHEALTHY FOR SENSITIVE (Orange)',
        'color': '#FF9800',
        'description':
            '• Children, elderly, and people with respiratory conditions should limit outdoor activities\n• Wear N95 masks if going outside\n• Keep windows closed',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_unhealthy': {
        'category_id': 'air_quality',
        'range': '151-200',
        'level': 'UNHEALTHY (Red)',
        'color': '#F44336',
        'description':
            '• Everyone should avoid prolonged outdoor activities\n• Wear protective masks outdoors\n• Use air purifiers indoors\n• Seek medical attention if experiencing symptoms',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_very_unhealthy': {
        'category_id': 'air_quality',
        'range': '201-300',
        'level': 'VERY UNHEALTHY (Purple)',
        'color': '#9C27B0',
        'description':
            '• Stay indoors with windows and doors closed\n• Avoid all outdoor activities\n• Use air purifiers and masks\n• Emergency health measures may be needed',
        'order': 5,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_hazardous': {
        'category_id': 'air_quality',
        'range': '301+',
        'level': 'HAZARDOUS (Maroon)',
        'color': '#B71C1C',
        'description':
            '• Health emergency - stay indoors immediately\n• Avoid all outdoor exposure\n• Seek immediate medical attention for symptoms\n• Follow official emergency guidelines',
        'order': 6,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Heat Index Tips
      'heat_safe': {
        'category_id': 'heat_index',
        'range': '<26°C',
        'level': 'SAFE (Green)',
        'color': '#4CAF50',
        'description':
            '• No adverse health effects\n• Normal outdoor activities safe\n• Stay hydrated as usual',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_caution': {
        'category_id': 'heat_index',
        'range': '27-32°C',
        'level': 'CAUTION (Yellow)',
        'color': '#FFEB3B',
        'description':
            '• Drink plenty of water every 15-20 minutes\n• Take frequent breaks in shade\n• Watch for signs of heat cramps\n• Avoid prolonged sun exposure',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_extreme_caution': {
        'category_id': 'heat_index',
        'range': '33-41°C',
        'level': 'EXTREME CAUTION (Orange)',
        'color': '#FF9800',
        'description':
            '• Limit outdoor activities between 10AM-4PM\n• Drink water before feeling thirsty\n• Wear light-colored, loose clothing\n• Seek air-conditioned spaces\n• Watch for heat exhaustion symptoms',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_danger': {
        'category_id': 'heat_index',
        'range': '42-51°C',
        'level': 'DANGER (Red)',
        'color': '#F44336',
        'description':
            '• Avoid outdoor activities during peak hours\n• Stay in air-conditioned areas\n• Drink water every 10-15 minutes\n• Apply cold wet cloths to body\n• Call for medical help if feeling unwell',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_extreme_danger': {
        'category_id': 'heat_index',
        'range': '>52°C',
        'level': 'EXTREME DANGER (Dark Red)',
        'color': '#B71C1C',
        'description':
            '• EMERGENCY - Stay indoors immediately\n• Seek immediate air conditioning\n• Apply ice packs to neck, armpits, groin\n• Call emergency services if experiencing heat stroke symptoms\n• Continuous hydration required',
        'order': 5,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Flood Safety Tips
      'flood_level1': {
        'category_id': 'flood_safety',
        'range': '0-0.5m',
        'level': 'ALERT LEVEL 1 (Yellow)',
        'color': '#FFEB3B',
        'description':
            '• Monitor weather updates continuously\n• Prepare emergency kit and evacuation plan\n• Check drainage systems around your area\n• Stay informed through official channels',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_level2': {
        'category_id': 'flood_safety',
        'range': '0.5-1.3m',
        'level': 'ALERT LEVEL 2 (Orange)',
        'color': '#FF9800',
        'description':
            '• Prepare to evacuate immediately\n• Move valuable items to higher areas\n• Ensure family emergency plan is ready\n• Monitor local government announcements',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_level3': {
        'category_id': 'flood_safety',
        'range': '1.3m+',
        'level': 'CRITICAL LEVEL 3 (Red)',
        'color': '#F44336',
        'description':
            '• EVACUATE IMMEDIATELY to nearest evacuation center\n• Do not attempt to cross flood waters\n• Call emergency hotlines if trapped\n• Follow all evacuation orders',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Typhoon Safety Tips
      'typhoon_signal1': {
        'category_id': 'typhoon_safety',
        'range': 'Signal #1',
        'level': 'TROPICAL DEPRESSION (Blue)',
        'color': '#2196F3',
        'description':
            '• Wind Speed: 61 km/h or less\n• Light to moderate damage expected\n• Secure loose objects, check emergency supplies',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_signal2': {
        'category_id': 'typhoon_safety',
        'range': 'Signal #2',
        'level': 'TROPICAL STORM (Yellow)',
        'color': '#FFEB3B',
        'description':
            '• Wind Speed: 62-88 km/h\n• Minor to moderate damage possible\n• Stay indoors, avoid unnecessary travel',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_signal3': {
        'category_id': 'typhoon_safety',
        'range': 'Signal #3',
        'level': 'SEVERE TROPICAL STORM (Orange)',
        'color': '#FF9800',
        'description':
            '• Wind Speed: 89-117 km/h\n• Moderate to heavy damage expected\n• Suspend classes and work, secure all windows',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_signal4': {
        'category_id': 'typhoon_safety',
        'range': 'Signal #4',
        'level': 'TYPHOON (Red)',
        'color': '#F44336',
        'description':
            '• Wind Speed: 118-184 km/h\n• Heavy to very heavy damage expected\n• Complete shutdown, stay in strongest part of house',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_signal5': {
        'category_id': 'typhoon_safety',
        'range': 'Signal #5',
        'level': 'SUPER TYPHOON (Purple)',
        'color': '#9C27B0',
        'description':
            '• Wind Speed: 185 km/h or higher\n• Catastrophic damage expected\n• Emergency shelters, evacuate if ordered',
        'order': 5,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    };

    final batch = _firestore.batch();
    tips.forEach((id, data) {
      batch.set(_firestore.collection('safety_tips').doc(id), data);
    });
    await batch.commit();
    print('✅ Safety tips imported: ${tips.length} documents');
  }

  static Future<void> _importPreventiveMeasures() async {
    final measures = {
      // Air Quality Preventive Measures
      'air_prevent1': {
        'category_id': 'air_quality',
        'number': '01',
        'title': 'Enforce Clean Air Laws',
        'description':
            'Ban open burning, monitor vehicle and factory emissions.',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_prevent2': {
        'category_id': 'air_quality',
        'number': '02',
        'title': 'Greening the City',
        'description': 'Plant more trees, promote biking and walking.',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_prevent3': {
        'category_id': 'air_quality',
        'number': '03',
        'title': 'Public Education',
        'description': 'Teach proper waste disposal and pollution effects.',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'air_prevent4': {
        'category_id': 'air_quality',
        'number': '04',
        'title': 'Air Monitoring',
        'description': 'Install sensors, share air quality updates regularly.',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Heat Index Preventive Measures
      'heat_prevent1': {
        'category_id': 'heat_index',
        'number': '01',
        'title': 'Public Awareness',
        'description':
            'Use social media, radio, and barangay announcements to inform residents about heat advisories and safety tips.',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_prevent2': {
        'category_id': 'heat_index',
        'number': '02',
        'title': 'Hydration & Shade',
        'description':
            'Set up water stations and shaded areas in public places.',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_prevent3': {
        'category_id': 'heat_index',
        'number': '03',
        'title': 'Modified Schedules',
        'description':
            'Adjust school and work hours or shift to online during extreme heat.',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'heat_prevent4': {
        'category_id': 'heat_index',
        'number': '04',
        'title': 'Protect Vulnerable Groups',
        'description':
            'Barangay health workers monitor children, elderly, and those with health conditions.',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Flood Safety Preventive Measures
      'flood_prevent1': {
        'category_id': 'flood_safety',
        'number': '01',
        'title': 'Emergency Kit',
        'description':
            'Keep emergency supplies, important documents, and first aid kit ready.',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_prevent2': {
        'category_id': 'flood_safety',
        'number': '02',
        'title': 'Evacuation Plan',
        'description':
            'Know your evacuation routes and nearest evacuation centers.',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_prevent3': {
        'category_id': 'flood_safety',
        'number': '03',
        'title': 'Stay Informed',
        'description':
            'Monitor weather updates and local government announcements.',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'flood_prevent4': {
        'category_id': 'flood_safety',
        'number': '04',
        'title': 'Secure Property',
        'description':
            'Clear drainage systems and secure outdoor items before flooding.',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },

      // Typhoon Safety Preventive Measures
      'typhoon_prevent1': {
        'category_id': 'typhoon_safety',
        'number': '01',
        'title': 'Spread public awareness',
        'description': 'and early warnings.',
        'order': 1,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_prevent2': {
        'category_id': 'typhoon_safety',
        'number': '02',
        'title': 'Reinforce homes',
        'description': 'and trim nearby trees.',
        'order': 2,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_prevent3': {
        'category_id': 'typhoon_safety',
        'number': '03',
        'title': 'Prepare emergency kits',
        'description': 'and evacuation plans.',
        'order': 3,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'typhoon_prevent4': {
        'category_id': 'typhoon_safety',
        'number': '04',
        'title': 'Conduct disaster drills',
        'description': 'and community education.',
        'order': 4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    };

    final batch = _firestore.batch();
    measures.forEach((id, data) {
      batch.set(_firestore.collection('preventive_measures').doc(id), data);
    });
    await batch.commit();
    print('✅ Preventive measures imported: ${measures.length} documents');
  }
}
