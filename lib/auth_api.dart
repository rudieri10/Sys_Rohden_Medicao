import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApi {
  AuthApi({required String baseUrl, http.Client? client})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Map<String, String> _headers({required bool json}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    return headers;
  }

  void _captureCookie(http.Response response) {
    // Web: o browser já gerencia cookies automaticamente.
    // Não é necessário extrair e reenviar manualmente.
  }

  Uri _endpoint(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('/sys_rohden_medicao/api/login'),
      headers: _headers(json: true),
      body: jsonEncode({'username': username, 'password': password}),
    );

    _captureCookie(response);

    final body = response.body;
    final decoded = body.isEmpty ? null : jsonDecode(body);

    if (response.statusCode == 200) {
      return (decoded as Map).cast<String, dynamic>();
    }

    final error = decoded is Map ? (decoded['error']?.toString()) : null;
    throw AuthException(error ?? 'Falha no login (${response.statusCode})');
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _client.get(
      _endpoint('/sys_rohden_medicao/api/me'),
      headers: _headers(json: true),
    );

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode == 200) {
      return (decoded as Map).cast<String, dynamic>();
    }

    final error = decoded is Map ? (decoded['error']?.toString()) : null;
    throw AuthException(error ?? 'Sessão inválida (${response.statusCode})');
  }

  Future<void> logout() async {
    final response = await _client.post(
      _endpoint('/sys_rohden_medicao/api/logout'),
      headers: _headers(json: true),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw AuthException('Falha ao sair (${response.statusCode})');
  }

  void dispose() {
    _client.close();
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
