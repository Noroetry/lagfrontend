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
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      try {
        final auth = Provider.of<AuthController>(context, listen: false);
        // Capture MessageController and QuestController synchronously so we don't use BuildContext across async gaps.
        final mc = Provider.of<MessageController>(context, listen: false);
        final qc = Provider.of<QuestController>(context, listen: false);
        // Run the auth check and then ensure MessageController refreshes BEFORE QuestController.
        // Use a microtask so we don't make this lifecycle callback async.
        Future.microtask(() async {
          try {
            await auth.checkAuthenticationStatus();
          } catch (_) {}
          try {
            // Load messages FIRST
            await mc.loadMessages();
          } catch (_) {}
          try {
            // Then load quests
            await qc.loadQuests();
          } catch (_) {}
        });
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