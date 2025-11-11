import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/quest_popups_handler.dart';
import 'package:lagfrontend/widgets/quest_detail_popup.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
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
              // Fila superior con los iconos (transparente), alineada a la derecha
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person),
                      color: Colors.white,
                      tooltip: 'Perfil',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not implemented yet')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: Colors.white,
                      tooltip: 'Ajustes',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not implemented yet')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.mail_outline),
                      color: Colors.white,
                      tooltip: 'Mensajes',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not implemented yet')));
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

              // Panel: información de usuario (nivel / título / job / rango / barra EXP)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Builder(builder: (context) {
                  final user = authController.currentUser;
                  final additional = user?.additionalData ?? {};

                  // Try to read some commonly used keys from additionalData
                  final level = additional['level'] ?? additional['nivel'] ?? additional['xpLevel'];
                  final title = additional['title'] ?? additional['titulo'] ?? additional['rankTitle'];
                  final job = additional['job'] ?? additional['profesion'] ?? additional['role'];
                  final range = additional['range'] ?? additional['rango'];

                  // EXP placeholder: if we have exp and nextExp compute ratio, otherwise null
                  double? expRatio;
                  try {
                    final exp = (additional['exp'] ?? additional['xp']) as num?;
                    final next = (additional['expToNext'] ?? additional['xpToNext'] ?? additional['next'] ?? 0) as num?;
                    if (exp != null && next != null && next > 0) {
                      expRatio = (exp.toDouble() / next.toDouble()).clamp(0.0, 1.0);
                    }
                  } catch (_) {
                    expRatio = null;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Nivel: ${level ?? '—'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Rango: ${range ?? '—'}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Título: ${title ?? '—'}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Trabajo: ${job ?? '—'}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 8),
                      // EXP bar (placeholder)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EXP', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6.0),
                            child: expRatio != null
                                ? LinearProgressIndicator(value: expRatio, minHeight: 10, backgroundColor: Colors.white24, color: Colors.white)
                                : LinearProgressIndicator(value: 0.0, minHeight: 10, backgroundColor: Colors.white24, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),

              const SizedBox(height: 12),

              // Sección: título de misiones
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Misiones',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 8),

              // Panel: misiones activas (state == 'L' o 'C')
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Consumer<QuestController>(builder: (context, qc, child) {
                  if (qc.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final active = qc.quests.where((q) {
                    try {
                      final s = q is Map && q['state'] != null ? q['state'].toString() : '';
                      return s == 'L' || s == 'C';
                    } catch (_) {
                      return false;
                    }
                  }).toList();

                  if (active.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No hay misiones activas', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: active.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                    itemBuilder: (ctx, idx) {
                      final q = active[idx];
                      String questTitle = 'Misión';
                      String questState = '';
                      try {
                        if (q is Map) {
                          final header = q['header'];
                          if (header is Map && header['title'] != null) questTitle = header['title'].toString();
                          questTitle = questTitle.isNotEmpty ? questTitle : (q['title']?.toString() ?? 'Misión');
                          questState = q['state']?.toString() ?? '';
                        }
                      } catch (_) {}

                      final checked = questState == 'C';

                      return InkWell(
                        borderRadius: BorderRadius.circular(6.0),
                        onTap: () async {
                          // Build the same info summary used in QuestPopupsHandler
                          // Show detailed quest popup (modular)
                          await showQuestDetailPopup(context, q);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(child: Text(questTitle, style: const TextStyle(color: Colors.white))),
                              const SizedBox(width: 8),
                              Icon(
                                checked ? Icons.check_box : Icons.check_box_outline_blank,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
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