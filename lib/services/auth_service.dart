import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';
import 'package:lagfrontend/config/app_config.dart';
// Use the standard http.Client; tests should mock http.Client directly.

class AuthService implements IAuthService {
  final String _baseUrl = AppConfig.usersApiUrl; // URL configurada según entorno
  final http.Client _client;

  AuthService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _authHeadersFromToken(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // PUBLIC NO TOKEN ROUTES
  @override
  Future<AuthResponse> login(String usernameOrEmail, String password) async { 
    // Las peticiones POST/LOGIN no usan el token de almacenamiento (todavía no existe)
    final response = await _client.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usernameOrEmail': usernameOrEmail,
        'password': password
      }),
    );

    if (response.statusCode == 200) {
      try {
        debugPrint('🔍 [AuthService.login] raw body: ${response.body}');
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw ApiException('Unexpected login response shape');
        return AuthResponse.fromJson(decoded);
      } catch (e) {
        debugPrint('❌ [AuthService.login] failed to parse login response: $e');
        throw ApiException('Fallo el inicio de sesión: ${response.body}');
      }
    } else {
      throw ApiException('Fallo el inicio de sesión: ${response.body}');
    }
  }

  @override
  Future<AuthResponse> register(String username, String email, String password) async {
    // Las peticiones POST/REGISTER no usan el token de almacenamiento
    final response = await _client.post(
      Uri.parse('$_baseUrl/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        debugPrint('🔍 [AuthService.register] raw body: ${response.body}');
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw ApiException('Unexpected register response shape');
        return AuthResponse.fromJson(decoded);
      } catch (e) {
        debugPrint('❌ [AuthService.register] failed to parse register response: $e');
        throw ApiException('Fallo el registro: ${response.body}');
      }
    } else {
      throw ApiException('Fallo el registro: ${response.body}');
    }
  }
  
  // PRIVATE TOKEN ROUTES
  @override
  Future<User> getProfile(String token) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.get(
      Uri.parse('$_baseUrl/me'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      try {
        debugPrint('🔍 [AuthService.getProfile] raw body: ${response.body}');
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw ApiException('Unexpected /me response shape: not an object');
        }
        return User.fromJson(decoded);
      } catch (e) {
        debugPrint('❌ [AuthService.getProfile] failed to parse /me response: $e');
        throw ApiException('Fallo al obtener perfil: ${response.statusCode}');
      }
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Acceso denegado. Token inválido en servidor.');
    } else {
      throw ApiException('Fallo al obtener perfil: ${response.statusCode}');
    }
  }
}