import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/models/quest_model.dart';
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
  Future<List<Quest>> fetchQuestsForUser(User user, {String? token}) async {
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

          // Expecting an object like { questsRewarded, assigned, activeQuests }
          // For compatibility, try to extract activeQuests or an array at the root.
          List<dynamic>? rawList;
          if (decoded is Map<String, dynamic>) {
            if (decoded['activeQuests'] is List) {
              rawList = decoded['activeQuests'];
            } else if (decoded['assigned'] is List) {
              rawList = decoded['assigned'];
            }
          } else if (decoded is List) {
            rawList = decoded;
          }

          if (rawList == null) return <Quest>[];
          return rawList.map((e) {
            if (e is Map<String, dynamic>) return Quest.fromJson(e);
            return Quest.fromJson(Map<String, dynamic>.from(e));
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
}

