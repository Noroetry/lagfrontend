// no extra imports required

class User {
  final String id;
  final String username;
  final String email;
  // Nivel de administración: entero entre 0 y 100.
  // 0 = sin privilegios; >0 indica algún nivel administrativo.
  final int adminLevel;

  // Map libre para cualquier campo adicional que el backend devuelva
  // (por ejemplo: displayName, avatarUrl, bio, settings, etc.).
  final Map<String, dynamic> additionalData;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.adminLevel,
  this.additionalData = const {},
  });

  // Helper booleano compatible con código antiguo: true si adminLevel > 0
  bool get isAdmin => adminLevel > 0;

  factory User.fromJson(Map<String, dynamic> json) {
    // Conservamos todos los campos extra en additionalData excluding the known ones
    final Map<String, dynamic> copy = Map<String, dynamic>.from(json);

    // Support both '_id' (Mongo-like) and 'id' (numeric or string) from backend
    dynamic rawId = copy.remove('_id');
    rawId ??= copy.remove('id');
    String id = '';
    try {
      if (rawId is int) {
        id = rawId.toString();
      } else if (rawId is String) {
        id = rawId;
      } else {
        id = '';
      }
    } catch (_) {
      id = '';
    }
    final username = (copy.remove('username') ?? '') as String;
    final email = (copy.remove('email') ?? '') as String;
    final adminRaw = copy.remove('admin');
    int adminLevel = 0;
    try {
      if (adminRaw is int) {
        adminLevel = adminRaw.clamp(0, 100).toInt();
      } else if (adminRaw is String) {
        final s = adminRaw.trim();
        if (s.toUpperCase() == 'S' || s.toUpperCase() == 'Y' || s.toLowerCase() == 'true') {
          adminLevel = 100;
        } else if (s.toUpperCase() == 'N' || s.toLowerCase() == 'false') {
          adminLevel = 0;
        } else {
          // try parse numeric string
          final parsed = int.tryParse(s);
          if (parsed != null) adminLevel = parsed.clamp(0, 100).toInt();
        }
      } else if (adminRaw is bool) {
        adminLevel = adminRaw ? 100 : 0;
      }
    } catch (_) {
      adminLevel = 0;
    }

    // No message parsing here — the messages feature was removed.

    return User(
      id: id,
      username: username,
      email: email,
      adminLevel: adminLevel,
      additionalData: copy,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> base = {
      '_id': id,
      'username': username,
      'email': email,
      'admin': adminLevel,
    };
    base.addAll(additionalData);
    return base;
  }
}