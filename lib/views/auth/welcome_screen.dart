import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/app_background.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/views/auth/login_screen.dart';
import 'package:lagfrontend/views/auth/register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // Limpiar errores previos al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthController>(context, listen: false).clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: PopupForm(
            icon: const Icon(Icons.notifications, color: Colors.white, size: 18),
            title: 'NOTIFICACIÓN',
            actions: [
              PopupActionButton(
                label: 'Si',
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              ),
              PopupActionButton(
                label: 'No',
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ],
            // Use child for rich formatting so we can bold "Jugador"
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  children: [
                    const TextSpan(text: 'Bienvenido, ¿Es la primera vez que accedes al sistema?'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}