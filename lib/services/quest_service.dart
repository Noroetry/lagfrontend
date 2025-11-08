import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Keep lightweight models separate until backend shape is final.
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/exceptions.dart';

/// Service responsible for quest-related server calls.
class QuestService {
  final http.Client _client;
  final String _baseUrl = AppConfig.questsApiUrl;

  QuestService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch quests for [user]. Calls POST /api/quests/load with body { userId }.
  /// If [token] is provided it will be sent as a Bearer Authorization header.
  /// Returns a raw list of quests as decoded JSON maps. The UI/controller
  /// will decide how to render them. This keeps the frontend flexible while
  /// backend shapes are being finalized.
  Future<List<dynamic>> fetchQuestsForUser(User user, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/load');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final requestBody = jsonEncode({'userId': user.id});
      if (kDebugMode) {
        debugPrint('➡️ [QuestService.fetchQuestsForUser] POST $uri');
        debugPrint('➡️ [QuestService.fetchQuestsForUser] headers: $headers');
        debugPrint('➡️ [QuestService.fetchQuestsForUser] body: $requestBody');
      }

      final response = await _client.post(uri, headers: headers, body: requestBody);

      if (kDebugMode) {
        debugPrint('🔍 [QuestService.fetchQuestsForUser] HTTP ${response.statusCode}');
        debugPrint('🔍 [QuestService.fetchQuestsForUser] raw body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (kDebugMode) debugPrint('🔍 [QuestService.fetchQuestsForUser] decoded JSON: $decoded');

          // Expecting an object like { questsRewarded, quests, assigned, activeQuests }
          // For now return the raw list (maps) so the UI can iterate freely.
          List<dynamic>? rawList;
          if (decoded is Map<String, dynamic>) {
            if (decoded['quests'] is List) {
              rawList = decoded['quests'];
            } else if (decoded['activeQuests'] is List) {
              rawList = decoded['activeQuests'];
            } else if (decoded['assigned'] is List) {
              rawList = decoded['assigned'];
            }
          } else if (decoded is List) {
            rawList = decoded;
          }

          if (rawList == null) return <dynamic>[];
          return rawList.map((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e);
          }).toList();
        } catch (e) {
          if (kDebugMode) debugPrint('❌ [QuestService] failed to parse response: $e');
          throw ApiException('Fallo al parsear quests: $e');
        }
      } else if (response.statusCode == 401) {
        if (kDebugMode) debugPrint('⚠️ [QuestService] 401 response when loading quests');
        throw UnauthorizedException('Acceso denegado al cargar misiones');
      } else {
        throw ApiException('Fallo al cargar misiones: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException || e is UnauthorizedException) rethrow;
      throw ApiException('Error comunicándose con el servidor de quests: $e');
    }
  }

  /// Activate a quest for the user. Sends POST /api/quests/activate with body { userId, questUserId? }
  /// Returns the array `quests` that the backend responds with (usually a single quest object).
  Future<List<dynamic>> activateQuestForUser(User user, dynamic questUserId, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/activate');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) headers['Authorization'] = 'Bearer $token';

  final body = <String, dynamic>{'userId': user.id};
  // Backend expects the quests_users id field named `idQuest` (per controller error message)
  if (questUserId != null) body['idQuest'] = questUserId;

    try {
      if (kDebugMode) {
        debugPrint('➡️ [QuestService.activateQuestForUser] POST $uri');
        debugPrint('➡️ [QuestService.activateQuestForUser] headers: $headers');
        debugPrint('➡️ [QuestService.activateQuestForUser] body: $body');
      }

      final response = await _client.post(uri, headers: headers, body: jsonEncode(body));
      if (kDebugMode) {
        debugPrint('🔍 [QuestService.activateQuestForUser] HTTP ${response.statusCode}');
        debugPrint('🔍 [QuestService.activateQuestForUser] raw body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (kDebugMode) debugPrint('🔍 [QuestService.activateQuestForUser] decoded JSON: $decoded');

        // The backend now returns a consistent `quests` array. Prefer that shape.
        if (decoded is Map<String, dynamic> && decoded['quests'] is List) {
          return List<dynamic>.from(decoded['quests']);
        }
        // If backend returns the array directly, accept it too.
        if (decoded is List) return decoded;

        // Unexpected shape: return empty list to keep callers robust.
        return <dynamic>[];
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Acceso denegado al activar quest');
      } else {
        throw ApiException('Fallo al activar quest: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException || e is UnauthorizedException) rethrow;
      throw ApiException('Error comunicándose con el servidor de quests: $e');
    }
  }

  /// Submit initial parameter values for a quest. Endpoint: POST /submit-params
  /// Body: { userId, idQuest, values: [{ idDetail|id, value }, ...] }
  Future<List<dynamic>> submitParamsForUser(User user, dynamic idQuest, List<dynamic> values, {String? token}) async {
    final uri = Uri.parse('$_baseUrl/submit-params');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final body = <String, dynamic>{'userId': user.id, 'idQuest': idQuest, 'values': values};

    try {
      if (kDebugMode) {
        debugPrint('➡️ [QuestService.submitParamsForUser] POST $uri');
        debugPrint('➡️ [QuestService.submitParamsForUser] headers: $headers');
        debugPrint('➡️ [QuestService.submitParamsForUser] body: $body');
      }

      final response = await _client.post(uri, headers: headers, body: jsonEncode(body));
      if (kDebugMode) {
        debugPrint('🔍 [QuestService.submitParamsForUser] HTTP ${response.statusCode}');
        debugPrint('🔍 [QuestService.submitParamsForUser] raw body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (kDebugMode) debugPrint('🔍 [QuestService.submitParamsForUser] decoded JSON: $decoded');

        // Expect the backend to return a `quests` array consistently.
        if (decoded is Map<String, dynamic> && decoded['quests'] is List) {
          return List<dynamic>.from(decoded['quests']);
        }
        // Accept direct array responses as well.
        if (decoded is List) return decoded;

        // Unexpected shape: return empty list.
        return <dynamic>[];
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Acceso denegado al enviar parámetros de quest');
      } else {
        throw ApiException('Fallo al enviar parámetros de quest: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException || e is UnauthorizedException) rethrow;
      throw ApiException('Error comunicándose con el servidor de quests: $e');
    }
  }
}

