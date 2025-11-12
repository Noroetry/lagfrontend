import 'package:lagfrontend/models/message_model.dart';

abstract class IMessageService {
  /// Load all messages for a specific user
  /// If [token] is provided it will be sent as a Bearer Authorization header.
  Future<List<Message>> loadMessages(int userId, {String? token});
  
  /// Mark a message as read
  /// [userId] - ID of the user
  /// [messageUserId] - ID of the user-message relationship (message.id)
  /// If [token] is provided it will be sent as a Bearer Authorization header.
  Future<Map<String, dynamic>> markAsRead(int userId, int messageUserId, {String? token});
}
