import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // <-- Necesitarás añadir este paquete para decodificar

class AuthController extends ChangeNotifier {
  // 🟢 1. Instancia de Storage
  final FlutterSecureStorage storage;
  final AuthService _authService;
  
  User? _currentUser;
  String? _authToken;
  bool _isLoading = true; // Empieza en true para el chequeo inicial
  String? _errorMessage;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  // 🟢 2. Validación: Requiere usuario Y token
  bool get isAuthenticated => _currentUser != null && _authToken != null; 
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Ahora permite inyección de dependencias (storage y authService).
  /// Si no se proveen, se usan las implementaciones por defecto.
  AuthController({FlutterSecureStorage? storage, AuthService? authService})
      : storage = storage ?? const FlutterSecureStorage(),
        _authService = authService ?? AuthService() {
    // Llamar a la verificación de estado al construir el controlador
    checkAuthenticationStatus();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // --- LÓGICA DE PERSISTENCIA ---
  
  // 🟢 3. Función para verificar si hay un token guardado al inicio
  Future<void> checkAuthenticationStatus() async {
    _setLoading(true);
    String? storedToken;
    try {
      // Primer paso: listar todas las claves guardadas para diagnóstico
      try {
        final all = await storage.readAll();
        debugPrint('🧭 [Auth Check] Storage keys count: ${all.length}');
        if (all.isNotEmpty) {
          debugPrint('🧭 [Auth Check] Storage keys: ${all.keys.join(', ')}');
        }
      } catch (e) {
        debugPrint('❌ [Auth Check] Error leyendo todas las claves del storage: $e');
      }

  storedToken = await storage.read(key: 'jwt_token');
  final tokenPreview = storedToken == null ? 'null' : '${storedToken.substring(0, 10)}...';
  debugPrint('🔐 [Auth Check] Token encontrado raw: $tokenPreview');
    } catch (e) {
      // Error leyendo storage: tratamos como no autenticado
      storedToken = null;
    }

    if (storedToken != null) {
      try {
        // Primero comprobar expiración local
        final expired = JwtDecoder.isExpired(storedToken);
        debugPrint('⏱️ [Auth Check] Token expired (local): $expired');
        if (expired) {
          try {
            await storage.delete(key: 'jwt_token'); // Token expirado localmente
          } catch (_) {}
          _authToken = null;
          _currentUser = null;
        } else {
          // Token localmente válido: validar contra backend (/me)
          try {
            final profile = await _authService.getProfile();
            _authToken = storedToken;
            _currentUser = profile;
            debugPrint('✅ [Auth Check] Token validado por backend, usuario: ${profile.username}');
          } on UnauthorizedException catch (e) {
            debugPrint('⚠️ [Auth Check] Token rechazado por backend: $e');
            try {
              await storage.delete(key: 'jwt_token');
            } catch (_) {}
            _authToken = null;
            _currentUser = null;
          } catch (e) {
            // Error de red u otro — conservamos el token localmente y asumimos no autenticado
            debugPrint('❌ [Auth Check] Error validando token con backend: $e');
            _authToken = null;
            _currentUser = null;
          }
        }
      } catch (e) {
        // Error de decodificación u otro
        try {
          await storage.delete(key: 'jwt_token');
        } catch (_) {}
        _authToken = null;
        _currentUser = null;
      }
    }
    _setLoading(false);
  }

  // --- LÓGICA DE AUTENTICACIÓN ---
  
  Future<void> login(String usernameOrEmail, String password) async { 
    _setLoading(true);
    _setErrorMessage(null);
    try {
  final response = await _authService.login(usernameOrEmail, password);
      _currentUser = response.user;
      _authToken = response.token; 
      
      // 🟢 4. Guardar token tras login exitoso
      if (_authToken != null) {
        try {
          await storage.write(key: 'jwt_token', value: _authToken!);
          debugPrint('🔐 [Auth Save] Token guardado correctamente');
          // Leer de vuelta para verificar persistencia inmediata
          try {
            final verify = await storage.read(key: 'jwt_token');
            debugPrint('🔐 [Auth Verify] Token leído tras guardar: ${verify != null}');
          } catch (e) {
            debugPrint('❌ [Auth Verify] Error leyendo token tras guardar: $e');
          }
        } catch (e) {
          _setErrorMessage('Error al guardar credenciales localmente');
        }
      }
      notifyListeners();
    } catch (e) {
      _setErrorMessage(e.toString());
      _currentUser = null;
      _authToken = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> registerAndLogin(String username, String email, String password) async {
    _setLoading(true);
    _setErrorMessage(null);
    try {
  final response = await _authService.register(username, email, password);
      
      _currentUser = response.user;
      _authToken = response.token; 
      
      // 🟢 CAMBIO: Lógica para guardar el token después del registro exitoso
      if (_authToken != null) {
        try {
          await storage.write(key: 'jwt_token', value: _authToken!);
          debugPrint('🔐 [Auth Save] Token guardado correctamente tras registro');
        } catch (e) {
          _setErrorMessage('Error al guardar credenciales localmente');
        }
      }
      
      notifyListeners(); // Notificar a los listeners del cambio de estado
      
    } catch (e) {
      _setErrorMessage(e.toString());
      _currentUser = null;
      _authToken = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _authToken = null;
    try {
      await storage.delete(key: 'jwt_token'); // Eliminar el token
      debugPrint('🗑️ [Auth Logout] Token borrado del storage');
    } catch (e) {
      debugPrint('❌ [Auth Logout] Error al borrar token: $e');
      // Si falló el borrado, no hacemos nada más; el token en memoria ya se
      // ha limpiado. Podríamos loggear esto si tuvieras un logger.
    }
    notifyListeners();
  }
}