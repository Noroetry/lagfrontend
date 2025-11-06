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
      // Try to locate token in multiple possible fields for robustness
      String? token;
      if (json['token'] != null) token = json['token'].toString();
      token ??= json['accessToken']?.toString();
      token ??= json['access_token']?.toString();
      // Some backends may embed the access token inside the user object
      if (token == null) {
        final candidate = rawUser['token'] ?? rawUser['accessToken'] ?? rawUser['access_token'];
        if (candidate != null) token = candidate.toString();
      }

      return AuthResponse(
        user: User.fromJson(rawUser),
        token: token,
      );
    } catch (e) {
      throw Exception('AuthResponse.fromJson: failed to parse user: $e; Raw: ${jsonEncode(json)}');
    }
  }
}