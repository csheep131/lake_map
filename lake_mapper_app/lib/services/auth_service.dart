import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final bool success;
  final String? token;
  final String? userId;
  final String? error;

  AuthResult({required this.success, this.token, this.userId, this.error});
}

class AuthService {
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
    // Demo-Modus: Akzeptiere bestimmte Logins
    // TODO: Echten Server-Endpunkt nutzen wenn bereit
    final demoUsers = {
      'wammsee': 'angelverein123',
      'test': 'test123',
    };

    if (demoUsers.containsKey(clubId) && demoUsers[clubId] == password) {
      _token = 'demo_token_${DateTime.now().millisecondsSinceEpoch}';
      _userId = clubId;
      _clubId = clubId;

      // Speichern
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_id', _userId!);
      await prefs.setString('club_id', _clubId!);

      return AuthResult(
        success: true,
        token: _token,
        userId: _userId,
      );
    }

    // Echter Server-Check (auskommentiert bis Server bereit)
    /*
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clubId': clubId, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _userId = data['userId'];
        _clubId = clubId;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('club_id', _clubId!);

        return AuthResult(success: true, token: _token, userId: _userId);
      }
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
    */

    return AuthResult(success: false, error: 'Ungültige Club-ID oder Passwort');
  }

  Future<void> logout() async {
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