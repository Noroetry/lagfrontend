class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  NetworkException({
    required this.message,
    this.statusCode,
    this.body,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'NetworkException: $message (Status: $statusCode)';
    }
    return 'NetworkException: $message';
  }

  // Helpers para tipos comunes de errores
  static NetworkException connectionTimeout() {
    return NetworkException(
      message: 'La conexión al servidor ha tardado demasiado. Por favor, verifica tu conexión a internet.',
    );
  }

  static NetworkException serverError() {
    return NetworkException(
      message: 'Ha ocurrido un error en el servidor. Por favor, intenta más tarde.',
      statusCode: 500,
    );
  }

  static NetworkException noInternet() {
    return NetworkException(
      message: 'No hay conexión a internet. Por favor, verifica tu conexión.',
    );
  }
}