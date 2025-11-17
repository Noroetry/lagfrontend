
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/exceptions.dart';

/// Estado enriquecido de la conexión
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  backendStarting,
}

/// Servicio centralizado para gestionar la conectividad de red y reintentos.
/// 
/// Características:
/// - Timeouts largos (35s) para servidores que se despiertan lentamente
/// - Sistema de reintentos con backoff exponencial
/// - Verificación de conexión antes de operaciones críticas
/// - Notificaciones de estado de conexión

/// Servicio centralizado y reactivo para gestionar la conectividad de red y reintentos.
/// Notifica listeners cuando cambia el estado de conexión.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final http.Client _client = http.Client();

  // Estado enriquecido
  ConnectionStatus _status = ConnectionStatus.connected;
  ConnectionStatus get status => _status;

  DateTime? _lastSuccessfulConnection;
  int _consecutiveFailures = 0;
  String? _lastErrorMessage;

  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  int get consecutiveFailures => _consecutiveFailures;
  String? get lastErrorMessage => _lastErrorMessage;

  // Configuración de timeouts
  static const Duration defaultTimeout = Duration(seconds: 35); // Tiempo suficiente para servidores que se despiertan
  static const Duration quickTimeout = Duration(seconds: 10); // Para verificaciones rápidas
  static const Duration pingTimeout = Duration(seconds: 8);

  // Configuración de reintentos
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  static const double retryBackoffMultiplier = 2.0;

  /// Permite saber si la UI debe bloquearse (no hay conexión o está arrancando el backend)
  bool get shouldBlockUI => _status == ConnectionStatus.connecting || _status == ConnectionStatus.disconnected || _status == ConnectionStatus.backendStarting;

  /// Verifica la conectividad haciendo ping al servidor.
  /// Usa un timeout corto para no bloquear la UI.
  /// Si no hay conexión, expone el estado adecuado y notifica listeners.
  Future<bool> checkConnectivity({bool updateState = true, bool forceNotify = false}) async {
    _updateStatus(ConnectionStatus.connecting);
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
          _markConnectionFailure('Respuesta inesperada del servidor: ${response.statusCode}');
        }
      }

      if (forceNotify) notifyListeners();
      return isOk;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ConnectivityService] Ping failed: $e');
      }
      if (updateState) {
        // Si es timeout, probablemente el backend está arrancando
        if (e is TimeoutException) {
          _updateStatus(ConnectionStatus.backendStarting);
          _lastErrorMessage = 'El servidor está arrancando. Inténtalo en unos segundos.';
        } else {
          _markConnectionFailure(e.toString());
        }
      }
      if (forceNotify) notifyListeners();
      return false;
    }
  }

  /// Ejecuta una petición HTTP con timeout largo y sistema de reintentos.
  /// Notifica listeners en cada cambio de estado relevante.
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

    _updateStatus(ConnectionStatus.connecting);

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

        // Si es timeout en el primer intento, probablemente el backend está arrancando
        if (e is TimeoutException && attempt == 1) {
          _updateStatus(ConnectionStatus.backendStarting);
          _lastErrorMessage = 'El servidor está arrancando. Inténtalo en unos segundos.';
        } else {
          _markConnectionFailure(e.toString());
        }

        // Decidir si reintentar
        final shouldRetryThis = shouldRetry?.call(e) ?? _shouldRetryError(e);

        if (!shouldRetryThis || isLastAttempt) {
          if (kDebugMode && operationName != null) {
            debugPrint('❌ [ConnectivityService] $operationName - Fallo definitivo después de $attempt intentos');
          }
          notifyListeners();
          rethrow;
        }

        // Esperar antes del siguiente intento (backoff exponencial)
        if (kDebugMode && operationName != null) {
          debugPrint('⏳ [ConnectivityService] $operationName - Reintentando en ${delay.inSeconds}s...');
        }

        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * retryBackoffMultiplier).round());
        notifyListeners();
      }
    }

    // Este punto nunca debería alcanzarse, pero por seguridad
    _updateStatus(ConnectionStatus.disconnected);
    throw ApiException('Error ejecutando petición después de $maxAttempts intentos');
  }

  bool defaultShouldRetry(dynamic error) {
    return _shouldRetryError(error);
  }

  bool _shouldRetryError(dynamic error) {
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    if (error is UnauthorizedException) return false;
    if (error is ApiException) {
      final msg = error.toString().toLowerCase();
      if (msg.contains('credenciales inválidas')) return false;
      if (msg.contains('credenciales incorrectas')) return false;
      if (msg.contains('contraseña incorrecta')) return false;
      if (msg.contains('usuario no encontrado')) return false;
      if (msg.contains('invalid credentials')) return false;
      if (msg.contains('invalid password')) return false;
      if (msg.contains('user not found')) return false;
      if (msg.contains('inválido') || msg.contains('rechazado')) return false;
      if (msg.contains('invalid') || msg.contains('rejected')) return false;
      return true;
    }
    return true;
  }

  void _markConnectionSuccess() {
    _updateStatus(ConnectionStatus.connected);
    _lastSuccessfulConnection = DateTime.now();
    _consecutiveFailures = 0;
    _lastErrorMessage = null;
  }

  void _markConnectionFailure([String? errorMsg]) {
    _consecutiveFailures++;
    _lastErrorMessage = errorMsg;
    _updateStatus(ConnectionStatus.disconnected);
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Obtiene un mensaje descriptivo del estado de conexión.
  String getConnectionStatusMessage() {
    switch (_status) {
      case ConnectionStatus.connected:
        return 'Conectado';
      case ConnectionStatus.connecting:
        return 'Conectando...';
      case ConnectionStatus.backendStarting:
        return 'El servidor está arrancando. Inténtalo en unos segundos.';
      case ConnectionStatus.disconnected:
        if (_consecutiveFailures == 1) {
          return 'Problema de conexión. Reintentando...';
        } else if (_consecutiveFailures < 5) {
          return 'Sin conexión. Reintentando ($_consecutiveFailures intentos)...';
        } else {
          return 'Sin conexión. Verifica tu conexión a internet.';
        }
    }
  }

  /// Resetea el estado de conexión (útil para testing o forzar re-verificación)
  void resetConnectionState() {
    _consecutiveFailures = 0;
    _lastErrorMessage = null;
    _updateStatus(ConnectionStatus.connected);
  }

  /// Lógica para integración con ciclo de vida: refresca conexión al reanudar la app
  Future<void> onAppResumed() async {
    await checkConnectivity(updateState: true, forceNotify: true);
  }
}
