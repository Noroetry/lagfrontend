import 'package:flutter/material.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Shows a detailed message popup when tapping a message.
/// Displays the message description with an "Aceptar" button.
Future<void> showMessageDetailPopup(
  BuildContext context,
  Message message,
) async {
  if (!context.mounted) return;

  debugPrint('📨 [showMessageDetailPopup] Presenting message ${message.id}');
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final child = Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              message.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );

      return PopupForm(
        title: 'MENSAJE',
        icon: const Icon(Icons.mail_outline, color: Colors.white, size: 24),
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
  debugPrint('📨 [showMessageDetailPopup] Message ${message.id} dialog returned');
}
