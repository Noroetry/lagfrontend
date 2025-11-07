import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/utils/cookie_client.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/services/quest_service.dart';
// Messages feature removed: messages controller and services are not provided
import 'package:lagfrontend/views/auth/auth_gate.dart'; 
import 'package:lagfrontend/views/home/home_screen.dart'; 
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

  ChangeNotifierProvider<AuthController>(
    create: (context) => AuthController(authService: context.read<IAuthService>()),
    lazy: false,
  ),
  // QuestController depends on the UserController instance owned by AuthController, so create it after AuthController
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
    if (state == AppLifecycleState.resumed) {
      try {
        final auth = Provider.of<AuthController>(context, listen: false);
        auth.checkAuthenticationStatus();
      } catch (_) {
        // If providers are not ready or during tests, ignore.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}