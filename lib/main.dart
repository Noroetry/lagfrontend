import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 

import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/auth/auth_screen.dart'; 
import 'package:lagfrontend/views/home/home_screen.dart'; 

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life As Game',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AuthController>(
        builder: (context, authController, child) {
          // Si el usuario está autenticado, vamos a HomeScreen, si no, a AuthScreen.
          // Por ahora, asumimos que no está autenticado hasta que lo implementemos.
          // return authController.isAuthenticated ? const HomeScreen() : const AuthScreen();
          return const AuthScreen(); // Por ahora siempre a AuthScreen
        },
      ),
      // Aquí puedes definir rutas nombradas si prefieres
      routes: {
        '/home': (context) => const HomeScreen(),
        // Otras rutas...
      },
    );
  }
}