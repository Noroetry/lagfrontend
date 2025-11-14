/// Represents an attachment (adjunt) in a message, which can be a reward or penalty.
/// Types include: experience, coin, quest, etc.
class MessageAdjunt {
  final int id;
  final String objectName;
  final String shortName;
  final String description;
  final String type;
  final int quantity;
  final String? questAssignedTitle;
  final int? idQuestAssigned;

  const MessageAdjunt({
    required this.id,
    required this.objectName,
    required this.shortName,
    required this.description,
    required this.type,
    required this.quantity,
    this.questAssignedTitle,
    this.idQuestAssigned,
  });

  factory MessageAdjunt.fromJson(Map<String, dynamic> json) {
    return MessageAdjunt(
      id: _parseInt(json['id']),
      objectName: json['objectName']?.toString() ?? '',
      shortName: json['shortName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      quantity: _parseInt(json['quantity']),
      questAssignedTitle: json['questAssignedTitle']?.toString(),
      idQuestAssigned: json['idQuestAssigned'] != null
          ? _parseInt(json['idQuestAssigned'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'objectName': objectName,
    'shortName': shortName,
    'description': description,
    'type': type,
    'quantity': quantity,
    if (questAssignedTitle != null) 'questAssignedTitle': questAssignedTitle,
    if (idQuestAssigned != null) 'idQuestAssigned': idQuestAssigned,
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
}
