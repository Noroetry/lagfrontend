class AppConfig {
  static const bool isDevelopment = bool.fromEnvironment('DEV_MODE', defaultValue: false);
  
  // URLs del backend
  static const String devApiUrl = 'http://10.0.2.2:3000/api';
  static const String prodApiUrl = 'https://lagbackend.onrender.com/api';
  
  // Endpoints
  static const String usersEndpoint = '/users';
  
  // Obtener la URL base según el entorno
  static String get baseApiUrl => isDevelopment ? devApiUrl : prodApiUrl;
  
  // URLs completas para los servicios
  static String get usersApiUrl => '$baseApiUrl$usersEndpoint';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Configuración de seguridad
  static const bool validateSSLCertificate = true; // Poner en false solo si hay problemas con certificados en desarrollo
  
  // IP addresses permitidas de Render (para validación si es necesario)
  static const List<String> renderIpAddresses = [
    '44.229.227.142',
    '54.188.71.94',
    '52.13.128.108',
    '74.220.48.0/24',
    '74.220.56.0/24',
  ];
}