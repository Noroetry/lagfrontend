import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/utils/cookie_client.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/services/quest_service.dart';
import 'package:lagfrontend/services/message_service.dart';
import 'package:lagfrontend/services/user_service.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart'; 
import 'package:lagfrontend/theme/app_theme.dart';


void main() {
  runApp(
    MultiProvider(
      providers: [
  // CookieClient persists HttpOnly cookies set by the server (refresh token)
  Provider<CookieClient>(create: (_) => CookieClient()),
  Provider<IAuthService>(create: (context) => AuthService(client: context.read<CookieClient>())),
  // Provide QuestService so controllers can call backend quests endpoints (uses same cookie-enabled client)
  Provider<QuestService>(create: (context) => QuestService(client: context.read<CookieClient>())),
  // Provide MessageService for message-related operations
  Provider<MessageService>(create: (context) => MessageService(client: context.read<CookieClient>())),

  // Provide a separate UserController (backed by UserService) so the rest of the
  // app can read profile, inventory, levels, etc. directly from the provider.
  ChangeNotifierProvider<UserController>(
    create: (context) => UserController(UserService(context.read<IAuthService>())),
    lazy: false,
  ),

  // AuthController should receive the shared UserController instance so it does
  // not create its own. This keeps a single source of truth for user state.
  ChangeNotifierProvider<AuthController>(
    create: (context) => AuthController(authService: context.read<IAuthService>(), userController: context.read<UserController>()),
    lazy: false,
  ),

  // MessageController manages user messages - created BEFORE QuestController
  // so messages are loaded and shown first
  ChangeNotifierProvider<MessageController>(
    create: (context) => MessageController(context.read<UserController>(), context.read<MessageService>()),
    lazy: false,
  ),

  // QuestController depends on the UserController instance owned by AuthController (or the provided one),
  // so create it after AuthController and MessageController.
  ChangeNotifierProvider<QuestController>(
    create: (context) => QuestController(context.read<AuthController>().userController, context.read<QuestService>()),
    lazy: false,
  ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _hasHandledInitialResume = false;
  DateTime? _lastResumeTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🔄 [$timestamp] [Main] App lifecycle changed to: $state');
    
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('⏸️ [$timestamp] [Main] App became inactive (puede estar en transición o bloqueada)');
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ [$timestamp] [Main] App paused (en background)');
    } else if (state == AppLifecycleState.detached) {
      debugPrint('⏹️ [$timestamp] [Main] App detached (cerrándose)');
    } else if (state == AppLifecycleState.hidden) {
      debugPrint('👁️ [$timestamp] [Main] App hidden (no visible pero puede estar ejecutándose)');
    }
  }

  void _handleAppResumed() {
    final now = DateTime.now();
    final timestamp = now.toString().substring(11, 23);
    
    // Skip initial resume - HomeScreen will handle initial data load
    if (!_hasHandledInitialResume) {
      _hasHandledInitialResume = true;
      debugPrint('⏯️ [$timestamp] [Main] Initial resume - skipping data load (HomeScreen will handle it)');
      return;
    }

    // Throttle: no refrescar si ya refrescamos hace menos de 3 segundos
    if (_lastResumeTime != null && now.difference(_lastResumeTime!).inSeconds < 3) {
      debugPrint('⏯️ [$timestamp] [Main] Resume throttled (last resume was ${now.difference(_lastResumeTime!).inSeconds}s ago)');
      return;
    }

    _lastResumeTime = now;

    // Only reload on subsequent resumes (when user returns to app)
    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      
      // Verificar si estamos autenticados antes de recargar
      if (!auth.isAuthenticated) {
        debugPrint('⏯️ [$timestamp] [Main] Not authenticated, skipping reload');
        return;
      }
      
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);
      
      Future.microtask(() async {
        debugPrint('🔄 [$timestamp] [Main] App resumed - reloading data usando refreshAllData...');
        
        try {
          // Usar el método centralizado para garantizar consistencia
          await auth.refreshAllData(
            messageController: mc,
            questController: qc,
          );
          
          debugPrint('✅ [$timestamp] [Main] Data reload complete');
        } catch (e) {
          debugPrint('❌ [$timestamp] [Main] Error en refresco: $e');
          // El ConnectivityService ya maneja los reintentos, solo registrar el error
        }
      });
    } catch (e) {
      debugPrint('❌ [$timestamp] [Main] Error setting up refresh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      // Removed routes - AuthGate handles navigation automatically
    );
  }
}