import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/widgets/message_detail_popup.dart';

/// Handler that listens for new unread messages and shows them automatically
/// as popups when they arrive. Messages are shown before quests.
class MessagePopupsHandler extends StatefulWidget {
  const MessagePopupsHandler({super.key});

  @override
  State<MessagePopupsHandler> createState() => _MessagePopupsHandlerState();
}

class _MessagePopupsHandlerState extends State<MessagePopupsHandler> {
  final Set<int> _shownMessageIds = {}; // track shown messages to avoid repeats
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processMessages());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageController>(builder: (context, mc, child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processMessages());
      return const SizedBox.shrink();
    });
  }

  Future<void> _processMessages() async {
    if (!mounted) return;
    if (_isShowing) return;

    _isShowing = true;
    try {
      while (mounted) {
        // ignore: use_build_context_synchronously
        final mc = Provider.of<MessageController>(context, listen: false);
        final unreadMessages = mc.unreadMessages;

        // Find the next unshown message
        final nextMessage = unreadMessages.where(
          (msg) => !_shownMessageIds.contains(msg.id),
        ).firstOrNull;

        if (nextMessage == null) break; // nothing left to show

        await _showMessage(nextMessage);
      }
    } finally {
      _isShowing = false;
    }
  }

  Future<void> _showMessage(dynamic message) async {
    if (!mounted) return;
    if (message == null) return;

    final messageId = message.id as int;
    if (_shownMessageIds.contains(messageId)) return;

    final mc = Provider.of<MessageController>(context, listen: false);

    // Show the message popup
    await showMessageDetailPopup(
      context,
      message,
      onAccept: () async {
        // Mark as read when user accepts
        try {
          await mc.markAsRead(messageId);
        } catch (e) {
          debugPrint('❌ [MessagePopupsHandler] error marking message as read: $e');
        }
      },
    );

    // Mark as shown regardless of whether user read it or dismissed it
    _shownMessageIds.add(messageId);
  }
}
