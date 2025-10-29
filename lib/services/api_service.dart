import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl = 'http://10.0.2.2:3000/api/users';
  final storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      // 🟢 Añadir el encabezado de autorización
      if (token != null) 'Authorization': 'Bearer $token', 
    };
  }

  // Ejemplo de petición protegida: Obtener todos los usuarios
  Future<dynamic> getAllUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/getAll'), // Ruta protegida
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Token expirado o inválido
      throw Exception('Acceso denegado. Token expirado/inválido.');
    } else {
      throw Exception('Fallo al cargar usuarios: ${response.statusCode}');
    }
  }
}