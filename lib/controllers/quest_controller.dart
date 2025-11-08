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
      // Replace or insert activated quests into local list
      if (activated.isNotEmpty) {
        for (final a in activated) {
          try {
            final aId = a is Map && a['id'] != null ? a['id'] : null;
            if (aId != null) {
              final idx = _quests.indexWhere((q) => q is Map && q['id'] == aId);
              if (idx >= 0) {
                _quests[idx] = a;
              } else {
                _quests.add(a);
              }
            }
          } catch (_) {}
        }
        notifyListeners();
      }
      return activated;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [QuestController.activateQuest] error: $e');
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
