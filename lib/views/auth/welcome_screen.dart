import 'package:flutter/material.dart';
import 'package:lagfrontend/widgets/app_background.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/views/auth/login_screen.dart';
import 'package:lagfrontend/views/auth/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              ),
              PopupActionButton(
                label: 'No',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
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