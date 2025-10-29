import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String _baseUrl = 'http://10.0.2.2:3000/api/users'; // URL de tu backend
  final storage = const FlutterSecureStorage();

  // 🟢 1. Función clave para obtener encabezados con el token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token', 
    };
  }

  // --- RUTAS PÚBLICAS (NO REQUIEREN TOKEN) ---
  
  Future<AuthResponse> login(String usernameOrEmail, String password) async { 
    // Las peticiones POST/LOGIN no usan el token de almacenamiento (todavía no existe)
    final response = await http.post(
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
    final response = await http.post(
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
    final response = await http.get(
      Uri.parse('$_baseUrl/getAll'), 
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Manejo de error específico 401
      throw Exception('Acceso denegado. Token expirado/inválido.');
    } else {
      throw Exception('Fallo al cargar usuarios: ${response.statusCode}');
    }
  }
}