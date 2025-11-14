import 'package:flutter/material.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/widgets/message_adjunts_list.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Shows a detailed message popup when tapping a message.
/// Displays different content based on the message type: info, reward, or penalty.
Future<void> showMessageDetailPopup(
  BuildContext context,
  Message message,
) async {
  if (!context.mounted) return;

  debugPrint(
    '📨 [showMessageDetailPopup] Presenting message ${message.id} type=${message.type}',
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      // Determine popup configuration based on message type
      final popupConfig = _getPopupConfigForType(message.type);
      final child = _buildContentForType(ctx, message);

      return PopupForm(
        title: popupConfig.title,
        icon: popupConfig.icon,
        actions: [
          PopupActionButton(
            label: 'Aceptar',
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
        child: child,
      );
    },
  );
  debugPrint(
    '📨 [showMessageDetailPopup] Message ${message.id} dialog returned',
  );
}

class _PopupConfig {
  final String title;
  final Icon icon;

  const _PopupConfig({required this.title, required this.icon});
}

_PopupConfig _getPopupConfigForType(String type) {
  switch (type.toLowerCase()) {
    case 'reward':
      return const _PopupConfig(
        title: 'RECOMPENSA',
        icon: Icon(Icons.card_giftcard, color: Colors.white, size: AppTheme.popupIconSize),
      );
    case 'penalty':
      return const _PopupConfig(
        title: 'PENALIZACIÓN',
        icon: Icon(Icons.card_giftcard, color: Colors.white, size: AppTheme.popupIconSize),
      );
    case 'info':
    default:
      return const _PopupConfig(
        title: 'AVISO',
        icon: Icon(Icons.info_outline, color: Colors.white, size: AppTheme.popupIconSize),
      );
  }
}

Widget _buildContentForType(BuildContext context, Message message) {
  final type = message.type.toLowerCase();

  if (type == 'info') {
    // INFO: Shows title and description
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            '[${message.title}]',
            textAlign: TextAlign.center,
            style: AppTheme.popupContentTitleStyle(context),
          ),
          const SizedBox(height: 12),
          Text(
            message.description,
            textAlign: TextAlign.center,
            style: AppTheme.popupContentDescriptionStyle(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  } else if (type == 'reward' || type == 'penalty') {
    // REWARD/PENALTY: Shows "title: [ questTitle ]" and adjunts list
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Mostrar "title: [ questTitle ]"
          Text(
            '${message.title}: [ ${message.questTitle ?? ''} ]',
            textAlign: TextAlign.center,
            style: AppTheme.popupContentTitleStyle(context),
          ),
          const SizedBox(height: 16),
          // Mostrar adjunts
          if (message.adjunts != null && message.adjunts!.isNotEmpty) ...[
            MessageAdjuntsList(adjunts: message.adjunts!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  } else {
    // Fallback for unknown types
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            message.description,
            textAlign: TextAlign.center,
            style: AppTheme.popupContentDescriptionStyle(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
