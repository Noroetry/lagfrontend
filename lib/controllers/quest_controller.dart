import 'package:flutter/foundation.dart';
import 'package:lagfrontend/models/quest_model.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/services/quest_service.dart';

/// Controller that manages quests for the currently authenticated user.
class QuestController extends ChangeNotifier {
  final UserController _userController;
  final QuestService _questService;

  List<Quest> _quests = [];
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

  List<Quest> get quests => _quests;
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
    notifyListeners();

    try {
      _quests = await _questService.fetchQuestsForUser(user);
    } catch (e) {
      _error = e.toString();
      _quests = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear resources
  @override
  void dispose() {
    _userController.removeListener(_onUserChanged);
    super.dispose();
  }
}
