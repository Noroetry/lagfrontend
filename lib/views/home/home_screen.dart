import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart'; // Para regresar

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio - Life As Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authController.logout();
              // Vuelve a la pantalla de autenticación
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¡Bienvenido!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (authController.currentUser != null)
              Text(
                'Has iniciado sesión como: ${authController.currentUser!.username}',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 10),
            if (authController.currentUser != null)
              Text(
                'Email: ${authController.currentUser!.email}',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 40),
            // Aquí puedes añadir más contenido para tu aplicación
            ElevatedButton(
              onPressed: () {
                // Navegar a otras partes de la app
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Explorando tu juego de vida...')),
                );
              },
              child: const Text('Ir al juego'),
            ),
          ],
        ),
      ),
    );
  }
}