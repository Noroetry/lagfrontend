class Quest {
  final String id;
  final String title;
  final bool completed;

  Quest({required this.id, required this.title, this.completed = false});

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        completed: json['completed'] == true,
      );
}
