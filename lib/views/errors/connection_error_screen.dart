import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';

class ConnectionErrorScreen extends StatelessWidget {
  final String? message;
  const ConnectionErrorScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context, listen: false);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                message ?? 'Sin conexión al servidor',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Intentar reintento: el controller hará ping y re-evaluará el estado.
                  await auth.retryConnection();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
