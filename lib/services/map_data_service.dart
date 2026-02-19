import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapDataService {
  static const baseUrl = 'https://caring-kindness-production.up.railway.app';

  Future<List<Map<String, dynamic>>> fetchEvacuationCenters() async {
    final res = await http.get(Uri.parse('$baseUrl/api/evacuation-centers/'));
    if (res.statusCode != 200) {
      throw Exception(
          'Evacuation centers error: ${res.statusCode} ${res.body}');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map<Map<String, dynamic>>((e) {
      final m = e as Map<String, dynamic>;
      final lat = (m['lat'] as num).toDouble();
      final lng = (m['lng'] as num).toDouble();
      return {...m, 'location': LatLng(lat, lng)};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchGovernmentAgencies() async {
    final res = await http.get(Uri.parse('$baseUrl/api/government-agencies/'));
    if (res.statusCode != 200) {
      throw Exception(
          'Government agencies error: ${res.statusCode} ${res.body}');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map<Map<String, dynamic>>((e) {
      final m = e as Map<String, dynamic>;

      // backend-hydromet reference shape: location { latitude, longitude }
      if (m['location'] is Map<String, dynamic>) {
        final loc = m['location'] as Map<String, dynamic>;
        final lat = (loc['latitude'] as num).toDouble();
        final lng = (loc['longitude'] as num).toDouble();
        return {...m, 'location': LatLng(lat, lng)};
      }

      // fallback: if API returns lat/lng at top-level instead
      final lat = (m['lat'] as num).toDouble();
      final lng = (m['lng'] as num).toDouble();
      return {...m, 'location': LatLng(lat, lng)};
    }).toList();
  }
}
