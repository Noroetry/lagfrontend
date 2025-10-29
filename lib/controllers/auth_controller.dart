import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // <-- Necesitarás añadir este paquete para decodificar

class AuthController extends ChangeNotifier {
  // 🟢 1. Instancia de Storage
  final storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  
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

  AuthController() {
    // 🟢 Llamar a la verificación de estado al construir el controlador
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
    final storedToken = await storage.read(key: 'jwt_token');

    if (storedToken != null) {
      try {
        // Asumiendo que el token contiene info básica o lo verificaremos en un '/me' endpoint
        // Por ahora, asumimos que si existe y es decodificable, está bien.
        if (JwtDecoder.isExpired(storedToken)) {
            await storage.delete(key: 'jwt_token'); // Token expirado, lo borramos
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
        await storage.delete(key: 'jwt_token');
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
        await storage.write(key: 'jwt_token', value: _authToken!);
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
        await storage.write(key: 'jwt_token', value: _authToken!);
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

  void logout() async {
    _currentUser = null;
    _authToken = null;
    await storage.delete(key: 'jwt_token'); // 🟢 6. Eliminar el token
    notifyListeners();
  }
}