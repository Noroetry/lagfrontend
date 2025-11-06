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
  /// Temporary flag to enable/disable message popups while feature is incomplete.
  /// Set to `false` to disable popup behavior; set to `true` to restore.
  bool messagesActive = false;
  String? _token;

  MessagesController({IMessagesService? service}) : _service = service ?? (throw ArgumentError.notNull('service'));

  // Called by ChangeNotifierProxyProvider to inform about auth changes
  void updateAuth(AuthController? auth) {
    if (auth != null && auth.isAuthenticated && !_loaded) {
      // Load inbox/sent lazily
      _token = auth.authToken;
      loadInbox();
      loadSent();
    }
    if (auth == null || !auth.isAuthenticated) {
      // Reset on logout
      inbox = [];
      sent = [];
      _loaded = false;
      _popupShown = false;
      _token = null;
      notifyListeners();
    }
  }

  Future<void> loadInbox() async {
    try {
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for inbox');
        return;
      }
      final list = await _service.inbox(_token!);
      inbox = list;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MessagesController] loadInbox failed: $e');
    }
  }

  Future<void> loadSent() async {
    try {
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for sent');
        return;
      }
      final list = await _service.sent(_token!);
      sent = list;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MessagesController] loadSent failed: $e');
    }
  }

  int get unreadCount => inbox.where((m) => !m.read && m.state == 'A').length;

  bool get shouldShowUnreadPopup => messagesActive && !_popupShown && unreadCount > 0;

  void markPopupShown() {
    _popupShown = true;
    notifyListeners();
  }

  // Proxy methods that update local cache after performing service calls
  Future<Message?> markRead(String id) async {
    try {
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for markRead');
        return null;
      }
      final updated = await _service.markRead(_token!, id);
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
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for changeState');
        return null;
      }
      final updated = await _service.changeState(_token!, id, state);
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
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for sendMessage');
        return null;
      }
      final m = await _service.send(token: _token!, title: title, description: description, destination: destination, adjunts: adjunts);
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
      if (_token == null) {
        debugPrint('⚠️ [MessagesController] no token available for deleteMessage');
        return null;
      }
      final updated = await _service.deleteMessage(_token!, id);
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
