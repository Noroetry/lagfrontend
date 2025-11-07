import 'package:flutter/foundation.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/user_service.dart';

/// Controller dedicated to user/profile state.
class UserController extends ChangeNotifier {
  final UserService _userService;

  User? _currentUser;
  String? _authToken;

  UserController(this._userService);

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;

  /// Set user and optional token. Use when the app obtains the profile.
  void setUser(User user, String? token) {
    _currentUser = user;
    _authToken = token;
    notifyListeners();
  }

  /// Clear local user state.
  void clearUser() {
    _currentUser = null;
    _authToken = null;
    notifyListeners();
  }

  /// Convenience: fetch fresh profile from server using provided token.
  Future<User> refreshProfile(String token) => _userService.getProfile(token);
}
