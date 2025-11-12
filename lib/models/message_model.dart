class Message {
  final int id;
  final int messageId;
  final String title;
  final String description;
  final String type;
  final String? dateRead;
  final bool isRead;
  final String createdAt;

  Message({
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
        id: json['id'] as int,
        messageId: json['messageId'] as int,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        type: json['type']?.toString() ?? 'info',
        dateRead: json['dateRead']?.toString(),
        isRead: json['isRead'] == true,
        createdAt: json['createdAt']?.toString() ?? '',
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
}
