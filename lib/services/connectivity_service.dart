import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/exceptions.dart';

/// Servicio centralizado para gestionar la conectividad de red y reintentos.
/// 
/// Características:
/// - Timeouts largos (35s) para servidores que se despiertan lentamente
/// - Sistema de reintentos con backoff exponencial
/// - Verificación de conexión antes de operaciones críticas
/// - Notificaciones de estado de conexión
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final http.Client _client = http.Client();
  
  // Estado de conexión
  bool _isConnected = true;
  DateTime? _lastSuccessfulConnection;
  int _consecutiveFailures = 0;

  bool get isConnected => _isConnected;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  int get consecutiveFailures => _consecutiveFailures;

  // Configuración de timeouts
  static const Duration defaultTimeout = Duration(seconds: 35); // Tiempo suficiente para servidores que se despiertan
  static const Duration quickTimeout = Duration(seconds: 10); // Para verificaciones rápidas
  static const Duration pingTimeout = Duration(seconds: 8);

  // Configuración de reintentos
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  static const double retryBackoffMultiplier = 2.0;

  /// Verifica la conectividad haciendo ping al servidor.
  /// Usa un timeout corto para no bloquear la UI.
  Future<bool> checkConnectivity({bool updateState = true}) async {
    try {
      final pingUrl = AppConfig.pingUrl;
      final response = await _client
          .get(Uri.parse(pingUrl))
          .timeout(pingTimeout);

      final isOk = response.statusCode == 200;
      
      if (updateState) {
        if (isOk) {
          _markConnectionSuccess();
        } else {
          _markConnectionFailure();
        }
      }

      return isOk;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ConnectivityService] Ping failed: $e');
      }
      if (updateState) {
        _markConnectionFailure();
      }
      return false;
    }
  }

  /// Ejecuta una petición HTTP con timeout largo y sistema de reintentos.
  /// 
  /// [request]: Función que ejecuta la petición HTTP
  /// [retries]: Número de reintentos (por defecto maxRetries)
  /// [timeout]: Timeout para cada intento (por defecto defaultTimeout)
  /// [shouldRetry]: Función opcional para decidir si reintentar basado en la excepción
  Future<T> executeWithRetry<T>({
    required Future<T> Function() request,
    int? retries,
    Duration? timeout,
    bool Function(dynamic error)? shouldRetry,
    String? operationName,
  }) async {
    final maxAttempts = (retries ?? maxRetries) + 1;
    final requestTimeout = timeout ?? defaultTimeout;
    var attempt = 0;
    var delay = initialRetryDelay;

    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        if (kDebugMode && operationName != null) {
          debugPrint('🔄 [ConnectivityService] $operationName - Intento $attempt/$maxAttempts');
        }

        final result = await request().timeout(requestTimeout);
        
        // Éxito: marcar conexión como buena y resetear contador
        _markConnectionSuccess();
        
        if (kDebugMode && operationName != null && attempt > 1) {
          debugPrint('✅ [ConnectivityService] $operationName - Éxito en intento $attempt');
        }
        
        return result;
      } catch (e) {
        final isLastAttempt = attempt >= maxAttempts;
        
        if (kDebugMode && operationName != null) {
          debugPrint('❌ [ConnectivityService] $operationName - Error en intento $attempt: $e');
        }

        // Marcar fallo de conexión
        _markConnectionFailure();

        // Decidir si reintentar
        final shouldRetryThis = shouldRetry?.call(e) ?? _shouldRetryError(e);
        
        if (!shouldRetryThis || isLastAttempt) {
          if (kDebugMode && operationName != null) {
            debugPrint('❌ [ConnectivityService] $operationName - Fallo definitivo después de $attempt intentos');
          }
          rethrow;
        }

        // Esperar antes del siguiente intento (backoff exponencial)
        if (kDebugMode && operationName != null) {
          debugPrint('⏳ [ConnectivityService] $operationName - Reintentando en ${delay.inSeconds}s...');
        }
        
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * retryBackoffMultiplier).round());
      }
    }

    // Este punto nunca debería alcanzarse, pero por seguridad
    throw ApiException('Error ejecutando petición después de $maxAttempts intentos');
  }

  /// Determina si un error debería provocar un reintento.
  bool _shouldRetryError(dynamic error) {
    // Reintentar para errores de red/timeout
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    
    // No reintentar para errores de autenticación
    if (error is UnauthorizedException) return false;
    
    // Para ApiException, revisar el mensaje
    if (error is ApiException) {
      final msg = error.toString().toLowerCase();
      // No reintentar para errores de validación
      if (msg.contains('inválido') || msg.contains('rechazado')) return false;
      // Reintentar para otros errores de API
      return true;
    }
    
    // Por defecto, reintentar
    return true;
  }

  void _markConnectionSuccess() {
    _isConnected = true;
    _lastSuccessfulConnection = DateTime.now();
    _consecutiveFailures = 0;
  }

  void _markConnectionFailure() {
    _isConnected = false;
    _consecutiveFailures++;
  }

  /// Obtiene un mensaje descriptivo del estado de conexión.
  String getConnectionStatusMessage() {
    if (_isConnected) {
      return 'Conectado';
    }
    
    if (_consecutiveFailures == 1) {
      return 'Problema de conexión. Reintentando...';
    } else if (_consecutiveFailures < 5) {
      return 'Sin conexión. Reintentando ($_consecutiveFailures intentos)...';
    } else {
      return 'Sin conexión. Verifica tu conexión a internet.';
    }
  }

  /// Resetea el estado de conexión (útil para testing o forzar re-verificación)
  void resetConnectionState() {
    _isConnected = true;
    _consecutiveFailures = 0;
  }
}
