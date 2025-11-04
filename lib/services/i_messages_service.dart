import 'package:lagfrontend/models/message_model.dart';

abstract class IMessagesService {
  Future<Message> send({required String title, required String description, required String destination, String? adjunts});
  Future<List<Message>> inbox();
  Future<List<Message>> sent();
  Future<Message> getById(String id);
  Future<Message> markRead(String id);
  Future<Message> changeState(String id, String state);
  Future<Message> deleteMessage(String id);
}
