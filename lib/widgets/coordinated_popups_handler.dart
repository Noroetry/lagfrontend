import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/message_detail_popup.dart';
import 'package:lagfrontend/widgets/quest_notification_popup.dart';
import 'package:lagfrontend/widgets/quest_form_popup.dart';

/// Coordinated handler that shows messages FIRST, then quests.
/// This ensures popups don't overlap and messages have priority.
class CoordinatedPopupsHandler extends StatefulWidget {
  const CoordinatedPopupsHandler({super.key});

  @override
  State<CoordinatedPopupsHandler> createState() => _CoordinatedPopupsHandlerState();
}

class _CoordinatedPopupsHandlerState extends State<CoordinatedPopupsHandler> {
  final Set<int> _shownMessageIds = {};
  final Set<dynamic> _shownQuestIds = {};
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processPopups());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MessageController, QuestController>(
      builder: (context, mc, qc, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _processPopups());
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _processPopups() async {
    if (!mounted) return;
    if (_isShowing) return;

    _isShowing = true;
    try {
      // FIRST: Process all messages
      await _processMessages();
      
      // THEN: Process all quests
      await _processQuests();
    } finally {
      _isShowing = false;
    }
  }

  // ==================== MESSAGES ====================
  
  Future<void> _processMessages() async {
    if (!mounted) return;

    while (mounted) {
      // ignore: use_build_context_synchronously
      final mc = Provider.of<MessageController>(context, listen: false);
      final unreadMessages = mc.unreadMessages;

      // Find the next unshown message
      final nextMessage = unreadMessages.where(
        (msg) => !_shownMessageIds.contains(msg.id),
      ).firstOrNull;

      if (nextMessage == null) break; // no more messages

      await _showMessage(nextMessage, mc);
    }
  }

  Future<void> _showMessage(dynamic message, MessageController mc) async {
    if (!mounted) return;
    if (message == null) return;

    final messageId = message.id as int;
    if (_shownMessageIds.contains(messageId)) return;

    // Show the message popup
    await showMessageDetailPopup(
      context,
      message,
      onAccept: () async {
        try {
          await mc.markAsRead(messageId);
        } catch (e) {
          debugPrint('❌ [CoordinatedPopupsHandler] error marking message as read: $e');
        }
      },
    );

    _shownMessageIds.add(messageId);
  }

  // ==================== QUESTS ====================
  
  Future<void> _processQuests() async {
    if (!mounted) return;

    while (mounted) {
      // ignore: use_build_context_synchronously
      final qc = Provider.of<QuestController>(context, listen: false);
      final questsNow = qc.quests;

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

      if (nextQuest == null) break; // no more quests

      await _processQuest(nextQuest, qc);
    }
  }

  Future<void> _processQuest(dynamic quest, QuestController qc) async {
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

    if (state == 'N') {
      final accepted = await showQuestNotificationPopup(context, quest);
      if (!accepted) {
        _shownQuestIds.add(id);
        return;
      }

      try {
        final activated = await qc.activateQuest(id);
        if (!mounted) return;
        if (activated.isNotEmpty) {
          final info = activated.first;
          await _processQuest(info, qc);
        }
      } catch (e) {
        debugPrint('❌ [CoordinatedPopupsHandler] error activating quest: $e');
      } finally {
        _shownQuestIds.add(id);
      }
    } else if (state == 'P') {
      final accepted = await showQuestNotificationPopup(context, quest);
      if (!accepted) {
        _shownQuestIds.add(id);
        return;
      }

      try {
        // ignore: use_build_context_synchronously
        final params = await showQuestFormPopup(context, id, title, quest);
        if (params == null || params.isEmpty) {
          _shownQuestIds.add(id);
          return;
        }

        // If form was submitted successfully, activate the quest
        final activated = await qc.activateQuest(id);
        if (!mounted) return;
        if (activated.isNotEmpty) {
          final info = activated.first;
          await _processQuest(info, qc);
        }
      } catch (e) {
        debugPrint('❌ [CoordinatedPopupsHandler] error with parametric quest: $e');
      } finally {
        _shownQuestIds.add(id);
      }
    }
  }
}
