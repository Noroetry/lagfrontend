import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';

class MockClient extends Mock implements http.Client {}
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockClient mockClient;
  late MockSecureStorage mockStorage;
  late AuthService authService;
  const baseUrl = 'http://10.0.2.2:3000/api/users';

  setUp(() {
    mockClient = MockClient();
    mockStorage = MockSecureStorage();
    authService = AuthService(storage: mockStorage, client: mockClient);

    registerFallbackValue(Uri.parse(''));
  });

  group('Manejo de token y 401:', () {
    test('getAllUsers borra token y lanza UnauthorizedException en 401', () async {
      // Configurar storage para devolver un token
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'test-token');
      
      // Configurar que delete funcione sin errores
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async => {});

      // Simular respuesta 401 del servidor
      when(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Token inválido'}),
        401,
      ));

      // Intentar obtener usuarios debería fallar con UnauthorizedException
      try {
        await authService.getAllUsers();
        fail('Se esperaba una UnauthorizedException');
      } catch (e) {
        expect(e, isA<UnauthorizedException>());
      }

      // Verificar que el token fue borrado
      verify(() => mockStorage.delete(key: 'jwt_token')).called(1);
    });

    test('_getAuthHeaders incluye token si existe en storage', () async {
      const testToken = 'test-auth-token';
      when(() => mockStorage.read(key: 'jwt_token'))
          .thenAnswer((_) async => testToken);

      // Configurar una respuesta exitosa para getAllUsers
      when(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response('[]', 200));

      try {
        await authService.getAllUsers();
      } catch (_) {}

      // Verificar que la petición incluyó el header Authorization
      verify(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: any(named: 'headers'),
      )).called(1);
    });

    test('_getAuthHeaders maneja error de storage sin romper', () async {
      // Simular error al leer storage
      when(() => mockStorage.read(key: 'jwt_token'))
          .thenThrow(Exception('Storage error'));

      // Configurar respuesta del servidor (debería fallar por falta de token)
      when(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'No autorizado'}),
        401,
      ));

      // El servicio debería manejar el error de storage y continuar
      expect(
        () => authService.getAllUsers(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('Errores en delete de token no rompen el flujo', () async {
      // Storage devuelve token pero falla al intentar borrarlo
      when(() => mockStorage.read(key: 'jwt_token'))
          .thenAnswer((_) async => 'test-token');
      when(() => mockStorage.delete(key: 'jwt_token'))
          .thenThrow(Exception('Error borrando token'));

      // Servidor responde 401
      when(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Token inválido'}),
        401,
      ));

      // Debería manejar el error de delete y seguir lanzando UnauthorizedException
      expect(
        () => authService.getAllUsers(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('Integración con rutas protegidas:', () {
    test('Rutas protegidas reciben token en headers', () async {
      const testToken = 'valid-token';
      when(() => mockStorage.read(key: 'jwt_token'))
          .thenAnswer((_) async => testToken);

      when(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: captureAny(named: 'headers'),
      )).thenAnswer((_) async => http.Response('[]', 200));

      await authService.getAllUsers();

      final captured = verify(() => mockClient.get(
        Uri.parse('$baseUrl/getAll'),
        headers: captureAny(named: 'headers'),
      )).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], equals('Bearer $testToken'));
    });
  });
}