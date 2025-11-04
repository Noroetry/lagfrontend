import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:lagfrontend/services/messages_service.dart';
import 'package:lagfrontend/models/message_model.dart';

import 'mocks.dart';

void main() {
  late MockClient client;
  late MockStorage storage;
  late MessagesService service;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    client = MockClient();
    storage = MockStorage();
    service = MessagesService(storage: storage, client: client);
  });

  group('MessagesService', () {
    test('inbox parses message list and maps read flag', () async {
      final sample = [
        {
          'id': 123,
          'title': 'Hello',
          'description': 'desc',
          'source': 'userA',
          'destination': 'userB',
          'adjunts': null,
          'read': 'N',
          'dateRead': null,
          'dateSent': DateTime.now().toIso8601String(),
          'state': 'A'
        }
      ];

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'fake-token');
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response(jsonEncode(sample), 200),
      );

      final inbox = await service.inbox();
      expect(inbox, isA<List<Message>>());
      expect(inbox.length, 1);
      expect(inbox.first.read, false);
      expect(inbox.first.title, 'Hello');
      expect(inbox.first.id, '123');
    });

    test('send returns created message', () async {
      final msg = {
        'id': 'abc',
        'title': 'Title',
        'description': 'body',
        'source': 'me',
        'destination': 'you',
        'adjunts': null,
        'read': 'N',
        'dateRead': null,
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'A'
      };

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'fake-token');
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response(jsonEncode(msg), 201),
      );

      final res = await service.send(title: 'Title', description: 'body', destination: 'you');
      expect(res, isA<Message>());
      expect(res.id, 'abc');
      expect(res.title, 'Title');
    });

    test('markRead returns message with read true', () async {
      final updated = {
        'id': 'm1',
        'title': 'T',
        'description': null,
        'source': 'a',
        'destination': 'b',
        'adjunts': null,
        'read': 'S',
        'dateRead': DateTime.now().toIso8601String(),
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'A'
      };

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'fake-token');
      when(() => client.patch(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response(jsonEncode(updated), 200),
      );

      final res = await service.markRead('m1');
      expect(res.read, true);
      expect(res.id, 'm1');
    });

    test('changeState returns updated message', () async {
      final updated = {
        'id': 'm2',
        'title': 'T2',
        'description': null,
        'source': 'a',
        'destination': 'b',
        'adjunts': null,
        'read': 'N',
        'dateRead': null,
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'R'
      };

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'fake-token');
      when(() => client.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => http.Response(jsonEncode(updated), 200),
      );

      final res = await service.changeState('m2', 'R');
      expect(res.state, 'R');
      expect(res.id, 'm2');
    });

    test('deleteMessage returns soft-deleted message', () async {
      final updated = {
        'id': 'm3',
        'title': 'T3',
        'description': null,
        'source': 'a',
        'destination': 'b',
        'adjunts': null,
        'read': 'N',
        'dateRead': null,
        'dateSent': DateTime.now().toIso8601String(),
        'state': 'D'
      };

      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'fake-token');
      when(() => client.delete(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response(jsonEncode(updated), 200),
      );

      final res = await service.deleteMessage('m3');
      expect(res.state, 'D');
      expect(res.id, 'm3');
    });
  });
}
