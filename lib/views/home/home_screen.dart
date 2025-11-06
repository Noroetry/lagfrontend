import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/messages_controller.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart'; // Para regresar
import 'package:lagfrontend/widgets/popup_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _listening = false;

  void _maybeShowUnreadPopup(BuildContext context) {
    MessagesController? messages;
    try {
      messages = Provider.of<MessagesController>(context, listen: false);
    } catch (_) {
      messages = null;
    }
    if (messages == null) return;
    if (messages.shouldShowUnreadPopup) {
      // Mark as shown so it won't appear again
      messages.markPopupShown();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black45,
          builder: (ctx) => PopupForm(
            icon: const Icon(Icons.mail_outline, color: Colors.white),
            title: 'BUZÓN',
            description: 'Tienes mensajes nuevos sin leer.¿Quieres abrir el buzón?',
            actions: [
              PopupActionButton(
                label: 'Si',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Implementation in progress...')));
                },
              ),
              PopupActionButton(
                label: 'No',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      // Listen to messages controller to reactively show popup once when needed
      try {
        final messages = Provider.of<MessagesController>(context, listen: false);
        messages.addListener(() {
          if (mounted) _maybeShowUnreadPopup(context);
        });
      } catch (_) {
        // Tests may not provide MessagesController; ignore silently.
      }
      _listening = true;
      // Also try immediately in case messages were already loaded
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowUnreadPopup(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      appBar: AppBar(
        // No title text; background matches scaffold so it visually blends.
        title: const SizedBox.shrink(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
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
                  // Center the action buttons to match requested UX
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}