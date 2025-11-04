import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/services/auth_service.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  test('Login with reserved username is rejected client-side', () async {
    final mockStorage = MockStorage();
    final mockAuth = MockAuthService();

    final controller = AuthController(storage: mockStorage, authService: mockAuth);

    await controller.login('system', 'irrelevant');

    expect(controller.isAuthenticated, isFalse);
    expect(controller.errorMessage, contains('no está permitido'));
    verifyNever(() => mockAuth.login(any(), any()));
  });

  test('Register with reserved username is rejected client-side', () async {
    final mockStorage = MockStorage();
    final mockAuth = MockAuthService();

    final controller = AuthController(storage: mockStorage, authService: mockAuth);

    await controller.registerAndLogin('system', 'sys@x.com', 'pw');

    expect(controller.isAuthenticated, isFalse);
    expect(controller.errorMessage, contains('no está permitido'));
    verifyNever(() => mockAuth.register(any(), any(), any()));
  });
}
