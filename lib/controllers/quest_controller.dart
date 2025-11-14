import 'package:flutter/foundation.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/services/quest_service.dart';
import 'package:lagfrontend/utils/quest_helpers.dart';

/// Controller that manages quests for the currently authenticated user.
class QuestController extends ChangeNotifier {
  final UserController _userController;
  final QuestService _questService;

  // Store raw quest JSON objects returned by the backend. Keep dynamic so we
  // can adapt quickly while the backend response shape is finalized.
  List<dynamic> _quests = [];
  bool _isLoading = false;
  String? _error;

  QuestController(this._userController, this._questService) {
    // React to user changes - but DON'T auto-load to avoid redundant calls
    // The app will explicitly call loadQuests() after login/register
    _userController.addListener(_onUserChanged);
  }

  List<dynamic> get quests => _quests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _removeQuestById(dynamic questId) {
    final targetId = idAsString(questId);
    if (targetId == null) return false;
    final originalLength = _quests.length;
    _quests.removeWhere((q) {
      if (q is! Map) return false;
      final existingId = idAsString(q['idQuestUser'] ?? q['id']);
      return existingId == targetId;
    });
    return originalLength != _quests.length;
  }

  bool _upsertQuests(List<dynamic> quests) {
    if (quests.isEmpty) return false;
    var changed = false;
    for (final quest in quests) {
      if (quest is! Map) {
        _quests.add(quest);
        changed = true;
        continue;
      }

      final questId = idAsString(quest['idQuestUser'] ?? quest['id']);
      if (questId == null) {
        _quests.add(quest);
        changed = true;
        continue;
      }

      final index = _quests.indexWhere((existing) {
        if (existing is! Map) return false;
        final existingId = idAsString(existing['idQuestUser'] ?? existing['id']);
        return existingId == questId;
      });

      if (index != -1) {
        _quests[index] = quest;
      } else {
        _quests.add(quest);
      }
      changed = true;
    }
    return changed;
  }

  void _onUserChanged() {
    if (!_userController.isAuthenticated) {
      // Only clear quests when user logs out
      _quests = [];
      notifyListeners();
    }
    // When user logs in, main.dart will explicitly call loadQuests()
    // This avoids redundant backend calls
  }

  Future<void> loadQuests() async {
    final user = _userController.currentUser;
    if (user == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
    // Pass auth token from UserController if available so server can authorize the request
    _quests = await _questServiceCall(user);
      } catch (e) {
        _error = e.toString();
        _quests = [];
      } finally {
        _isLoading = false;
        notifyListeners();
    }
  }

