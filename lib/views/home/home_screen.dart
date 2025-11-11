import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
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
  // Listen to UserController for profile changes so this widget rebuilds only
  // when the user data changes. Use AuthController with listen:false for
  // actions (logout) to avoid unnecessary rebuilds.
  final authController = Provider.of<AuthController>(context, listen: false);
  final userController = Provider.of<UserController>(context);

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

              const SizedBox(height: 12),

              // Panel: información de usuario (nivel / título / job / rango / barra EXP)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Builder(builder: (context) {
                  final user = userController.currentUser;
                  final additional = user?.additionalData ?? {};

                  // Try to read some commonly used keys from additionalData.
                  // The backend will provide new fields:
                  // - level_number
                  // - totalExp
                  // - minExpRequired
                  // - nextRequiredLevel
                  final title = additional['title'] ?? additional['titulo'] ?? additional['rankTitle'];
                  final job = additional['job'] ?? additional['profesion'] ?? additional['role'];
                  final range = additional['range'] ?? additional['rango'];

                  // Helper to parse numeric values that may come as int/double or String
                  num? parseNum(Object? v) {
                    try {
                      if (v == null) return null;
                      if (v is num) return v;
                      if (v is String) return num.tryParse(v);
                    } catch (_) {}
                    return null;
                  }

                  // Level: prefer explicit backend field, fall back to older keys
                  final levelNumber = additional['level_number'] ?? additional['level'] ?? additional['nivel'] ?? additional['xpLevel'];

                  // XP fields
                  final num? totalExp = parseNum(additional['totalExp'] ?? additional['exp'] ?? additional['xp']);
                  final num? minExp = parseNum(additional['minExpRequired'] ?? additional['minExp']);
                  final num? nextReq = parseNum(additional['nextRequiredLevel'] ?? additional['expToNext'] ?? additional['xpToNext'] ?? additional['next']);

                  // Compute ratio: (totalExp - minExp) / (nextReq - minExp)
                  double? expRatio;
                  try {
                    if (totalExp != null && minExp != null && nextReq != null) {
                      final denom = nextReq.toDouble() - minExp.toDouble();
                      if (denom > 0) {
                        expRatio = ((totalExp.toDouble() - minExp.toDouble()) / denom).clamp(0.0, 1.0);
                      } else {
                        expRatio = 0.0;
                      }
                    } else if (totalExp != null && nextReq != null) {
                      // Fallback: simple total / next
                      if (nextReq.toDouble() > 0) expRatio = (totalExp.toDouble() / nextReq.toDouble()).clamp(0.0, 1.0);
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
                          Text('Nivel: ${levelNumber ?? '—'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          const SizedBox(height: 6),
                          // Numeric XP label when we have values
                          Builder(builder: (context) {
                            try {
                              if (totalExp != null && nextReq != null) {
                                final percent = expRatio != null ? (expRatio * 100).toStringAsFixed(0) : '?';
                                return Text('${totalExp.toInt()} / ${nextReq.toInt()} XP ($percent%)', style: const TextStyle(fontSize: 12, color: Colors.white70));
                              }
                            } catch (_) {}
                            return const SizedBox.shrink();
                          }),
                        ],
                      ),
                    ],
                  );
                }),
              ),

              const SizedBox(height: 8),

              // Sección: título de misiones
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Misiones',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 6),

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
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  questTitle,
                                  style: TextStyle(color: checked ? Colors.green[400] : Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // If completed show a reward icon (future rewards), otherwise show countdown until expiration
                              if (checked)
                                IconButton(
                                  icon: const Icon(Icons.shopping_bag_outlined),
                                  color: Colors.amber,
                                  tooltip: 'Recompensas',
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No implementado aún')));
                                  },
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: SizedBox(
                                    height: 40,
                                    child: Center(
                                      child: _QuestCountdown(
                                        dateExpirationRaw: q is Map ? q['dateExpiration'] : null,
                                        dateReadRaw: q is Map ? q['dateRead'] : null,
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

/// Small widget that displays a live countdown to [dateExpirationRaw].
///
/// - `dateExpirationRaw` and `dateReadRaw` can be either ISO-8601 strings or
///   DateTime objects (or null). If `dateReadRaw` is provided we use it to
///   compute the full duration so the progress bar shows fraction remaining.
class _QuestCountdown extends StatefulWidget {
  final dynamic dateExpirationRaw;
  final dynamic dateReadRaw;

  const _QuestCountdown({this.dateExpirationRaw, this.dateReadRaw});

  @override
  State<_QuestCountdown> createState() => _QuestCountdownState();
}

class _QuestCountdownState extends State<_QuestCountdown> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  double _fraction = 0.0;
  DateTime? _expiresAt;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _parseDates();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  DateTime? _parse(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.parse(raw).toUtc();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw).toUtc();
    } catch (_) {}
    return null;
  }

  void _parseDates() {
    _expiresAt = _parse(widget.dateExpirationRaw);
    _startedAt = _parse(widget.dateReadRaw);
  }

  void _update() {
    final now = DateTime.now().toUtc();
    if (_expiresAt == null) {
      setState(() {
        _remaining = Duration.zero;
        _fraction = 0.0;
      });
      return;
    }

    final rem = _expiresAt!.difference(now);
    final total = (_startedAt != null) ? _expiresAt!.difference(_startedAt!) : null;

    final clamped = rem.isNegative ? Duration.zero : rem;
    double frac = 0.0;
    if (total != null && total.inMilliseconds > 0) {
      frac = clamped.inMilliseconds / total.inMilliseconds;
      if (frac < 0) frac = 0.0;
      if (frac > 1) frac = 1.0;
    }

    setState(() {
      _remaining = clamped;
      _fraction = frac;
    });
  }

  String _format(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00';
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (days > 0) return '${days}d $hours:$mins:$secs';
    return '$hours:$mins:$secs';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _format(_remaining);
    // Ensure the countdown fits tight vertical constraints by scaling the
    // label down and constraining the heights of children. This avoids
    // RenderFlex overflow when the parent gives only ~36px of height.
    return SizedBox(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Constrain label height and allow it to scale down if necessary
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 4),
          // Animate progress changes smoothly. Constrain minHeight to keep compact.
          SizedBox(
            height: 8,
            child: _startedAt != null
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: _fraction, end: _fraction),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) => LinearProgressIndicator(value: value.clamp(0.0, 1.0), backgroundColor: Colors.white12, color: Colors.green[400], minHeight: 8),
                  )
                : LinearProgressIndicator(value: null, backgroundColor: Colors.white12, color: Colors.green[400], minHeight: 8),
          ),
        ],
      ),
    );
  }
}