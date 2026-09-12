import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Adresse du backend FastAPI. À adapter selon l'environnement
/// (émulateur Android: 10.0.2.2, appareil réel: IP locale, prod: domaine HTTPS).
const String kApiBaseUrl = 'http://10.0.2.2:8000';
const String kWsBaseUrl = 'ws://10.0.2.2:8000';

class ApiService {
  static String? _token;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  static String? get token => _token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ---------- AUTH ----------
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handle(res);
  }

  // ---------- CLASSES ----------
  static Future<List<dynamic>> myClasses() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/mine'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createClass(String name, String subject) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/classes/'),
      headers: _headers,
      body: jsonEncode({'name': name, 'subject': subject}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> joinClass(String inviteCode) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/classes/join'),
      headers: _headers,
      body: jsonEncode({'invite_code': inviteCode}),
    );
    return _handle(res);
  }

  // ---------- SESSIONS LIVE ----------
  static Future<Map<String, dynamic>> createSession(String classId, String title) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/sessions/'),
      headers: _headers,
      body: jsonEncode({'class_id': classId, 'title': title}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> startSession(String sessionId) async {
    final res = await http.post(Uri.parse('$kApiBaseUrl/sessions/$sessionId/start'), headers: _headers);
    return _handle(res);
  }

  static Future<List<dynamic>> sessionsForClass(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/sessions/class/$classId'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  // ---------- HELPERS ----------
  static dynamic _handle(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw Exception(body['detail'] ?? 'Erreur serveur (${res.statusCode})');
  }
}