  // extracted call to aid logging and keep the main flow readable
  Future<List<dynamic>> _questServiceCall(User user) async {
    try {
      return await _questService.fetchQuestsForUser(user, token: _userController.authToken);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController._quest_service_call] caught error: $e');
      rethrow;
    }
  }

  /// Activate a quest (user accepted). Returns the activated quest(s) from server
  /// and updates the local _quests list replacing the matching questUser id.
  /// NO reloads from backend - HomeScreen will refresh after all popups complete.
  Future<List<dynamic>> activateQuest(dynamic questUserId) async {
    final user = _userController.currentUser;
    if (user == null) throw ArgumentError('No current user');
    try {
      final activated = await _questService.activateQuestForUser(user, questUserId, token: _userController.authToken);

      var changed = false;
      if (activated.isNotEmpty) {
        changed = _upsertQuests(activated);
      } else {
        changed = _removeQuestById(questUserId);
      }

      if (changed && kDebugMode) {
        debugPrint('✅ [QuestController.activateQuest] Updated local quests without reload');
      }
      if (changed) notifyListeners();

      return activated;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController.activateQuest] error: $e');
      rethrow;
    }
  }

  /// Validate parameter values for a quest that requires parameters.
  ///
  /// - [quest]: raw quest object (Map) as received from backend.
  /// - [values]: list of string values provided by the user, in the same order
  ///   as the `details` that have `needParam` true.
  ///
  /// Returns an empty list when validation passes, otherwise returns a list
  /// of human-friendly error messages for each failing parameter.
  List<String> validateParamsForQuest(dynamic quest, List<String> values) {
    final errors = <String>[];
    try {
      final details = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

      final paramDetails = <dynamic>[];
      for (final d in details) {
        if (d is Map && needsParam(d['needParam'])) paramDetails.add(d);
      }

      if (paramDetails.length != values.length) {
        errors.add('Número de parámetros inválido');
        return errors;
      }

      for (var i = 0; i < paramDetails.length; i++) {
        final d = paramDetails[i] as Map;
        // Ensure we have the per-user detail id (idQuestUserDetail) which the backend
        // requires to store values against the correct QuestsUser row.
        final idQuestUserDetail = d['idQuestUserDetail'];
        if (idQuestUserDetail == null) {
          errors.add('Parámetro ${i + 1}: idQuestUserDetail ausente en la configuración de la quest');
          continue;
        }
        final rawType = (d['paramtype'] ?? d['paramType'])?.toString().toLowerCase();
        final v = values[i].trim();
        if (v.isEmpty) {
          errors.add('Parámetro ${i + 1}: requerido');
          continue;
        }
        if (rawType == 'number') {
          if (num.tryParse(v) == null) errors.add('Parámetro ${i + 1}: debe ser un número válido');
        }
        // if rawType == 'text' or unknown, no further validation beyond required
      }
    } catch (e) {
      errors.add('Error validando parámetros: $e');
    }
    return errors;
  }

  /// Toggle a quest detail's checked state. Calls the service and merges the
  /// returned quests payload into the local list, notifying listeners.
  /// NO reloads from backend - state is synchronized locally.
  Future<List<dynamic>> checkQuestDetail({required dynamic idQuestUserDetail, required bool checked}) async {
    final user = _userController.currentUser;
    if (user == null) throw ArgumentError('No current user');

    try {
      final updated = await _questService.checkDetailForUser(user, idQuestUserDetail, checked, token: _userController.authToken);

      final changed = _upsertQuests(updated);
      if (changed && kDebugMode) {
        debugPrint('✅ [QuestController.checkQuestDetail] Updated local quests without reload');
      }
      if (changed) notifyListeners();

      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController.checkQuestDetail] error: $e');
      rethrow;
    }
  }

  /// Submit parameter values for a quest after local validation.
  /// Returns the list of quests returned by the backend (usually updated quest(s)).
  /// NO reloads from backend - HomeScreen will refresh after all popups complete.
  Future<List<dynamic>> submitParamsForQuest(dynamic quest, List<String> inputValues) async {
    final user = _userController.currentUser;
    if (user == null) throw ArgumentError('No current user');

    // Validate first
    final validationErrors = validateParamsForQuest(quest, inputValues);
    if (validationErrors.isNotEmpty) {
      // Surface validation errors to caller
      throw ArgumentError(validationErrors.join('; '));
    }

    // Build values payload expected by backend
    final details = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

    final paramDetails = <dynamic>[];
    for (final d in details) {
      if (d is Map && needsParam(d['needParam'])) paramDetails.add(d);
    }

    if (paramDetails.length != inputValues.length) {
      throw ArgumentError('Número de parámetros inválido');
    }

  final idQuest = quest is Map && quest['idQuestUser'] != null
    ? quest['idQuestUser']
    : (quest is Map && quest['id'] != null ? quest['id'] : null);
  if (idQuest == null) throw ArgumentError('Quest id missing');

    final valuesForBackend = <Map<String, dynamic>>[];
    for (var i = 0; i < paramDetails.length; i++) {
      final d = paramDetails[i] as Map<String, dynamic>;
      final rawType = (d['paramtype'] ?? d['paramType'])?.toString().toLowerCase();
      final rawInput = inputValues[i].trim();
      dynamic finalValue = rawInput;
      if (rawType == 'number') {
        finalValue = num.tryParse(rawInput);
      }
      final idQuestUserDetail = d['idQuestUserDetail'];
      if (idQuestUserDetail == null) {
        // idQuestUserDetail is required for backend storage; fail fast with a clear message
        throw ArgumentError('idQuestUserDetail missing for parameter ${i + 1}');
      }

      // Per backend requirements, place idQuestUserDetail *inside* the `value` field
      // so the server receives: { value: { idQuestUserDetail: ..., value: ... }, idUser, idQuest }
      final entry = <String, dynamic>{
        'value': <String, dynamic>{'idQuestUserDetail': idQuestUserDetail, 'value': finalValue},
        // Keep idUser and idQuest at the entry level so server can locate the QuestsUser row
        'idUser': user.id,
        'idQuest': idQuest,
      };
      valuesForBackend.add(entry);
    }

    try {
      final submitted = await _questService.submitParamsForUser(user, idQuest, valuesForBackend, token: _userController.authToken);

      final changedBySubmit = _upsertQuests(submitted);
      if (changedBySubmit && kDebugMode) {
        debugPrint('✅ [QuestController.submitParamsForQuest] Updated local quests without reload');
      }

      if (changedBySubmit) notifyListeners();
      return submitted;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController.submitParamsForQuest] error: $e');
      rethrow;
    }
  }

  /// Clear resources
  @override
  void dispose() {
    _userController.removeListener(_onUserChanged);
    super.dispose();
  }
}
