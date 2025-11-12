import 'package:flutter/foundation.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/services/message_service.dart';

/// Controller that manages messages for the currently authenticated user.
class MessageController extends ChangeNotifier {
  final UserController _userController;
  final MessageService _messageService;

  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  MessageController(this._userController, this._messageService) {
    // React to user changes
    _userController.addListener(_onUserChanged);
    // If there's already a user, try to load messages
    if (_userController.isAuthenticated) {
      loadMessages();
    }
  }

  List<Message> get messages => _messages;
  List<Message> get unreadMessages => _messages.where((m) => !m.isRead).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => unreadMessages.length;

  void _onUserChanged() {
    if (_userController.isAuthenticated) {
      loadMessages();
    } else {
      // Clear messages when user logs out
      _messages = [];
      notifyListeners();
    }
  }

  /// Load all messages for the current user
  Future<void> loadMessages() async {
    final user = _userController.currentUser;
    if (user == null) return;
    
    _isLoading = true;
    _error = null;
    if (kDebugMode) {
      debugPrint('📬 [MessageController.loadMessages] starting for userId=${user.id} tokenPresent=${_userController.authToken != null}');
    }
    notifyListeners();

    try {
      // Parse user.id to int (it's stored as String but backend expects int)
      final userId = int.tryParse(user.id) ?? 0;
      // Pass auth token from UserController if available so server can authorize the request
      _messages = await _messageService.loadMessages(userId, token: _userController.authToken);
      if (kDebugMode) {
        debugPrint('✅ [MessageController.loadMessages] loaded ${_messages.length} messages');
        debugPrint('📊 [MessageController.loadMessages] unread: $unreadCount');
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('❌ [MessageController.loadMessages] error: $_error');
      _messages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a message as read
  /// [messageUserId] is the ID of the user-message relationship (message.id)
  Future<void> markAsRead(int messageUserId) async {
    final user = _userController.currentUser;
    if (user == null) return;
    
    if (kDebugMode) {
      debugPrint('📖 [MessageController.markAsRead] marking message $messageUserId as read for user ${user.id}');
    }

    try {
      // Parse user.id to int
      final userId = int.tryParse(user.id) ?? 0;
      
      // Pass auth token from UserController if available so server can authorize the request
      final response = await _messageService.markAsRead(userId, messageUserId, token: _userController.authToken);
      if (kDebugMode) {
        debugPrint('✅ [MessageController.markAsRead] response: $response');
      }

      // Update local state
      final index = _messages.indexWhere((m) => m.id == messageUserId);
      if (index != -1) {
        final message = _messages[index];
        _messages[index] = Message(
          id: message.id,
          messageId: message.messageId,
          title: message.title,
          description: message.description,
          type: message.type,
          dateRead: DateTime.now().toIso8601String(),
          isRead: true,
          createdAt: message.createdAt,
        );
        notifyListeners();
      }

      // Optionally reload messages to sync with server
      // await loadMessages();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [MessageController.markAsRead] error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _userController.removeListener(_onUserChanged);
    super.dispose();
  }
}
