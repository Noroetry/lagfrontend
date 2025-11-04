import 'dart:convert';
import 'package:lagfrontend/models/message_model.dart';

class User {
  final String id;
  final String username;
  final String email;
  final bool isAdmin; // Asumimos que 'S'/'N' se convierte a bool

  // Map libre para cualquier campo adicional que el backend devuelva
  // (por ejemplo: displayName, avatarUrl, bio, settings, etc.).
  final Map<String, dynamic> additionalData;
  // Mensajes asociados al usuario. Parseados a objetos Message si vienen del backend.
  final List<Message> messages;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    this.additionalData = const {},
    this.messages = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Conservamos todos los campos extra en additionalData excluding the known ones
    final Map<String, dynamic> copy = Map<String, dynamic>.from(json);

    final id = (copy.remove('_id') ?? '') as String;
    final username = (copy.remove('username') ?? '') as String;
    final email = (copy.remove('email') ?? '') as String;
    final adminRaw = copy.remove('admin');
    final isAdmin = adminRaw == 'S';

    // Extract messages if present and remove from additional map
    final rawMessages = copy.remove('messages');
    List<Message> messages = const [];
    if (rawMessages is List) {
      try {
        messages = rawMessages.where((e) => e != null).map<Message>((e) {
          if (e is Map<String, dynamic>) return Message.fromJson(e);
          if (e is String) {
            try {
              final parsed = Map<String, dynamic>.from(jsonDecode(e));
              return Message.fromJson(parsed);
            } catch (_) {
              return Message.fromJson({});
            }
          }
          return Message.fromJson({});
        }).toList();
      } catch (_) {
        messages = const [];
      }
    }

    return User(
      id: id,
      username: username,
      email: email,
      isAdmin: isAdmin,
      additionalData: copy,
      messages: messages,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> base = {
      '_id': id,
      'username': username,
      'email': email,
      'admin': isAdmin ? 'S' : 'N',
    };
    base.addAll(additionalData);
    if (messages.isNotEmpty) base['messages'] = messages.map((m) => m.toJson()).toList();
    return base;
  }
}