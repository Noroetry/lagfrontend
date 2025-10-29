class User {
  final String id;
  final String username;
  final String email;
  final bool isAdmin; // Asumimos que 'S'/'N' se convierte a bool

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '', // MongoDB usa '_id'
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      isAdmin: json['admin'] == 'S', // Conversión de 'S'/'N' a bool
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'admin': isAdmin ? 'S' : 'N',
    };
  }
}