import 'package:lagfrontend/models/message_adjunt_model.dart';

class Message {
  final int id;
  final String title;
  final String description;
  final String? questTitle;
  final String type;
  final List<MessageAdjunt>? adjunts;
  final String? dateRead;
  final bool isRead;
  final String createdAt;

  const Message({
    required this.id,
    required this.title,
    required this.description,
    this.questTitle,
    required this.type,
    this.adjunts,
    this.dateRead,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawDateRead =
        _stringOrNull(json['dateRead']) ?? _stringOrNull(json['fechaLeido']);
    final cleanedDateRead = _normalizeNullableString(rawDateRead);

    final bool backendFlagsRead = _parseBool(
      json['isRead'] ?? json['read'] ?? json['leido'],
    );
    final bool hasReadTimestamp = cleanedDateRead != null;

    // Parse adjunts if present
    List<MessageAdjunt>? adjunts;
    if (json['adjunts'] != null && json['adjunts'] is List) {
      adjunts = (json['adjunts'] as List)
          .map(
            (adjuntJson) =>
                MessageAdjunt.fromJson(adjuntJson as Map<String, dynamic>),
          )
          .toList();
    }

    return Message(
      id: _parseInt(
        json['id'] ??
            json['messageUserId'] ??
            json['idMessageUser'] ??
            json['message_user_id'],
      ),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      questTitle: json['questTitle']?.toString(),
      type: json['type']?.toString() ?? 'info',
      adjunts: adjunts,
      dateRead: cleanedDateRead,
      isRead: backendFlagsRead || hasReadTimestamp,
      createdAt:
          _stringOrNull(json['createdAt']) ??
          _stringOrNull(json['fechaCreado']) ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    if (questTitle != null) 'questTitle': questTitle,
    'type': type,
    if (adjunts != null) 'adjunts': adjunts!.map((a) => a.toJson()).toList(),
    'dateRead': dateRead,
    'isRead': isRead,
    'createdAt': createdAt,
  };

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static String? _normalizeNullableString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }
}
