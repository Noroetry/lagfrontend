import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/messages_controller.dart';
import 'package:lagfrontend/services/auth_service.dart';
import 'package:lagfrontend/services/messages_service.dart';
import 'package:lagfrontend/services/i_auth_service.dart';
import 'package:lagfrontend/services/i_messages_service.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart'; 
import 'package:lagfrontend/views/home/home_screen.dart'; 
import 'package:lagfrontend/theme/app_theme.dart';


void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<IAuthService>(create: (_) => AuthService()),
        Provider<IMessagesService>(create: (_) => MessagesService()),
        
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(authService: context.read<IAuthService>()),
        ),

        ChangeNotifierProxyProvider<AuthController, MessagesController>(
          create: (context) => MessagesController(service: context.read<IMessagesService>()),
          update: (context, auth, previous) {
            final controller = previous ?? MessagesController(service: context.read<IMessagesService>());
            controller.updateAuth(auth);
            return controller;
          },
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