import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/services/i_messages_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';
// Use the standard http.Client; tests should mock http.Client directly.

class MessagesService implements IMessagesService {
  final String _baseUrl = AppConfig.messagesApiUrl; // e.g. http://.../api/messages
  final http.Client _client;

  MessagesService({http.Client? client}) : _client = client ?? http.Client();

  // MessagesService no longer reads secure storage. The controller must
  // provide the JWT token for protected requests. Helper to build headers:
  Map<String, String> _authHeadersFromToken(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Send a message (POST /send)
  @override
  Future<Message> send({
    required String token,
    required String title,
    required String description,
    required String destination,
    String? adjunts,
  }) async {
    final headers = _authHeadersFromToken(token);
    final body = jsonEncode({
      'title': title,
      'description': description,
      'destination': destination,
      'adjunts': adjunts,
    });

    final response = await _client.post(Uri.parse('$_baseUrl/send'), headers: headers, body: body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      debugPrint('🔍 [MessagesService.send] raw: ${response.body}');
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return Message.fromJson(decoded);
      throw ApiException('Unexpected send response');
    } else {
      throw ApiException('Failed to send message: ${response.statusCode} ${response.body}');
    }
  }

  /// Inbox (GET /inbox)
  @override
  Future<List<Message>> inbox(String token) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.get(Uri.parse('$_baseUrl/inbox'), headers: headers);
    if (response.statusCode == 200) {
      debugPrint('🔍 [MessagesService.inbox] raw: ${response.body}');
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map<Message>((e) {
          if (e is Map<String, dynamic>) return Message.fromJson(e);
          return Message.fromJson({});
        }).toList();
      }
      throw Exception('Unexpected inbox response shape');
    } else if (response.statusCode == 401) {
      // propagate unauthorized as a special case
      throw UnauthorizedException('Unauthorized');
    } else {
      throw ApiException('Failed to load inbox: ${response.statusCode}');
    }
  }

  /// Sent (GET /sent)
  @override
  Future<List<Message>> sent(String token) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.get(Uri.parse('$_baseUrl/sent'), headers: headers);
    if (response.statusCode == 200) {
      debugPrint('🔍 [MessagesService.sent] raw: ${response.body}');
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map<Message>((e) {
          if (e is Map<String, dynamic>) return Message.fromJson(e);
          return Message.fromJson({});
        }).toList();
      }
      throw Exception('Unexpected sent response shape');
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else {
      throw ApiException('Failed to load sent: ${response.statusCode}');
    }
  }

  /// Get message by id (GET /:id)
  @override
  Future<Message> getById(String token, String id) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.get(Uri.parse('$_baseUrl/$id'), headers: headers);
    if (response.statusCode == 200) {
      debugPrint('🔍 [MessagesService.getById] raw: ${response.body}');
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return Message.fromJson(decoded);
      throw Exception('Unexpected getById response');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden');
    } else if (response.statusCode == 404) {
      throw ApiException('Not found');
    } else {
      throw ApiException('Failed to get message: ${response.statusCode}');
    }
  }

  /// Mark as read (PATCH /:id/read)
  @override
  Future<Message> markRead(String token, String id) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.patch(Uri.parse('$_baseUrl/$id/read'), headers: headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return Message.fromJson(decoded);
      throw Exception('Unexpected markRead response');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden');
    } else {
      throw ApiException('Failed to mark read: ${response.statusCode}');
    }
  }

  /// Change state (PATCH /:id/state) body { state: 'R' }
  @override
  Future<Message> changeState(String token, String id, String state) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.patch(
      Uri.parse('$_baseUrl/$id/state'),
      headers: headers,
      body: jsonEncode({'state': state}),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return Message.fromJson(decoded);
      throw Exception('Unexpected changeState response');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden');
    } else {
      throw ApiException('Failed to change state: ${response.statusCode}');
    }
  }

  /// Soft-delete (DELETE /:id) -> server marks state 'D'
  @override
  Future<Message> deleteMessage(String token, String id) async {
    final headers = _authHeadersFromToken(token);
    final response = await _client.delete(Uri.parse('$_baseUrl/$id'), headers: headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return Message.fromJson(decoded);
      throw Exception('Unexpected delete response');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden');
    } else {
      throw ApiException('Failed to delete message: ${response.statusCode}');
    }
  }
}
