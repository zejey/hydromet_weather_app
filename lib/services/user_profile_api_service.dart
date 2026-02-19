import 'dart:convert';
import 'package:http/http.dart' as http;

class UserProfileApiService {
  static const String _apiBaseUrl =
      "https://caring-kindness-production.up.railway.app";

  Future<Map<String, dynamic>> fetchUser(String userId) async {
    final res = await http.get(Uri.parse('$_apiBaseUrl/api/users/$userId'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load user: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(
      String userId, Map<String, dynamic> payload) async {
    final res = await http.put(
      Uri.parse('$_apiBaseUrl/api/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update user: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
