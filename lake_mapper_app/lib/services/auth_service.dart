import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final bool success;
  final String? token;
  final String? userId;
  final String? error;

  AuthResult({required this.success, this.token, this.userId, this.error});
}

class AuthService {
  static const _baseUrl = 'https://wammsee.arxlabs.dev';

  String? _token;
  String? _userId;
  String? _clubId;

  String? get token => _token;
  String? get userId => _userId;
  String? get clubId => _clubId;
  bool get isLoggedIn => _token != null;

  Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _clubId = prefs.getString('club_id');
  }

  Future<AuthResult> login(String clubId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': clubId, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _userId = data['username'] ?? clubId;
        _clubId = clubId;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('club_id', _clubId!);

        return AuthResult(success: true, token: _token, userId: _userId);
      } else {
        final data = jsonDecode(response.body);
        return AuthResult(
          success: false,
          error: data['error'] ?? 'Login fehlgeschlagen',
        );
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Server nicht erreichbar: $e');
    }
  }

  Future<void> logout() async {
    // Server-Logout versuchen (optional, Token wird serverseitig invalidiert)
    if (_token != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignorieren, lokal trotzdem ausloggen
      }
    }

    _token = null;
    _userId = null;
    _clubId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('club_id');
  }

  Map<String, String> getAuthHeaders() {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }
}

final authService = AuthService();