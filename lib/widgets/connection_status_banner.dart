import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/services/connectivity_service.dart';

/// Widget que muestra el estado de la conexión y permite reintentar.
/// Se muestra como banner en la parte superior cuando hay problemas.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // No mostrar nada si estamos conectados
        if (connectivity.status == ConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        final message = connectivity.getConnectionStatusMessage();
        final failures = connectivity.consecutiveFailures;

        Color backgroundColor;
        IconData icon;

        if (failures < 3) {
          // Intentando reconectar
          backgroundColor = Colors.orange.shade700;
          icon = Icons.cloud_off;
        } else {
          // Error persistente
          backgroundColor = Colors.red.shade700;
          icon = Icons.error_outline;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (failures >= 3)
                      const Text(
                        'Es posible que el servidor esté arrancando (puede tardar ~30s)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (failures >= 3)
                ElevatedButton(
                  onPressed: () => _retryConnection(context, connectivity),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: backgroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _retryConnection(BuildContext context, ConnectivityService connectivity) async {
    // Resetear el estado de conexión para forzar un nuevo intento
    connectivity.resetConnectionState();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verificando conexión...'),
        duration: Duration(seconds: 2),
      ),
    );
    // Intentar reconectar
    await connectivity.checkConnectivity(updateState: true, forceNotify: true);
  }
}
