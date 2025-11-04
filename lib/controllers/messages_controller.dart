import 'package:flutter/foundation.dart';
import 'package:lagfrontend/services/i_messages_service.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';

class MessagesController extends ChangeNotifier {
  final IMessagesService _service;
  List<Message> inbox = [];
  List<Message> sent = [];
  bool _loaded = false;
  bool _popupShown = false; // whether we've already shown the unread popup

  MessagesController({IMessagesService? service}) : _service = service ?? (throw ArgumentError.notNull('service'));

  // Called by ChangeNotifierProxyProvider to inform about auth changes
  void updateAuth(AuthController? auth) {
    if (auth != null && auth.isAuthenticated && !_loaded) {
      // Load inbox/sent lazily
      loadInbox();
      loadSent();
    }
    if (auth == null || !auth.isAuthenticated) {
      // Reset on logout
      inbox = [];
      sent = [];
      _loaded = false;
      _popupShown = false;
      notifyListeners();
    }
  }

  Future<void> loadInbox() async {
    try {
      final list = await _service.inbox();
      inbox = list;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MessagesController] loadInbox failed: $e');
    }
  }

  Future<void> loadSent() async {
    try {
      final list = await _service.sent();
      sent = list;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MessagesController] loadSent failed: $e');
    }
  }

  int get unreadCount => inbox.where((m) => !m.read && m.state == 'A').length;

  bool get shouldShowUnreadPopup => !_popupShown && unreadCount > 0;

  void markPopupShown() {
    _popupShown = true;
    notifyListeners();
  }

  // Proxy methods that update local cache after performing service calls
  Future<Message?> markRead(String id) async {
    try {
      final updated = await _service.markRead(id);
      final idx = inbox.indexWhere((m) => m.id == id);
      if (idx != -1) inbox[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint('❌ [MessagesController] markRead failed: $e');
      return null;
    }
  }

  Future<Message?> changeState(String id, String state) async {
    try {
      final updated = await _service.changeState(id, state);
      // update in both lists
      final iidx = inbox.indexWhere((m) => m.id == id);
      if (iidx != -1) inbox[iidx] = updated;
      final sidx = sent.indexWhere((m) => m.id == id);
      if (sidx != -1) sent[sidx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint('❌ [MessagesController] changeState failed: $e');
      return null;
    }
  }

  Future<Message?> sendMessage({required String title, required String description, required String destination, String? adjunts}) async {
    try {
      final m = await _service.send(title: title, description: description, destination: destination, adjunts: adjunts);
      // append to sent
      sent.insert(0, m);
      notifyListeners();
      return m;
    } catch (e) {
      debugPrint('❌ [MessagesController] sendMessage failed: $e');
      return null;
    }
  }

  Future<Message?> deleteMessage(String id) async {
    try {
      final updated = await _service.deleteMessage(id);
      final iidx = inbox.indexWhere((m) => m.id == id);
      if (iidx != -1) inbox[iidx] = updated;
      final sidx = sent.indexWhere((m) => m.id == id);
      if (sidx != -1) sent[sidx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint('❌ [MessagesController] deleteMessage failed: $e');
      return null;
    }
  }
}
