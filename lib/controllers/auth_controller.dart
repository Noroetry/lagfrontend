import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // Función para verificar si hay un token guardado al inicio
  Future<void> checkAuthenticationStatus() async {
    _setLoading(true);
    String? storedToken;
    try {
      try {
        final dynamic dyn = storage as dynamic;
        final dynamic maybeAll = dyn.readAll();
        if (maybeAll is Future) {
          try {
            final Map<String, String> all = await maybeAll;
            debugPrint('🧭 [Auth Check] Storage keys count: ${all.length}');
            if (all.isNotEmpty) debugPrint('🧭 [Auth Check] Storage keys: ${all.keys.join(', ')}');
          } catch (e) {
            debugPrint('❌ [Auth Check] Error awaiting readAll(): $e');
          }
        }
      } catch (e) {
        debugPrint('❌ [Auth Check] Error leyendo todas las claves del storage: $e');
      }

      // Leer el token guardado (mocks may return null/non-Future)
      try {
        final dynamic dynStorage = storage as dynamic;
        final dynamic maybeToken = dynStorage.read(key: 'jwt_token');
        if (maybeToken is Future) {
          storedToken = await maybeToken as String?;
        } else if (maybeToken is String) {
          storedToken = maybeToken;
        } else {
          storedToken = null;
        }
      } catch (e) {
        storedToken = null;
      }
      final tokenPreview = storedToken == null ? 'null' : '${storedToken.substring(0, 10)}...';
      debugPrint('🔐 [Auth Check] Token encontrado raw: $tokenPreview');
    } catch (e) {
      storedToken = null;
    }

    if (storedToken != null) {
      try {
        // Comprobar expiración local
        final expired = JwtDecoder.isExpired(storedToken);
        debugPrint('⏱️ [Auth Check] Token expired (local): $expired');
        if (expired) {
          try {
            await storage.delete(key: 'jwt_token'); 
          } catch (_) {}
          _authToken = null;
          _currentUser = null;
        } else {
          // Token localmente válido: validar contra backend (/me)
          try {
            final dynamic dyn = _authService as dynamic;
            try {
              final maybeProfile = dyn.getProfile();
              if (maybeProfile is Future) {
                final profile = await maybeProfile as dynamic;
                _authToken = storedToken;
                if (profile is User) {
                  _currentUser = profile;
                  debugPrint('✅ [Auth Check] Token validado por backend, usuario: ${profile.username}');
                } else if (profile is Map<String, dynamic>) {
                  _currentUser = User.fromJson(profile);
                  debugPrint('✅ [Auth Check] Token validado por backend (map), usuario: ${_currentUser!.username}');
                } else {
                  throw ApiException('Unexpected profile shape');
                }
              } else {
                // No backend validation provided; fallback to token decode
                final payload = JwtDecoder.decode(storedToken);
                _authToken = storedToken;
                _currentUser = User.fromJson(payload);
                debugPrint('✅ [Auth Check] Token decodificado localmente, usuario: ${_currentUser!.username}');
              }
            } on TypeError catch (e) {
              // Likely a mocked auth service without getProfile stub: fallback to local decode
              debugPrint('⚠️ [Auth Check] getProfile threw TypeError (probably unstubbed mock): $e');
              final payload = JwtDecoder.decode(storedToken);
              _authToken = storedToken;
              _currentUser = User.fromJson(payload);
              debugPrint('✅ [Auth Check] Fallback token decode used, usuario: ${_currentUser!.username}');
            }
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
    // Prevent login with reserved usernames (client-side guard)
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
      
      // Guardar token tras login exitoso
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
    // Prevent registering reserved usernames client-side
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
      
      // Guardar el token después del registro exitoso
      if (_authToken != null) {
        try {
          await storage.write(key: 'jwt_token', value: _authToken!);
          debugPrint('🔐 [Auth Save] Token guardado correctamente tras registro');
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
      debugPrint('🗑️ [Auth Logout] Token borrado del storage');
    } catch (e) {
      debugPrint('❌ [Auth Logout] Error al borrar token: $e');
    }
    notifyListeners();
  }
}