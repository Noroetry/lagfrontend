import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lagfrontend/controllers/messages_controller.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'mocks.dart';
 

import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/models/auth_response_model.dart';

void main() {
  late MockMessagesService mockMessages;
  late MessagesController controller;
  late MockStorage mockStorage;
  late MockAuthService mockAuthService;
  late AuthController authController;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() async {
    mockMessages = MockMessagesService();
    controller = MessagesController(service: mockMessages);

    mockStorage = MockStorage();
    mockAuthService = MockAuthService();

    // Create a dummy user and auth response for AuthController.login
    final user = User(id: 'u1', username: 'u', email: 'u@e.com', isAdmin: false);
    final authResp = AuthResponse(token: 'tok', user: user);

    when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => authResp);
    when(() => mockAuthService.getProfile()).thenAnswer((_) async => user);

    // storage reads/writes used by AuthController
    when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async {});

    authController = AuthController(storage: mockStorage, authService: mockAuthService);
  });

  test('updateAuth loads inbox and sent when authenticated', () async {
    final inbox = [
      Message.fromJson({
        'id': '1',
        'title': 'Hi',
        'description': 'x',
        'source': 'a',
        'destination': 'b',
        'adjunts': null,
        'read': 'N',
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'A'
      })
    ];

    final sent = [
      Message.fromJson({
        'id': 's1',
        'title': 'S',
        'description': null,
        'source': 'me',
        'destination': 'you',
        'adjunts': null,
        'read': 'N',
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'A'
      })
    ];

    when(() => mockMessages.inbox()).thenAnswer((_) async => inbox);
    when(() => mockMessages.sent()).thenAnswer((_) async => sent);

    // Simulate login to make authController authenticated
    await authController.login('u', 'p');
    expect(authController.isAuthenticated, true);

    controller.updateAuth(authController);
    // allow async loads to finish
    await controller.loadInbox();
    await controller.loadSent();

    expect(controller.inbox.length, 1);
    expect(controller.sent.length, 1);
    expect(controller.unreadCount, 1);
    expect(controller.shouldShowUnreadPopup, true);

    // mark popup shown and assert flag clears
    controller.markPopupShown();
    expect(controller.shouldShowUnreadPopup, false);
  });
}
