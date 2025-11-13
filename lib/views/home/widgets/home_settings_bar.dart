import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart';

/// Widget that displays the top settings bar with report, help, profile, settings, and logout buttons.
class HomeSettingsBar extends StatelessWidget {
  const HomeSettingsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context, listen: false);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.warning_amber),
            color: Colors.white,
            tooltip: 'Reporte',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: Colors.white,
            tooltip: 'Ayuda',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            color: Colors.white,
            tooltip: 'Perfil',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: Colors.white,
            tooltip: 'Configuración',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            color: Colors.white,
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
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Sí'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                if (!navigator.mounted) return;
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
    );
  }
}
