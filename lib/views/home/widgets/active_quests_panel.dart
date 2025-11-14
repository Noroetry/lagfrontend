import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/widgets/quest_detail_popup.dart';
import 'package:lagfrontend/widgets/coordinated_popups_handler.dart';
import 'package:lagfrontend/views/home/widgets/quest_countdown.dart';

/// Widget that displays the list of active quests (state 'L' or 'C').
class ActiveQuestsPanel extends StatelessWidget {
  const ActiveQuestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(
              'No hay misiones activas',
              style: TextStyle(color: Colors.white70),
            ),
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
                if (header is Map && header['title'] != null) {
                  questTitle = header['title'].toString();
                }
                questTitle = questTitle.isNotEmpty
                    ? questTitle
                    : (q['title']?.toString() ?? 'Misión');
                questState = q['state']?.toString() ?? '';
              }
            } catch (_) {}

            final checked = questState == 'C';

            return InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: () async {
                // Show detailed quest popup
                final completed = await showQuestDetailPopup(context, q);
                
                // Si se completó la quest, recargar datos
                if (completed && context.mounted) {
                  final mc = Provider.of<MessageController>(context, listen: false);
                  final uc = Provider.of<UserController>(context, listen: false);
                  
                  debugPrint('✅ [ActiveQuestsPanel] Quest completada, recargando datos...');
                  
                  // Recargar mensajes (para mostrar el mensaje de recompensa)
                  await mc.loadMessages();
                  
                  // Recargar quests (para actualizar el estado)
                  await qc.loadQuests();
                  
                  // Refrescar perfil (para actualizar XP y nivel)
                  final token = uc.authToken;
                  if (token != null && token.isNotEmpty) {
                    try {
                      final updatedProfile = await uc.refreshProfile(token);
                      uc.setUser(updatedProfile, token);
                      debugPrint('✅ [ActiveQuestsPanel] Perfil actualizado después de completar quest');
                    } catch (e) {
                      debugPrint('⚠️ [ActiveQuestsPanel] Error actualizando perfil: $e');
                    }
                  }
                  
                  // Procesar popups automáticamente (mostrará el mensaje de recompensa)
                  if (context.mounted) {
                    debugPrint('🎁 [ActiveQuestsPanel] Procesando popups de recompensa...');
                    await CoordinatedPopupsHandler.processAllPopups(context, mc, qc);
                  }
                }
              },
              child: SizedBox(
                height: 36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        questTitle,
                        style: TextStyle(
                          color: checked ? Colors.green[400] : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // If completed show lock icon with countdown, otherwise show countdown
                    if (checked)
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: _UnlockCountdown(quest: q),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                // Try to find duration in multiple places
                                int? durationMinutes;
                                if (q is Map) {
                                  // Check direct duration field
                                  if (q['duration'] != null) {
                                    durationMinutes = q['duration'] is int
                                        ? q['duration'] as int
                                        : int.tryParse(q['duration'].toString());
                                  }
                                  // Check in header
                                  else if (q['header'] is Map && q['header']['duration'] != null) {
                                    durationMinutes = q['header']['duration'] is int
                                        ? q['header']['duration'] as int
                                        : int.tryParse(q['header']['duration'].toString());
                                  }
                                  // Check in details
                                  else if (q['details'] is Map && q['details']['duration'] != null) {
                                    durationMinutes = q['details']['duration'] is int
                                        ? q['details']['duration'] as int
                                        : int.tryParse(q['details']['duration'].toString());
                                  }
                                }
                                
                                return QuestCountdown(
                                  dateExpirationRaw:
                                      q is Map ? q['dateExpiration'] : null,
                                  durationMinutes: durationMinutes,
                                  dateReadRaw: q is Map ? q['dateRead'] : null,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Widget that shows a lock icon with countdown for completed quests
/// waiting to be unlocked again based on their dateExpiration from backend
class _UnlockCountdown extends StatefulWidget {
  final dynamic quest;

  const _UnlockCountdown({required this.quest});

  @override
  State<_UnlockCountdown> createState() => _UnlockCountdownState();
}

class _UnlockCountdownState extends State<_UnlockCountdown> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime? _parse(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.parse(raw);
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {}
    return null;
  }

  void _update() {
    if (!mounted) return;

    // Según la documentación, para misiones en estado 'C' o 'E',
    // dateExpiration indica cuándo se reactivará la misión.
    // El backend ya calculó toda la lógica de periodicidad (FIXED/WEEKDAYS/PATTERN)
    DateTime? unlockDate;

    try {
      if (widget.quest is Map) {
        final q = widget.quest as Map;
        
        // Leer directamente dateExpiration - el backend ya hizo todos los cálculos
        unlockDate = _parse(q['dateExpiration']);
      }
    } catch (e) {
      debugPrint('Error leyendo dateExpiration: $e');
    }

    if (unlockDate == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }

    final now = DateTime.now();
    final rem = unlockDate.difference(now);
    final clamped = rem.isNegative ? Duration.zero : rem;

    setState(() => _remaining = clamped);
  }

  String _format(Duration d) {
    if (d.inSeconds <= 0) return 'Disponible';
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (days > 0) return '${days}d $hours:$mins:$secs';
    return '$hours:$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.lock_outline,
          color: Colors.amber,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          _format(_remaining),
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
