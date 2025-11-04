import 'dart:convert';
import 'user_model.dart';

class AuthResponse {
  final User user;
  final String? token; // Si tu backend devuelve un token JWT

  AuthResponse({required this.user, this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: ensure 'user' exists and is a Map
    final rawUser = json['user'];
    if (rawUser == null) {
      throw Exception('AuthResponse.fromJson: missing "user" field. Raw: ${jsonEncode(json)}');
    }
    if (rawUser is! Map<String, dynamic>) {
      throw Exception('AuthResponse.fromJson: "user" is not an object. Raw: ${jsonEncode(json)}');
    }

    try {
      return AuthResponse(
        user: User.fromJson(rawUser),
        token: json['token']?.toString(),
      );
    } catch (e) {
      throw Exception('AuthResponse.fromJson: failed to parse user: $e; Raw: ${jsonEncode(json)}');
    }
  }
}