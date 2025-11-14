import 'package:flutter/material.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Shows the notification-style quest popup (state 'N').
/// Returns true if the user accepted, false otherwise.
Future<bool> showQuestNotificationPopup(BuildContext context, dynamic quest) async {
  if (!Navigator.of(context).mounted) return false;

  final questId = (quest is Map && (quest['idQuestUser'] ?? quest['id']) != null)
      ? (quest['idQuestUser'] ?? quest['id']).toString()
      : 'unknown';
  final state = (quest is Map && quest['state'] != null) ? quest['state'].toString() : 'unknown';
  debugPrint('⚔️ [showQuestNotificationPopup] Presenting quest $questId (state: $state)');

  // Determine title/header safely from the quest map
  Map<String, dynamic> header = {};
  String title = '—';
  try {
    if (quest is Map) {
      final h = quest['header'];
      if (h is Map<String, dynamic>) header = h;
      title = header['title']?.toString() ?? title;
    }
  } catch (_) {}

  // Determine period label: D->diaria, W->semanal, M->mensual, otherwise blank
  String periodLabel = '';
  try {
    final dynamic p = (quest is Map && quest['period'] != null)
        ? quest['period']
        : (header['period'] ?? header['periodo']);
    if (p != null) {
      final ps = p.toString().toUpperCase();
      if (ps == 'D') {
        periodLabel = 'diaria';
      } else if (ps == 'W') {
        periodLabel = 'semanal';
      } else if (ps == 'M') {
        periodLabel = 'mensual';
      }
    }
  } catch (_) {}

  // Welcome message (newly added field in header)
  String welcome = '';
  try {
    final wm = header['welcomeMessage'] ?? header['welcome_message'] ?? header['welcome'];
    if (wm != null) {
      welcome = wm.toString();
    }
  } catch (_) {}

  final missionLine = periodLabel.isNotEmpty ? 'Nueva misión $periodLabel:' : 'Nueva misión:';

  final child = Material(
    color: Colors.transparent,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: '$missionLine ',
                style: AppTheme.popupContentSubtitleStyle(context),
              ),
              TextSpan(
                text: '[ $title ]',
                style: AppTheme.popupContentTitleStyle(context),
              ),
            ],
          ),
        ),
        if (welcome.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '"$welcome"',
            textAlign: TextAlign.center,
            style: AppTheme.popupContentDescriptionStyle(context).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    ),
  );

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopupForm(
      icon: const Icon(Icons.priority_high, size: AppTheme.popupIconSize),
      title: 'NUEVA MISIÓN',
      actions: [
        PopupActionButton(label: 'Aceptar', onPressed: () => Navigator.of(ctx).pop(true)),
      ],
      child: child,
    ),
  );

  debugPrint('⚔️ [showQuestNotificationPopup] Quest $questId dialog returned -> ${accepted == true ? 'accepted' : 'rejected'}');
  return accepted == true;
}
