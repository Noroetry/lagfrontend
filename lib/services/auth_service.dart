import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/services/connectivity_service.dart';
// Use the standard http.Client; tests should mock http.Client directly.

class AuthService implements IAuthService {
  final String _baseUrl = AppConfig.usersApiUrl; // URL configurada según entorno
  final http.Client _client;
  final ConnectivityService _connectivity = ConnectivityService();

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
    return await _connectivity.executeWithRetry(
      operationName: 'Login',
      shouldRetry: (error) {
        // Para login, solo reintentar errores de red/timeout
        // NO reintentar errores de credenciales inválidas
        if (error is ApiException) {
          final msg = error.toString().toLowerCase();
          // Si el error menciona credenciales, no reintentar
          if (msg.contains('credenciales')) return false;
          if (msg.contains('credentials')) return false;
          if (msg.contains('contraseña')) return false;
          if (msg.contains('password')) return false;
          if (msg.contains('usuario no encontrado')) return false;
          if (msg.contains('user not found')) return false;
        }
        // Para otros errores, usar la lógica por defecto
        return _connectivity.defaultShouldRetry(error);
      },
      request: () async {
        final response = await _client.post(
          Uri.parse('$_baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usernameOrEmail': usernameOrEmail,
            'password': password
          }),
        ).timeout(ConnectivityService.defaultTimeout);

        if (response.statusCode == 200) {
          try {
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
      },
    );
  }

  @override
  Future<AuthResponse> register(String username, String email, String password) async {
    return await _connectivity.executeWithRetry(
      operationName: 'Register',
      request: () async {
        final response = await _client.post(
          Uri.parse('$_baseUrl/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'email': email,
            'password': password,
          }),
        ).timeout(ConnectivityService.defaultTimeout);

        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
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
      },
    );
  }
  
  // PRIVATE TOKEN ROUTES
  @override
  Future<User> getProfile(String token) async {
    return await _connectivity.executeWithRetry(
      operationName: 'Get Profile',
      request: () async {
        final headers = _authHeadersFromToken(token);
        final response = await _client.get(
          Uri.parse('$_baseUrl/me'),
          headers: headers,
        ).timeout(ConnectivityService.defaultTimeout);

        if (response.statusCode == 200) {
          try {
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
      },
    );
  }

  /// Request a refresh using the server-side cookie (or alternative header/body).
  @override
  Future<AuthResponse> refresh() async {
    return await _connectivity.executeWithRetry(
      operationName: 'Refresh Token',
      request: () async {
        final response = await _client.post(
          Uri.parse('$_baseUrl/refresh'),
          headers: {'Content-Type': 'application/json'},
          // No body by default; server will read cookie or header.
        ).timeout(ConnectivityService.defaultTimeout);

        if (response.statusCode == 200) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is! Map<String, dynamic>) throw ApiException('Unexpected refresh response');
            return AuthResponse.fromJson(decoded);
          } catch (e) {
            debugPrint('❌ [AuthService.refresh] failed to parse response: $e');
            throw ApiException('Fallo al refrescar token: ${response.body}');
          }
        } else if (response.statusCode == 401) {
          throw UnauthorizedException('Refresh token inválido o expirado');
        } else {
          throw ApiException('Fallo al refrescar token: ${response.statusCode}');
        }
      },
      shouldRetry: (error) => error is! UnauthorizedException, // No reintentar si el token es inválido
    );
  }

  @override
  Future<void> ping() async {
    // Usar ConnectivityService para ping con timeout apropiado
    final isConnected = await _connectivity.checkConnectivity(updateState: false);
    if (!isConnected) {
      throw ApiException('Ping failed: No connection');
    }
  }

  @override
  Future<void> logout() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/logout'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Non-fatal: throw to let caller react if desired
    throw ApiException('Fallo logout servidor: ${response.statusCode}');
  }
}