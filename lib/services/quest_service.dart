import 'package:lagfrontend/models/quest_model.dart';
import 'package:lagfrontend/models/user_model.dart';

/// Service responsible for quest-related server calls.
/// Minimal stub while quest subsystem is not implemented.
class QuestService {
  QuestService();

  /// Fetch quests for [user]. Currently returns an empty list — implement
  /// server integration when the quest API and contract are defined.
  Future<List<Quest>> fetchQuestsForUser(User user) async {
    return <Quest>[];
  }
}

