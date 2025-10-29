import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:lagfrontend/models/auth_response_model.dart';
import 'package:lagfrontend/models/user_model.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}
class MockAuthService extends Mock implements AuthService {}

String base64UrlNoPad(String input) => base64Url.encode(utf8.encode(input)).replaceAll('=', '');

String buildJwt(Map<String, dynamic> payload) {
  final header = jsonEncode({'alg': 'none', 'typ': 'JWT'});
  final payloadJson = jsonEncode(payload);
  final segments = [base64UrlNoPad(header), base64UrlNoPad(payloadJson), 'signature'];
  return segments.join('.');
}

Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 2)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw Exception('waitFor timeout');
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {

  test('Al iniciar con token válido en storage, controller queda autenticado', () async {
    final mockStorage = MockStorage();
    final mockAuthService = MockAuthService();

    // token con exp en el futuro
    final futureExp = (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch / 1000).round();
    final jwt = buildJwt({
      'id': '1',
      'username': 'tester',
      'email': 't@t.com',
      'admin': false,
      'exp': futureExp,
    });

    when(() => mockStorage.read(key: 'jwt_token')).thenAnswer((_) async => jwt);

    final controller = AuthController(storage: mockStorage, authService: mockAuthService);

    // Esperar a que termine el chequeo inicial
    await waitFor(() => controller.isLoading == false);

    expect(controller.isAuthenticated, isTrue);
    expect(controller.currentUser, isNotNull);
    expect(controller.currentUser!.username, 'tester');
    verify(() => mockStorage.read(key: 'jwt_token')).called(1);
  });

  test('Al iniciar con token expirado, se borra y no queda autenticado', () async {
    final mockStorage = MockStorage();
    final mockAuthService = MockAuthService();

    final pastExp = (DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch / 1000).round();
    final jwt = buildJwt({
      'id': '1',
      'username': 'expired',
      'email': 'e@e.com',
      'admin': false,
      'exp': pastExp,
    });

    when(() => mockStorage.read(key: 'jwt_token')).thenAnswer((_) async => jwt);
    when(() => mockStorage.delete(key: 'jwt_token')).thenAnswer((_) async {});

    final controller = AuthController(storage: mockStorage, authService: mockAuthService);

    await waitFor(() => controller.isLoading == false);

    expect(controller.isAuthenticated, isFalse);
    expect(controller.currentUser, isNull);
    verify(() => mockStorage.read(key: 'jwt_token')).called(1);
    verify(() => mockStorage.delete(key: 'jwt_token')).called(1);
  });

  test('login guarda token en storage y autentica', () async {
    final mockStorage = MockStorage();
    final mockAuthService = MockAuthService();

    final user = User(id: '2', username: 'logintest', email: 'l@l.com', isAdmin: false);
    final resp = AuthResponse(user: user, token: 'jwt_from_server');

    when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => resp);
    when(() => mockStorage.write(key: 'jwt_token', value: any(named: 'value'))).thenAnswer((_) async {});

    final controller = AuthController(storage: mockStorage, authService: mockAuthService);

    await controller.login('logintest', 'password');

    expect(controller.isAuthenticated, isTrue);
    expect(controller.currentUser!.username, 'logintest');
    verify(() => mockAuthService.login('logintest', 'password')).called(1);
    verify(() => mockStorage.write(key: 'jwt_token', value: 'jwt_from_server')).called(1);
  });

  test('logout borra token y limpia estado', () async {
    final mockStorage = MockStorage();
    final mockAuthService = MockAuthService();

    when(() => mockStorage.delete(key: 'jwt_token')).thenAnswer((_) async {});

    final controller = AuthController(storage: mockStorage, authService: mockAuthService);

    // Simular estado autenticado en memoria
    // Como los campos son privados, hacemos login con un mock de authService para establecerlos
    final user = User(id: '3', username: 'todel', email: 'd@d.com', isAdmin: false);
    final resp = AuthResponse(user: user, token: 'token_del');
    when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => resp);

    await controller.login('todel', 'pw');
    expect(controller.isAuthenticated, isTrue);

    await controller.logout();

    expect(controller.isAuthenticated, isFalse);
    expect(controller.currentUser, isNull);
    verify(() => mockStorage.delete(key: 'jwt_token')).called(1);
  });
}
