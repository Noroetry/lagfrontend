import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/home/home_screen.dart'; // Tu pantalla principal
import 'package:lagfrontend/views/auth/welcome_screen.dart'; // La nueva pantalla de bienvenida

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    if (authController.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verificando sesión...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // 3. Si está autenticado, va a Home (¡Login directo!)
    if (authController.isAuthenticated) {
      return const HomeScreen();
    } 
    
    // 4. Si no tiene token (o está expirado), va a WelcomeScreen
    else {
      return const WelcomeScreen();
    }
  }
}