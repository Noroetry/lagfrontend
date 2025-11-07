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
    if (kDebugMode) {
      debugPrint('🔐 [UserController.setUser] userId=${user.id} username=${user.username} tokenPresent=${token != null}');
    }
    notifyListeners();
  }

  /// Clear local user state.
  void clearUser() {
    if (kDebugMode) debugPrint('🗑️ [UserController.clearUser] clearing local user state');
    _currentUser = null;
    _authToken = null;
    notifyListeners();
  }

  /// Convenience: fetch fresh profile from server using provided token.
  Future<User> refreshProfile(String token) async {
  if (kDebugMode) debugPrint('🔄 [UserController.refreshProfile] requesting profile with tokenPresent=${token.isNotEmpty}');
    final profile = await _userService.getProfile(token);
    if (kDebugMode) debugPrint('🔄 [UserController.refreshProfile] received profile: id=${profile.id} username=${profile.username}');
    return profile;
  }
}
