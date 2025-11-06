import 'package:lagfrontend/models/message_model.dart';

abstract class IMessagesService {
  /// All protected message endpoints require the caller to provide the JWT token.
  Future<Message> send({required String token, required String title, required String description, required String destination, String? adjunts});
  Future<List<Message>> inbox(String token);
  Future<List<Message>> sent(String token);
  Future<Message> getById(String token, String id);
  Future<Message> markRead(String token, String id);
  Future<Message> changeState(String token, String id, String state);
  Future<Message> deleteMessage(String token, String id);
}
