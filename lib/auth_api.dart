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
    try {
      final url = _endpoint('/sys_rohden_medicao/api/login');
      print('DEBUG: Chamando URL: $url');
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      print('DEBUG: Resposta Status: ${response.statusCode}');
      print('DEBUG: Resposta Body: ${response.body}');

      _captureCookie(response);

      final body = response.body;
      final decoded = body.isEmpty ? null : jsonDecode(body);

      if (response.statusCode == 200) {
        return (decoded as Map).cast<String, dynamic>();
      }

      final error = decoded is Map ? (decoded['error']?.toString()) : null;
      throw AuthException(error ?? 'Falha no login (${response.statusCode})');
    } catch (e, stack) {
      print('DEBUG: Erro no login: $e');
      print('DEBUG: StackTrace: $stack');
      if (e is AuthException) rethrow;
      throw AuthException('Erro de conexão. Verifique se o backend está rodando em $baseUrl. Detalhe: $e');
    }
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

  Future<void> recoverPassword(String email) async {
    try {
      final url = _endpoint('/sys_rohden_medicao/api/recover_password');
      print('DEBUG: Chamando URL de recuperação: $url');
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      print('DEBUG: Resposta Status: ${response.statusCode}');
      print('DEBUG: Resposta Body: ${response.body}');

      final body = response.body;
      final decoded = body.isEmpty ? null : jsonDecode(body);

      if (response.statusCode == 200) {
        if (decoded is Map && decoded['success'] == true) {
          return;
        }
        throw AuthException(decoded is Map ? (decoded['message']?.toString() ?? 'Erro ao recuperar senha') : 'Erro ao recuperar senha');
      }

      final error = decoded is Map ? (decoded['message']?.toString() ?? 'Erro desconhecido') : null;
      throw AuthException(error ?? 'Falha na recuperação de senha (${response.statusCode})');
    } catch (e, stack) {
      print('DEBUG: Erro na recuperação: $e');
      print('DEBUG: StackTrace: $stack');
      if (e is AuthException) rethrow;
      throw AuthException('Erro de conexão. Verifique se o backend está rodando. Detalhe: $e');
    }
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
