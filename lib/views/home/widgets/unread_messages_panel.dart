import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/widgets/message_detail_popup.dart';

/// Widget that displays the list of unread messages.
class UnreadMessagesPanel extends StatelessWidget {
  const UnreadMessagesPanel({super.key});

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
      child: Consumer<MessageController>(builder: (context, mc, child) {
        if (mc.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final unread = mc.unreadMessages;

        if (unread.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No hay mensajes pendientes',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: unread.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white24),
          itemBuilder: (ctx, idx) {
            final message = unread[idx];

            return InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: () async {
                // Show message detail popup
                await showMessageDetailPopup(
                  context,
                  message,
                  onAccept: () async {
                    // Mark message as read
                    try {
                      await mc.markAsRead(message.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al marcar mensaje: $e')),
                        );
                      }
                    }
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    // Message icon
                    const Icon(
                      Icons.mail_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    
                    // Message title
                    Expanded(
                      child: Text(
                        message.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // New indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NUEVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
