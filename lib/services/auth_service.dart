import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/custom_http_client.dart';

class AuthService implements IAuthService {
  final String _baseUrl = AppConfig.usersApiUrl; // URL configurada según entorno
  final FlutterSecureStorage storage;
  final http.Client _client;

  /// Permite inyectar un storage y cliente HTTP (útil para tests). 
  /// Si no se proveen, se usan las implementaciones por defecto.
  AuthService({
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? CustomHttpClient();

  // 🟢 1. Función clave para obtener encabezados con el token
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final token = await storage.read(key: 'jwt_token');
      debugPrint('🔑 [Auth Headers] Token disponible: ${token != null}');
      return {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (e) {
      // Si falla el storage, devolvemos headers básicos y dejamos que la
      // petición falle de forma habitual (el caller decidirá qué hacer).
      return {'Content-Type': 'application/json'};
    }
  }

  // --- RUTAS PÚBLICAS (NO REQUIEREN TOKEN) ---
  
  @override
  Future<AuthResponse> login(String usernameOrEmail, String password) async { 
    // Las peticiones POST/LOGIN no usan el token de almacenamiento (todavía no existe)
    final dynamic maybe = _client.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usernameOrEmail': usernameOrEmail,
        'password': password
      }),
    );
    final response = maybe is Future ? await maybe as http.Response : maybe as http.Response;

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
    final dynamic maybe = _client.post(
      Uri.parse('$_baseUrl/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    final response = maybe is Future ? await maybe as http.Response : maybe as http.Response;

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
  
  // --- RUTAS PRIVADAS (REQUIEREN TOKEN) ---

  // 🟢 2. Ejemplo de ruta protegida: Obtener todos los usuarios
  @override
  Future<dynamic> getAllUsers() async {
    final headers = await _getAuthHeaders(); // <-- Usa el token guardado
    final dynamic maybe = _client.get(
      Uri.parse('$_baseUrl/getAll'),
      headers: headers,
    );
    final response = maybe is Future ? await maybe as http.Response : maybe as http.Response;

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      debugPrint('⚠️ [Auth Error] Recibido 401 del servidor');
      // Si el backend indica 401, borramos el token local (centralizado)
      try {
        await storage.delete(key: 'jwt_token');
        debugPrint('🗑️ [Auth Error] Token borrado del storage');
      } catch (_) {
        debugPrint('❌ [Auth Error] Error al borrar token');
        // Ignoramos errores de borrado: lo importante es propagar la excepción
      }
      throw UnauthorizedException('Acceso denegado. Token expirado/inválido.');
    } else {
      throw ApiException('Fallo al cargar usuarios: ${response.statusCode}');
    }
  }

  /// Valida el token con el backend y devuelve el perfil del usuario (/me).
  @override
  Future<User> getProfile() async {
    final headers = await _getAuthHeaders();
    final dynamic maybe = _client.get(
      Uri.parse('$_baseUrl/me'),
      headers: headers,
    );
    final response = maybe is Future ? await maybe as http.Response : maybe as http.Response;

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
      // Token inválido en backend: limpiar storage y propagar
      try {
        await storage.delete(key: 'jwt_token');
      } catch (_) {}
      throw UnauthorizedException('Acceso denegado. Token inválido en servidor.');
    } else {
      throw ApiException('Fallo al obtener perfil: ${response.statusCode}');
    }
  }
}