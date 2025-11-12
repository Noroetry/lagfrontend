import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
// app_theme is not required here; popups import it when needed
import 'package:lagfrontend/widgets/quest_notification_popup.dart';
import 'package:lagfrontend/widgets/quest_form_popup.dart';

class QuestPopupsHandler extends StatefulWidget {
  const QuestPopupsHandler({super.key});

  @override
  State<QuestPopupsHandler> createState() => _QuestPopupsHandlerState();
}

class _QuestPopupsHandlerState extends State<QuestPopupsHandler> {
  final Set<dynamic> _shownQuestIds = {}; // track shown quests to avoid repeats
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processQuests());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestController>(builder: (context, qc, child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processQuests());
      return const SizedBox.shrink();
    });
  }

  Future<void> _processQuests() async {
    if (!mounted) return;
    if (_isShowing) return;

    _isShowing = true;
    try {
      while (mounted) {
        // ignore: use_build_context_synchronously
        final qc = Provider.of<QuestController>(context, listen: false);
        final questsNow = qc.quests;

        // Helper to get state/id safely
        String? stateOf(dynamic q) {
          try {
            return (q is Map && q['state'] != null) ? q['state'].toString() : null;
          } catch (_) {
            return null;
          }
        }

        dynamic idOf(dynamic q) {
          try {
            if (q is Map && q['idQuestUser'] != null) return q['idQuestUser'];
            if (q is Map && q['id'] != null) return q['id'];
            return null;
          } catch (_) {
            return null;
          }
        }

        // Find any unshown 'N' quest first
        dynamic nextQuest;
        for (final q in questsNow) {
          final s = stateOf(q);
          final id = idOf(q);
          if (s != null && s == 'N' && id != null && !_shownQuestIds.contains(id)) {
            nextQuest = q;
            break;
          }
        }

        // If no 'N', find an unshown 'P' quest
        if (nextQuest == null) {
          for (final q in questsNow) {
            final s = stateOf(q);
            final id = idOf(q);
            if (s != null && s == 'P' && id != null && !_shownQuestIds.contains(id)) {
              nextQuest = q;
              break;
            }
          }
        }

        if (nextQuest == null) break; // nothing left to show

        await _processQuest(nextQuest);
      }
    } finally {
      _isShowing = false;
    }
  }

  Future<bool> _showNotificationPopup(dynamic quest) async {
    return await showQuestNotificationPopup(context, quest);
  }

  Future<List<dynamic>?> _showFormPopup(dynamic id, String questTitle, dynamic quest) async {
    return await showQuestFormPopup(context, id, questTitle, quest);
  }

  Future<void> _processQuest(dynamic quest) async {
    if (!mounted) return;
    if (quest == null) return;

    final id = (quest is Map && quest['idQuestUser'] != null)
        ? quest['idQuestUser']
        : (quest is Map && quest['id'] != null ? quest['id'] : null);
    if (id == null) return;
    if (_shownQuestIds.contains(id)) return;

    final state = quest is Map && quest['state'] != null ? quest['state'].toString() : null;
    final header = quest is Map ? (quest['header'] ?? {}) : {};
    final title = header is Map && header['title'] != null ? header['title'].toString() : 'Quest';

    final qc = Provider.of<QuestController>(context, listen: false);
    if (state == 'N') {
      // Quests en estado N: mostrar notificación y al aceptar llamar a activate
      final accepted = await _showNotificationPopup(quest);
      if (!accepted) {
        _shownQuestIds.add(id);
        return;
      }

      try {
        final activated = await qc.activateQuest(id);
        if (!mounted) return;
        if (activated.isNotEmpty) {
          // If the backend returned additional quest(s), process them
          // immediately but do not show the 'QUEST INFO' dialog.
          final info = activated.first;
          await _processQuest(info);
        }
      } catch (e) {
        debugPrint('❌ [_processQuest activate] error: $e');
      } finally {
        _shownQuestIds.add(id);
      }
    } else if (state == 'P') {
      // Quests en estado P: primero mostrar notificación, luego formulario,
      // y solo después de submit-params exitoso llamar a activate
      final accepted = await _showNotificationPopup(quest);
      if (!accepted) {
        _shownQuestIds.add(id);
        return;
      }

      try {
        // Mostrar el formulario para capturar parámetros
        final submitted = await _showFormPopup(id, title, quest);

        if (submitted != null && submitted.isNotEmpty) {
          // submit-params fue exitoso, ahora llamar a activate
          try {
            final activated = await qc.activateQuest(id);
            if (!mounted) return;
            if (activated.isNotEmpty) {
              final info = activated.first;
              await _processQuest(info);
            }
          } catch (e) {
            debugPrint('❌ [_processQuest activate after submit] error: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ [_processQuest submit] error: $e');
      } finally {
        // Mark this quest as shown regardless to avoid re-showing the same
        // form repeatedly on subsequent cycles.
        _shownQuestIds.add(id);
      }
    }
  }

  // No local info dialog anymore; details are shown in dedicated popups.
}