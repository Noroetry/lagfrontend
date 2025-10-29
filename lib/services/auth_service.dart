import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

class AuthService {
  final String _baseUrl = 'http://10.0.2.2:3000/api/users'; // URL de tu backend
  FlutterSecureStorage storage;
  final http.Client _client;

  /// Permite inyectar un storage y cliente HTTP (útil para tests). 
  /// Si no se proveen, se usan las implementaciones por defecto.
  AuthService({
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client();

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
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Fallo el inicio de sesión: ${response.body}');
    }
  }

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
      return AuthResponse.fromJson(jsonDecode(response.body)); 
    } else {
      throw Exception('Fallo el registro: ${response.body}');
    }
  }
  
  // --- RUTAS PRIVADAS (REQUIEREN TOKEN) ---

  // 🟢 2. Ejemplo de ruta protegida: Obtener todos los usuarios
  Future<dynamic> getAllUsers() async {
    final headers = await _getAuthHeaders(); // <-- Usa el token guardado
    final response = await _client.get(
      Uri.parse('$_baseUrl/getAll'),
      headers: headers,
    );

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
      throw Exception('Fallo al cargar usuarios: ${response.statusCode}');
    }
  }
}