import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/exceptions.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthController extends ChangeNotifier {
  final FlutterSecureStorage storage;
  final IAuthService _authService;

  User? _currentUser;
  String? _authToken;
  bool _isLoading = true;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthController({FlutterSecureStorage? storage, IAuthService? authService})
      : storage = storage ?? const FlutterSecureStorage(),
        _authService = authService ?? (throw ArgumentError.notNull('authService')) {
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

  Future<void> checkAuthenticationStatus() async {
    _setLoading(true);
    try {
      String? storedToken;
      try {
        storedToken = await storage.read(key: 'jwt_token');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error leyendo token del storage: $e');
        storedToken = null;
      }

      if (storedToken == null || storedToken.trim().isEmpty) {
        _authToken = null;
        _currentUser = null;
        return;
      }

      // Comprobar expiración localmente
      try {
        if (JwtDecoder.isExpired(storedToken)) {
          try {
            await storage.delete(key: 'jwt_token');
          } catch (_) {}
          _authToken = null;
          _currentUser = null;
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error decodificando token: $e');
        try {
          await storage.delete(key: 'jwt_token');
        } catch (_) {}
        _authToken = null;
        _currentUser = null;
        return;
      }

      // Token localmente válido: validar contra backend (/me)
      try {
        final profile = await _authService.getProfile(storedToken);
        // Si llegamos aquí, el backend validó el token
        _authToken = storedToken;
        _currentUser = profile;
        if (kDebugMode) debugPrint('✅ [Auth Check] Perfil obtenido: ${profile.username}');
      } on UnauthorizedException catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Auth Check] Token rechazado por backend: $e');
        try {
          await storage.delete(key: 'jwt_token');
        } catch (_) {}
        _authToken = null;
        _currentUser = null;
        _setErrorMessage('Token rechazado por backend');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error validando token: $e');
        _authToken = null;
        _currentUser = null;
        _setErrorMessage('Error validando token: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // --- LÓGICA DE AUTENTICACIÓN ---
  Future<void> login(String usernameOrEmail, String password) async {
    _setLoading(true);
    _setErrorMessage(null);

    // Guard client-side para nombres reservados
    try {
      final lower = usernameOrEmail.toLowerCase();
      if (AppConfig.reservedUsernames.contains(lower)) {
        _setErrorMessage('El nombre de usuario "$usernameOrEmail" no está permitido.');
        _setLoading(false);
        return;
      }
    } catch (_) {}

    try {
      final response = await _authService.login(usernameOrEmail, password);
      _currentUser = response.user;
      _authToken = response.token;

      if (_authToken != null) {
        try {
          await storage.write(key: 'jwt_token', value: _authToken!);
          if (kDebugMode) debugPrint('🔐 [Auth Save] Token guardado correctamente');
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
      final lower = username.toLowerCase();
      if (AppConfig.reservedUsernames.contains(lower)) {
        _setErrorMessage('El nombre de usuario "$username" no está permitido.');
        _setLoading(false);
        return;
      }
    } catch (_) {}

    try {
      final response = await _authService.register(username, email, password);

      _currentUser = response.user;
      _authToken = response.token;

      if (_authToken != null) {
        try {
          await storage.write(key: 'jwt_token', value: _authToken!);
          if (kDebugMode) debugPrint('🔐 [Auth Save] Token guardado correctamente tras registro');
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

  Future<void> logout() async {
    _currentUser = null;
    _authToken = null;
    try {
      await storage.delete(key: 'jwt_token');
      if (kDebugMode) debugPrint('🗑️ [Auth Logout] Token borrado del storage');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [Auth Logout] Error al borrar token: $e');
    }
    notifyListeners();
  }
}