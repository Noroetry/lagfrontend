import 'package:flutter/foundation.dart';
import 'package:lagfrontend/services/i_messages_service.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/utils/exceptions.dart';

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
  AuthController? _authController;

  MessagesController({IMessagesService? service}) : _service = service ?? (throw ArgumentError.notNull('service'));

  // Called by ChangeNotifierProxyProvider to inform about auth changes
  void updateAuth(AuthController? auth) {
    _authController = auth;
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
    await _withRefreshRetry<List<Message>>((token) => _service.inbox(token)).then((list) {
      if (list != null) {
        inbox = list;
        _loaded = true;
        notifyListeners();
      }
    });
  }

  Future<void> loadSent() async {
    await _withRefreshRetry<List<Message>>((token) => _service.sent(token)).then((list) {
      if (list != null) {
        sent = list;
        notifyListeners();
      }
    });
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
      final updated = await _withRefreshRetry<Message>((token) => _service.markRead(token, id));
      if (updated == null) return null;
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
      final updated = await _withRefreshRetry<Message>((token) => _service.changeState(token, id, state));
      if (updated == null) return null;
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
      final m = await _withRefreshRetry<Message>((token) => _service.send(token: token, title: title, description: description, destination: destination, adjunts: adjunts));
      if (m == null) return null;
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
      final updated = await _withRefreshRetry<Message>((token) => _service.deleteMessage(token, id));
      if (updated == null) return null;
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

  /// Helper that runs a [action] with the current token and, on UnauthorizedException,
  /// triggers a refresh via the AuthController and retries once.
  Future<T?> _withRefreshRetry<T>(Future<T> Function(String token) action) async {
    if (_authController == null || _authController!.authToken == null) return null;
    var token = _authController!.authToken!;
    try {
      return await action(token);
    } on UnauthorizedException {
      // Try to refresh auth status
      try {
        await _authController!.checkAuthenticationStatus();
      } catch (_) {}
      if (_authController!.isAuthenticated && _authController!.authToken != null) {
        token = _authController!.authToken!;
        try {
          return await action(token);
        } catch (e) {
          debugPrint('❌ [MessagesController] retry after refresh failed: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [MessagesController] _withRefreshRetry failed: $e');
      return null;
    }
  }
}
