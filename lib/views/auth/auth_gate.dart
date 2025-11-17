import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/home/home_screen.dart'; // Tu pantalla principal
import 'package:lagfrontend/views/auth/welcome_screen.dart'; // La nueva pantalla de bienvenida
import 'package:lagfrontend/views/errors/connection_error_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    debugPrint('[AuthGate] build: isAuthenticated = [33m[1m[4m[7m[41m${authController.isAuthenticated}[0m, isLoading = ${authController.isLoading}, connectionError = ${authController.connectionErrorMessage}');
    if (authController.connectionErrorMessage != null) {
      debugPrint('[AuthGate] build: Mostrando ConnectionErrorScreen');
      return ConnectionErrorScreen(message: authController.connectionErrorMessage);
    }

    if (authController.isLoading) {
      debugPrint('[AuthGate] build: Mostrando pantalla de carga');
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // 3. Si está autenticado, va a Home (¡Login directo!)
    if (authController.isAuthenticated) {
      debugPrint('[AuthGate] build: Mostrando HomeScreen');
      return const HomeScreen();
    } 
    // 4. Si no tiene token (o está expirado), va a WelcomeScreen
    else {
      debugPrint('[AuthGate] build: Mostrando WelcomeScreen');
      return const WelcomeScreen();
    }
  }
}