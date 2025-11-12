import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/services/i_message_service.dart';
import 'package:lagfrontend/utils/exceptions.dart';

/// Service responsible for message-related server calls.
class MessageService implements IMessageService {
  final http.Client _client;
  final String _baseUrl = AppConfig.messagesApiUrl;

  MessageService({http.Client? client}) : _client = client ?? http.Client();

  /// Load all messages for a user. Calls POST /api/messages/load with body { userId }.
  /// If [token] is provided it will be sent as a Bearer Authorization header.
  /// Returns a list of Message objects.
  @override
  Future<List<Message>> loadMessages(int userId, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/load');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final requestBody = jsonEncode({'userId': userId});

      final response = await _client.post(uri, headers: headers, body: requestBody);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);

          // Expecting { messages: [...] }
          if (decoded is Map<String, dynamic> && decoded['messages'] is List) {
            final messagesList = decoded['messages'] as List;
            return messagesList.map((json) => Message.fromJson(json as Map<String, dynamic>)).toList();
          }
          
          if (kDebugMode) debugPrint('⚠️ [MessageService] unexpected response format');
          return <Message>[];
        } catch (e) {
          if (kDebugMode) debugPrint('❌ [MessageService] failed to parse response: $e');
          throw ApiException('Fallo al parsear mensajes: $e');
        }
      } else if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('⚠️ [MessageService] 401 response when loading messages');
        throw UnauthorizedException('Acceso denegado al cargar mensajes');
      } else {
        throw ApiException('Fallo al cargar mensajes: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException || e is UnauthorizedException) rethrow;
      if (kDebugMode) debugPrint('❌ [MessageService] error during loadMessages: $e');
      throw ApiException('Error de red al cargar mensajes: $e');
    }
  }

  /// Mark a message as read. Calls POST /api/messages/mark-read with body { userId, messageUserId }.
  /// If [token] is provided it will be sent as a Bearer Authorization header.
  /// Returns the response object { success, alreadyRead }.
  @override
  Future<Map<String, dynamic>> markAsRead(int userId, int messageUserId, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/mark-read');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final requestBody = jsonEncode({'userId': userId, 'messageUserId': messageUserId});

      final response = await _client.post(uri, headers: headers, body: requestBody);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          
          return decoded as Map<String, dynamic>;
        } catch (e) {
          if (kDebugMode) debugPrint('❌ [MessageService] failed to parse mark-read response: $e');
          throw ApiException('Fallo al parsear respuesta de marcar como leído: $e');
        }
      } else if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('⚠️ [MessageService] 401 response when marking message as read');
        throw UnauthorizedException('Acceso denegado al marcar mensaje como leído');
      } else {
        throw ApiException('Fallo al marcar mensaje como leído: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException || e is UnauthorizedException) rethrow;
      if (kDebugMode) debugPrint('❌ [MessageService] error during markAsRead: $e');
      throw ApiException('Error de red al marcar mensaje como leído: $e');
    }
  }
}
