class Message {
  final String id;
  final String title;
  final String? description;
  final String source;
  final String destination;
  final String? adjunts; // optional base64 or URL
  final bool read; // true if 'S'
  final DateTime? dateRead;
  final DateTime dateSent;
  final String state; // 'A','R','D'

  Message({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    required this.destination,
    this.adjunts,
    required this.read,
    this.dateRead,
    required this.dateSent,
    required this.state,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // id may be int or string; normalize to string
    final rawId = json['id'] ?? json['_id'] ?? json['Id'];
    final id = rawId == null ? '' : rawId.toString();

    final title = json['title']?.toString() ?? '';
    final description = json['description']?.toString();
    final source = json['source']?.toString() ?? '';
    final destination = json['destination']?.toString() ?? '';
    final adjunts = json['adjunts']?.toString();

    // read stored as 'S'/'N'
    final rawRead = json['read'];
    bool read = false;
    if (rawRead is String) {
      read = rawRead.toUpperCase() == 'S';
    } else if (rawRead is bool) {
      read = rawRead;
    }

    DateTime? dateRead;
    if (json['dateRead'] != null) {
      try {
        dateRead = DateTime.parse(json['dateRead'].toString());
      } catch (_) {
        dateRead = null;
      }
    }

    DateTime dateSent;
    if (json['dateSent'] != null) {
      try {
        dateSent = DateTime.parse(json['dateSent'].toString());
      } catch (_) {
        dateSent = DateTime.now();
      }
    } else {
      dateSent = DateTime.now();
    }

    final state = json['state']?.toString() ?? 'A';

    return Message(
      id: id,
      title: title,
      description: description,
      source: source,
      destination: destination,
      adjunts: adjunts,
      read: read,
      dateRead: dateRead,
      dateSent: dateSent,
      state: state,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'source': source,
      'destination': destination,
      'adjunts': adjunts,
      'read': read ? 'S' : 'N',
      'dateRead': dateRead?.toIso8601String(),
      'dateSent': dateSent.toIso8601String(),
      'state': state,
    };
  }
}
