import 'package:flutter/foundation.dart';
import 'package:lagfrontend/utils/secure_storage_adapter.dart';
import 'package:lagfrontend/models/user_model.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/services/user_service.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/exceptions.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthController extends ChangeNotifier {
  final SecureStorage storage;
  final IAuthService _authService;

  late final UserController userController;
  bool _isLoading = true;
  String? _errorMessage;
  String? _connectionErrorMessage;

  User? get currentUser => userController.currentUser;
  String? get authToken => userController.authToken;
  bool get isAuthenticated => userController.isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get connectionErrorMessage => _connectionErrorMessage;

  AuthController({SecureStorage? storage, IAuthService? authService, UserController? userController})
      : storage = storage ?? FlutterSecureStorageAdapter(),
        _authService = authService ?? (throw ArgumentError.notNull('authService')) {
    // userController may be provided (e.g., for DI/testing); otherwise create a default one
    this.userController = userController ?? UserController(UserService(_authService));
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
        storedToken = await storage.read('jwt_token');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error leyendo token del storage: $e');
        storedToken = null;
      }

      if (storedToken == null || storedToken.trim().isEmpty) {
        userController.clearUser();
        return;
      }

      try {
        await _authService.ping();
        if (_connectionErrorMessage != null) {
          _connectionErrorMessage = null;
          notifyListeners();
        }
      } catch (e) {
        _connectionErrorMessage = 'Error de conexión: $e';
        if (kDebugMode) debugPrint('⚠️ [Auth Check] Ping failed: $e');
        return;
      }

      try {
        final now = DateTime.now();
        DateTime exp;
        try {
          exp = JwtDecoder.getExpirationDate(storedToken);
        } catch (e) {
          if (kDebugMode) debugPrint('❌ [Auth Check] Error decodificando token: $e');
          // If we can't decode, try to refresh once
          exp = now.subtract(const Duration(seconds: 1));
        }

        final timeLeft = exp.difference(now);
        final needsRefresh = timeLeft.inMinutes <= 5; // refresh if <= 5 minutes left or already expired

        if (needsRefresh) {
          // Try refresh first (server reads refresh cookie or header)
          try {
            final refreshed = await _authService.refresh();
            userController.setUser(refreshed.user, refreshed.token);
            try {
              if (refreshed.token != null) await storage.write('jwt_token', refreshed.token!);
            } catch (_) {}
            if (kDebugMode) debugPrint('🔄 [Auth Check] Token refrescado exitosamente');
            return;
          } on UnauthorizedException catch (e) {
            if (kDebugMode) debugPrint('⚠️ [Auth Check] Refresh rechazado: $e');
            try {
              await storage.delete('jwt_token');
            } catch (_) {}
            userController.clearUser();
            _setErrorMessage('Sesión expirada');
            return;
          } catch (e) {
            if (kDebugMode) debugPrint('❌ [Auth Check] Error refrescando token: $e');
            userController.clearUser();
            _setErrorMessage('Error refrescando sesión: $e');
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error procesando expiración: $e');
      }

      // Token localmente válido: validar contra backend (/me)
      try {
        final profile = await _authService.getProfile(storedToken);
        // Si llegamos aquí, el backend validó el token -> delegar al UserController
        userController.setUser(profile, storedToken);
        if (kDebugMode) debugPrint('✅ [Auth Check] Perfil obtenido: ${profile.username}');
      } on UnauthorizedException catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Auth Check] Token rechazado por backend: $e — intentando refresh');
        // Try one refresh attempt
        try {
          final refreshed = await _authService.refresh();
          userController.setUser(refreshed.user, refreshed.token);
          try {
            if (refreshed.token != null) await storage.write('jwt_token', refreshed.token!);
          } catch (_) {}
          if (kDebugMode) debugPrint('🔄 [Auth Check] Token refrescado tras 401');
        } on UnauthorizedException catch (e2) {
          if (kDebugMode) debugPrint('⚠️ [Auth Check] Refresh falló tras 401: $e2');
          try {
            await storage.delete('jwt_token');
          } catch (_) {}
          userController.clearUser();
          _setErrorMessage('Token rechazado por backend');
        } catch (e2) {
          if (kDebugMode) debugPrint('❌ [Auth Check] Error refrescando tras 401: $e2');
          userController.clearUser();
          _setErrorMessage('Error validando token: $e2');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Auth Check] Error validando token: $e');
        userController.clearUser();
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
      userController.setUser(response.user, response.token);

      // If backend didn't return an access token but set a refresh cookie, try to refresh once
      if (response.token == null) {
        try {
          if (kDebugMode) debugPrint('🔁 [Auth Login] No access token in response, attempting refresh via cookie');
          final refreshed = await _authService.refresh();
          userController.setUser(refreshed.user, refreshed.token);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ [Auth Login] refresh attempt after login failed: $e');
        }
      }

      if (userController.authToken != null) {
        try {
          await storage.write('jwt_token', userController.authToken!);
          if (kDebugMode) debugPrint('🔐 [Auth Save] Token guardado correctamente');
        } catch (e) {
          _setErrorMessage('Error al guardar credenciales localmente');
        }
      }
      notifyListeners();
    } catch (e) {
      _setErrorMessage(e.toString());
      userController.clearUser();
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

      // Ensure we delegate user state
      userController.setUser(response.user, response.token);

      if (userController.authToken != null) {
        try {
          await storage.write('jwt_token', userController.authToken!);
          if (kDebugMode) debugPrint('🔐 [Auth Save] Token guardado correctamente tras registro');
        } catch (e) {
          _setErrorMessage('Error al guardar credenciales localmente');
        }
      }
      notifyListeners();
    } catch (e) {
      _setErrorMessage(e.toString());
      userController.clearUser();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    // First, try to inform server to invalidate refresh token
    try {
      await _authService.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [Auth Logout] error calling server logout: $e');
      // continue with client-side cleanup even if server call fails
    }

    userController.clearUser();
    try {
      await storage.delete('jwt_token');
      if (kDebugMode) debugPrint('🗑️ [Auth Logout] Token borrado del storage');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [Auth Logout] Error al borrar token: $e');
    }
    notifyListeners();
  }

  /// Reintentar comprobación de conexión y, si procede, volver a chequear autenticación.
  Future<void> retryConnection() async {
    // Clear previous connection error and attempt to re-run the auth check which includes ping.
    _connectionErrorMessage = null;
    notifyListeners();
    await checkAuthenticationStatus();
  }
}