import 'package:flutter/foundation.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/services/quest_service.dart';

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
    // react to user changes
    _userController.addListener(_onUserChanged);
    // if there's already a user, try to load quests
    if (_userController.isAuthenticated) {
      loadQuests();
    }
  }

  List<dynamic> get quests => _quests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _onUserChanged() {
    if (_userController.isAuthenticated) {
      loadQuests();
    } else {
      // clear quests when user logs out
      _quests = [];
      notifyListeners();
    }
  }

  Future<void> loadQuests() async {
    final user = _userController.currentUser;
    if (user == null) return;
    _isLoading = true;
    _error = null;
    if (kDebugMode) debugPrint('🧭 [QuestController.loadQuests] starting for userId=${user.id} tokenPresent=${_userController.authToken != null}');
    notifyListeners();

    try {
  // Pass auth token from UserController if available so server can authorize the request
  _quests = await _questServiceCall(user);
  if (kDebugMode) debugPrint('🔎 [QuestController] raw quests: $_quests');
      if (kDebugMode) debugPrint('✅ [QuestController.loadQuests] loaded ${_quests.length} quests');
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('❌ [QuestController.loadQuests] error: $_error');
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
  Future<List<dynamic>> activateQuest(dynamic questUserId) async {
    final user = _userController.currentUser;
    if (user == null) throw ArgumentError('No current user');
    try {
      final activated = await _questService.activateQuestForUser(user, questUserId, token: _userController.authToken);
      
      // Force a full reload from backend to ensure we get correct dateExpiration
      // (especially for weekdays quests where backend calculates next valid day)
      await loadQuests();
      
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

      bool needsParam(Object? v) {
        if (v == null) return false;
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.trim().toLowerCase();
          return s == 'true' || s == '1' || s == 'yes' || s == 'y';
        }
        return false;
      }

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
  Future<List<dynamic>> checkQuestDetail({required dynamic idQuestUserDetail, required bool checked}) async {
    final user = _userController.currentUser;
    if (user == null) throw ArgumentError('No current user');

    try {
      final updated = await _questService.checkDetailForUser(user, idQuestUserDetail, checked, token: _userController.authToken);

      // Force a full reload from backend to ensure we get correct dateExpiration
      // (especially for weekdays quests where backend calculates next valid day)
      await loadQuests();

      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController.checkQuestDetail] error: $e');
      rethrow;
    }
  }

  /// Submit parameter values for a quest after local validation.
  /// Returns the list of quests returned by the backend (usually updated quest(s)).
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
    bool needsParam(Object? v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
      }
      return false;
    }

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

      // Force a full reload from backend to ensure we get correct dateExpiration
      // (especially for weekdays quests where backend calculates next valid day)
      await loadQuests();

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
