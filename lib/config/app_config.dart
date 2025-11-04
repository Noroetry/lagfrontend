class AppConfig {
  // Default to development for local testing. CI / production can override via
  // --dart-define=DEV_MODE=false when building for production.
  static const bool isDevelopment = bool.fromEnvironment('DEV_MODE', defaultValue: true);
  
  // URLs del backend
  static const String devApiUrl = 'http://10.0.2.2:3000/api';
  static const String prodApiUrl = 'https://lagbackend.onrender.com/api';
  
  // Endpoints
  static const String usersEndpoint = '/users';
  // Messages endpoint
  static const String messagesEndpoint = '/messages';
  
  // Obtener la URL base según el entorno
  static String get baseApiUrl => isDevelopment ? devApiUrl : prodApiUrl;

  // Allows tests or runtime code to override the base API URL (helps testing
  // against local servers or mocks). Use `null` to clear the override.
  static String? _overrideBaseApiUrl;

  static void setOverrideBaseApiUrl(String? url) => _overrideBaseApiUrl = url;

  static void clearOverrideBaseApiUrl() => _overrideBaseApiUrl = null;

  static String get effectiveBaseApiUrl => _overrideBaseApiUrl != null && _overrideBaseApiUrl!.isNotEmpty
      ? _overrideBaseApiUrl!
      : baseApiUrl;
  
  // URLs completas para los servicios
  static String get usersApiUrl => '$baseApiUrl$usersEndpoint';
  static String get messagesApiUrl => '$baseApiUrl$messagesEndpoint';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Configuración de seguridad
  static const bool validateSSLCertificate = true; // Poner en false solo si hay problemas con certificados en desarrollo
  
  // Optional background image for the app (relative asset path). Leave empty to use procedural fog.
  // Example: 'assets/images/background.jpg'
  // No background image by default; use a solid dark background color instead.
  // No background image by default; use solid dark background color instead.
  // Leave empty to avoid loading any image asset as background.
  static const String backgroundImagePath = '';

  // IP addresses permitidas de Render (para validación si es necesario)
  static const List<String> renderIpAddresses = [
    '44.229.227.142',
    '54.188.71.94',
    '52.13.128.108',
    '74.220.48.0/24',
    '74.220.56.0/24',
  ];

  // Reserved usernames that cannot be registered or used to login from client
  // (the server also reserves 'system' and may enforce others). Keep all in
  // lowercase for case-insensitive checks.
  static const List<String> reservedUsernames = [
    'system',
  ];
}