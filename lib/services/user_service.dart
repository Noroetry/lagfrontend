import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';

/// Thin wrapper around [IAuthService] to host user-related server calls.
class UserService {
  final IAuthService _authService;

  UserService(this._authService);

  Future<User> getProfile(String token) => _authService.getProfile(token);
}
