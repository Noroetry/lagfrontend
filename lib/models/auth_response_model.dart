import 'user_model.dart';

class AuthResponse {
  final User user;
  final String? token; // Si tu backend devuelve un token JWT

  AuthResponse({required this.user, this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user']),
      token: json['token'], // Ajusta si el nombre de la clave es diferente
    );
  }
}