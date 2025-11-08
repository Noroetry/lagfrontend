import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/quest_popups_handler.dart';
// Messages feature removed: no imports here
import 'package:lagfrontend/views/auth/auth_gate.dart'; // Para regresar

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Messages feature removed — keep HomeScreen focused on user info and navigation

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      // AppBar eliminado para evitar la flecha de back; botones colocados dentro del body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fila superior con los iconos, alineada a la derecha y con el mismo fondo que el tema
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mail_outline),
                      tooltip: 'Mensajes',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messages not implemented yet')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.exit_to_app),
                      tooltip: 'Cerrar sesión',
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('¿Estás seguro que deseas cerrar sesión?'),
                            actionsAlignment: MainAxisAlignment.center,
                            actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          if (!mounted) return;
                          authController.logout();
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const AuthGate()),
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Contenido principal centrado
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¡Bienvenido!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (authController.currentUser != null) ...[
                      Text(
                        'Usuario: ${authController.currentUser!.username}',
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email: ${authController.currentUser!.email}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${authController.currentUser!.id}',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Show admin flag
                      Text(
                        'Administrador: ${authController.currentUser!.isAdmin ? 'Sí' : 'No'}',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Render any additional fields returned by the backend
                      Builder(builder: (context) {
                        final additional = authController.currentUser?.additionalData;
                        if (additional == null || additional.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            const Text('Información adicional:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...additional.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white70)),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
              // Handler that listens for quests and shows popups when needed.
              const QuestPopupsHandler(),
            ],
          ),
        ),
      ),
    );
  }
}