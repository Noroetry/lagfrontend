import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';

abstract class IAuthService {
  Future<AuthResponse> login(String usernameOrEmail, String password);
  Future<AuthResponse> register(String username, String email, String password);
  Future<User> getProfile(String token);
}
