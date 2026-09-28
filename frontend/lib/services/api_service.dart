import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBaseUrl = 'https://edulive-yeac.onrender.com';
const String kWsBaseUrl = 'wss://edulive-yeac.onrender.com';

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

  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('saved_user');
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

  /// Toutes les classes publiques (tous enseignants), affichées sur l'écran d'accueil.
  static Future<List<dynamic>> publicClasses() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/public'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> classInfo(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/$classId/info'), headers: _headers);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createClass(
    String name,
    String subject, {
    String? description,
    bool isPrivate = false,
    bool isPaid = false,
    double price = 0,
    String currency = 'XOF',
    String? payoutPhone,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/classes/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'subject': subject,
        'description': description,
        'is_private': isPrivate,
        'is_paid': isPaid,
        'price': price,
        'currency': currency,
        'payout_phone': payoutPhone,
      }),
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

  static Future<List<dynamic>> classStudents(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/$classId/students'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<void> removeStudent(String classId, String studentId) async {
    final res = await http.delete(Uri.parse('$kApiBaseUrl/classes/$classId/students/$studentId'), headers: _headers);
    _handle(res);
  }

  static Future<Map<String, dynamic>> classRevenue(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/$classId/revenue'), headers: _headers);
    return _handle(res);
  }

  // ---------- MUR DE MESSAGES D'UNE CLASSE ----------
  static Future<List<dynamic>> classMessages(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/classes/$classId/messages'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> postClassMessage(
    String classId,
    String content, {
    bool isPrivate = false,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/classes/$classId/messages'),
      headers: _headers,
      body: jsonEncode({'content': content, 'is_private': isPrivate}),
    );
    return _handle(res);
  }

  // ---------- PROGRAMMER / RAPPELS ----------
  static Future<void> setReminder(String classId) async {
    final res = await http.post(Uri.parse('$kApiBaseUrl/classes/$classId/remind'), headers: _headers);
    _handle(res);
  }

  static Future<void> removeReminder(String classId) async {
    final res = await http.delete(Uri.parse('$kApiBaseUrl/classes/$classId/remind'), headers: _headers);
    _handle(res);
  }

  // ---------- NOTIFICATIONS ----------
  static Future<List<dynamic>> myNotifications() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/notifications/mine'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<void> markAllNotificationsRead() async {
    final res = await http.post(Uri.parse('$kApiBaseUrl/notifications/read-all'), headers: _headers);
    _handle(res);
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

  static Future<Map<String, dynamic>> endSession(String sessionId) async {
    final res = await http.post(Uri.parse('$kApiBaseUrl/sessions/$sessionId/end'), headers: _headers);
    return _handle(res);
  }

  static Future<List<dynamic>> sessionsForClass(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/sessions/class/$classId'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<List<dynamic>> chatHistory(String sessionId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/sessions/$sessionId/chat'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  // ---------- UTILISATEURS (cache de noms pour le chat/participants) ----------
  static final Map<String, String> _nameCache = {};

  static Future<String> getUserName(String userId) async {
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/users/$userId'), headers: _headers);
      final data = _handle(res);
      final name = data['full_name'] ?? userId.substring(0, 8);
      _nameCache[userId] = name;
      return name;
    } catch (_) {
      return userId.substring(0, 8);
    }
  }

  // ---------- EXERCICES ----------
  static Future<List<dynamic>> exercisesForClass(String classId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/exercises/class/$classId'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createExercise({
    required String classId,
    required String title,
    required String type,
    required String question,
    List<String>? options,
    String? correctAnswer,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/exercises/'),
      headers: _headers,
      body: jsonEncode({
        'class_id': classId,
        'title': title,
        'type': type,
        'question': question,
        'options': options,
        'correct_answer': correctAnswer,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitAnswer(String exerciseId, String answer) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/exercises/submit'),
      headers: _headers,
      body: jsonEncode({'exercise_id': exerciseId, 'answer': answer}),
    );
    return _handle(res);
  }

  static Future<List<dynamic>> exerciseResults(String exerciseId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/exercises/$exerciseId/results'), headers: _headers);
    return _handle(res) as List<dynamic>;
  }

  // ---------- PAIEMENTS (LeekPay) ----------
  static Future<Map<String, dynamic>> createCheckout(String classId) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/payments/checkout'),
      headers: _headers,
      body: jsonEncode({'class_id': classId}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> paymentStatus(String paymentId) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/payments/$paymentId/status'), headers: _headers);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/payments/wallet'), headers: _headers);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required String method, // mobile_money | card
    required double amount,
    String? phone,
    String? cardInfo,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/payments/withdraw'),
      headers: _headers,
      body: jsonEncode({
        'method': method,
        'amount': amount,
        'phone': phone,
        'card_info': cardInfo,
      }),
    );
    return _handle(res);
  }

  static Future<List<dynamic>> myWithdrawals() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/payments/withdrawals'), headers: _headers);
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
