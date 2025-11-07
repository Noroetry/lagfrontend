import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/utils/secure_storage_adapter.dart';
import 'package:lagfrontend/utils/exceptions.dart';

class FakeStorage implements SecureStorage {
  final Map<String, String> _map = {};
  @override
  Future<void> delete(String key) async => _map.remove(key);
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

/// Helper to build a simple unsigned JWT with a given expiration (seconds since epoch)
String makeJwt({required int exp}) {
  String base64EncodeUnpadded(String s) {
    return base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  }

  final header = base64EncodeUnpadded(jsonEncode({'alg': 'none', 'typ': 'JWT'}));
  final payload = base64EncodeUnpadded(jsonEncode({'exp': exp}));
  return '$header.$payload.'; // empty signature
}

class FakeAuthService implements IAuthService {
  final bool refreshShouldSucceed;
  String? lastRequestedToken;
  FakeAuthService({this.refreshShouldSucceed = true});

  @override
  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    final user = User(id: '1', username: usernameOrEmail, email: '$usernameOrEmail@x.com', adminLevel: 0);
    // Simulate backend returning no access token but maybe setting refresh cookie
    return AuthResponse(user: user, token: null);
  }

  @override
  Future<AuthResponse> register(String username, String email, String password) {
    throw UnimplementedError();
  }

  @override
  Future<User> getProfile(String token) async {
    lastRequestedToken = token;
    if (token == 'bad') throw UnauthorizedException('bad');
    return User(id: '1', username: 'u', email: 'u@x', adminLevel: 0);
  }

  @override
  Future<AuthResponse> refresh() async {
    if (!refreshShouldSucceed) throw UnauthorizedException('refresh failed');
    final user = User(id: '1', username: 'u', email: 'u@x', adminLevel: 0);
    return AuthResponse(user: user, token: 'new_access_token');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> ping() async {
    // Always succeed in tests unless overridden in a different fake.
    return;
  }
}

void main() {
  test('login uses refresh when no access token returned', () async {
    final storage = FakeStorage();
    final authService = FakeAuthService(refreshShouldSucceed: true);
    final ctrl = AuthController(storage: storage, authService: authService);

    await ctrl.login('bob', 'pass');

    expect(ctrl.authToken, 'new_access_token');
    final stored = await storage.read('jwt_token');
    expect(stored, 'new_access_token');
    expect(ctrl.currentUser, isNotNull);
  });

  test('checkAuthenticationStatus refreshes if token near expiry', () async {
    final storage = FakeStorage();
    final authService = FakeAuthService(refreshShouldSucceed: true);
    // create a token that expires in 60 seconds
    final exp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 60;
    final token = makeJwt(exp: exp);

    await storage.write('jwt_token', token);
    final ctrl = AuthController(storage: storage, authService: authService);

    // call explicitly
    await ctrl.checkAuthenticationStatus();

    expect(ctrl.authToken, 'new_access_token');
    final stored = await storage.read('jwt_token');
    expect(stored, 'new_access_token');
  });

  test('failed refresh clears authentication', () async {
    final storage = FakeStorage();
    final authService = FakeAuthService(refreshShouldSucceed: false);
    final exp = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 60;
    final token = makeJwt(exp: exp);
    await storage.write('jwt_token', token);

    final ctrl = AuthController(storage: storage, authService: authService);
    await ctrl.checkAuthenticationStatus();

    expect(ctrl.authToken, isNull);
    expect(ctrl.currentUser, isNull);
  });
}
