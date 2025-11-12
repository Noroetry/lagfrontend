class Message {
  final int id;
  final int messageId;
  final String title;
  final String description;
  final String type;
  final String? dateRead;
  final bool isRead;
  final String createdAt;

  const Message({
    required this.id,
    required this.messageId,
    required this.title,
    required this.description,
    required this.type,
    this.dateRead,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: _parseInt(json['id']),
        messageId: _parseInt(json['messageId'] ?? json['idMessage'] ?? json['message_id']),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        type: json['type']?.toString() ?? 'info',
        dateRead: json['dateRead']?.toString() ?? json['fechaLeido']?.toString(),
        isRead: _parseBool(json['isRead'] ?? json['read'] ?? json['leido'] ?? json['dateRead']),
        createdAt: json['createdAt']?.toString() ?? json['fechaCreado']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'messageId': messageId,
        'title': title,
        'description': description,
        'type': type,
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
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'y';
  }
}
