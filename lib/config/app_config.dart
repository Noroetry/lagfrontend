/// Centralized application configuration.
///
/// - Separates API root (protocol + host + port) from the API prefix (/api).
/// - Provides convenient endpoints (users, quests, ping, etc.).
/// - Keeps timeouts and other global constants.
class AppConfig {
  // Toggle for development mode; set as a compile-time environment flag if needed.
  static const bool isDevelopment = bool.fromEnvironment('DEV_MODE', defaultValue: true);

  // --- API roots ---
  // The root host (without the /api prefix). Use emulator host for Android emulator.
  static const String _devApiRoot = 'http://10.0.2.2:3000';
  static const String _prodApiRoot = 'https://lagbackend.onrender.com';

  // API prefix applied to resource endpoints
  static const String apiPrefix = '/api';

  // Chooses root depending on environment
  static String get baseApiRoot => isDevelopment ? _devApiRoot : _prodApiRoot;

  // Combined base API URL (e.g. https://host/api)
  static String get baseApiUrl => '$baseApiRoot$apiPrefix';

  // Helper to build endpoints relative to the API prefix
  static String endpoint(String path) => '$baseApiUrl$path';

  // --- Resource endpoints ---
  static String get usersApiUrl => endpoint('/users');
  static String get questsApiUrl => endpoint('/quests');
  static String get messagesApiUrl => endpoint('/messages');
  // Add other resource endpoints here, e.g. itemsApiUrl, etc.

  // Ping lives under the API root (e.g. /api/ping)
  static String get pingUrl => endpoint('/ping');

  // --- Timeouts ---
  // Milliseconds
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // --- Security / misc ---
  static const bool validateSSLCertificate = true;

  // Optional background image for the app (relative asset path). Leave empty to use procedural fog.
  static const String backgroundImagePath = '';

  // IP addresses permitidas de Render (para validación si es necesario)
  // Mantengo la lista para despliegues en Render; puede usarse en validaciones
  // del backend o para reglas de seguridad posteriores.
  static const List<String> renderIpAddresses = [
    '44.229.227.142',
    '54.188.71.94',
    '52.13.128.108',
    '74.220.48.0/24',
    '74.220.56.0/24',
  ];

  // Reserved usernames that cannot be registered or used to login from client
  static const List<String> reservedUsernames = [
    'system',
    'admin',
    'administrator',
  ];
}