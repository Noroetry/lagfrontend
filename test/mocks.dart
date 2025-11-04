import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/services/messages_service.dart';
import 'package:lagfrontend/services/auth_service.dart';

class MockClient extends Mock implements http.Client {}
class MockStorage extends Mock implements FlutterSecureStorage {}
class MockMessagesService extends Mock implements MessagesService {}
class MockAuthService extends Mock implements AuthService {}

// Fakes for non-primitive argument types
class FakeUri extends Fake implements Uri {}
