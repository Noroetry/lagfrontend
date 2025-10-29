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
      storedToken = await storage.read(key: 'jwt_token');
      debugPrint('🔐 [Auth Check] Token encontrado: ${storedToken?.substring(0, 10)}...');
    } catch (e) {
      // Error leyendo storage: tratamos como no autenticado
      storedToken = null;
    }

    if (storedToken != null) {
      try {
        // Asumiendo que el token contiene info básica o lo verificaremos en un '/me' endpoint
        // Por ahora, asumimos que si existe y es decodificable, está bien.
        if (JwtDecoder.isExpired(storedToken)) {
          try {
            await storage.delete(key: 'jwt_token'); // Token expirado, lo borramos
          } catch (_) {}
            _authToken = null;
            _currentUser = null;
        } else {
            _authToken = storedToken;
            // 💡 NOTA: En producción, aquí harías una llamada a /me para obtener los datos
            //          completos del usuario, en lugar de decodificar datos sensibles.
            // Decodificamos el payload para obtener el ID y el email guardados en el token
            Map<String, dynamic> decodedToken = JwtDecoder.decode(storedToken);
            _currentUser = User(
                id: decodedToken['id'] ?? '', 
                username: decodedToken['username'], // Usamos username como fallback
                email: decodedToken['email'] ?? '', 
                isAdmin: decodedToken['admin'] ?? false, 
            );
        }
      } catch (e) {
        // Error de decodificación (token corrupto)
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
    } catch (e) {
      // Si falló el borrado, no hacemos nada más; el token en memoria ya se
      // ha limpiado. Podríamos loggear esto si tuvieras un logger.
    }
    notifyListeners();
  }
}