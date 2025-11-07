import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';

abstract class IAuthService {
  Future<AuthResponse> login(String usernameOrEmail, String password);
  Future<AuthResponse> register(String username, String email, String password);
  Future<User> getProfile(String token);
  /// Attempt to refresh the access token using the server-side refresh token (cookie).
  /// Returns an [AuthResponse] containing the new access token and user if successful.
  Future<AuthResponse> refresh();

  Future<void> ping();

  /// Call server logout endpoint to invalidate refresh token on server.
  Future<void> logout();
}
