import 'dart:convert';
import 'package:http/http.dart' as http;

class BarangayApiService {
  static const String _apiBaseUrl =
      "https://caring-kindness-production.up.railway.app";

  Future<List<String>> fetchBarangayNames({bool activeOnly = true}) async {
    final uri = Uri.parse('$_apiBaseUrl/api/barangays?active_only=$activeOnly');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load barangays: ${res.statusCode} ${res.body}');
    }

    // ✅ Force UTF-8 decoding to avoid "NiÃ±o"
    final decodedBody = utf8.decode(res.bodyBytes);
    final decoded = jsonDecode(decodedBody) as List<dynamic>;

    return decoded
        .map((e) => (e as Map<String, dynamic>)['name'].toString())
        .toList();
  }
}
