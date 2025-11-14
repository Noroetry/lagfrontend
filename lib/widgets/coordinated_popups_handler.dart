import 'package:flutter/material.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/message_detail_popup.dart';
import 'package:lagfrontend/widgets/quest_form_popup.dart';
import 'package:lagfrontend/widgets/quest_notification_popup.dart';
import 'package:lagfrontend/utils/quest_helpers.dart';

/// Procesa popups de mensajes y quests de forma secuencial.
/// 
/// Flujo:
/// 1. Muestra todos los mensajes no leídos uno por uno
/// 2. Muestra todas las quests con state 'N' una por una (acepta y activa)
/// 3. Muestra todas las quests con state 'P' una por una (acepta, form, submit)
/// 
/// Este proceso es completamente síncrono y secuencial para evitar duplicaciones.
class CoordinatedPopupsHandler {
  /// Ejecuta el flujo completo de popups para el contexto dado
  /// Retorna true si se procesó al menos un popup
  static Future<bool> processAllPopups(
    BuildContext context,
    MessageController messageController,
    QuestController questController,
  ) async {
    if (!context.mounted) return false;

    debugPrint('🔄 [CoordinatedPopupsHandler] Iniciando procesamiento de popups...');
    
    var processedAny = false;

    // 1. Procesar mensajes primero
    processedAny |= await _processMessages(context, messageController);
    if (!context.mounted) return processedAny;

    // 2. Procesar quests con state 'N'
    processedAny |= await _processQuestsByState(context, questController, 'N');
    if (!context.mounted) return processedAny;

    // 3. Procesar quests con state 'P'
    processedAny |= await _processQuestsByState(context, questController, 'P');

    debugPrint('✅ [CoordinatedPopupsHandler] Procesamiento completado. Procesados: $processedAny');
    
    return processedAny;
  }

  /// Procesa todos los mensajes no leídos secuencialmente
  static Future<bool> _processMessages(BuildContext context, MessageController mc) async {
    var processed = false;

    while (true) {
      if (!context.mounted) break;
      
      // Obtener el siguiente mensaje no leído
      final unreadMessages = mc.messages.where((m) => !m.isRead).toList();
      if (unreadMessages.isEmpty) break;
      
      final message = unreadMessages.first;
      debugPrint('📬 [CoordinatedPopupsHandler] Mostrando mensaje ${message.id}');
      
      processed = true;
      
      // Mostrar popup del mensaje
      await showMessageDetailPopup(context, message);
      if (!context.mounted) return processed;

      // Marcar como leído
      try {
        await mc.markAsRead(message.id);
        debugPrint('✅ [CoordinatedPopupsHandler] Mensaje ${message.id} marcado como leído');
      } catch (e) {
        debugPrint('❌ [CoordinatedPopupsHandler] Error marcando mensaje ${message.id}: $e');
        break;
      }
    }

    return processed;
  }

  /// Procesa todas las quests con el estado especificado secuencialmente
  static Future<bool> _processQuestsByState(
    BuildContext context,
    QuestController qc,
    String targetState,
  ) async {
    var processed = false;

    while (true) {
      if (!context.mounted) break;
      
      // Buscar la siguiente quest con el estado objetivo
      Map<dynamic, dynamic>? quest;
      for (final q in qc.quests) {
        if (q is Map) {
          final state = q['state']?.toString();
          if (state == targetState) {
            quest = q;
            break;
          }
        }
      }
      
      if (quest == null) break;

      final questId = quest['idQuestUser'] ?? quest['id'];
      if (questId == null) continue;
      
      final questTitle = getQuestTitle(quest);
      debugPrint('⚔️ [CoordinatedPopupsHandler] Mostrando quest $questId (state: $targetState)');
      
      processed = true;

      // Mostrar popup de notificación de la quest
      final accepted = await showQuestNotificationPopup(context, quest);
      if (!context.mounted) return processed;
      
      if (!accepted) {
        debugPrint('⚠️ [CoordinatedPopupsHandler] Quest $questId rechazada por el usuario');
        continue;
      }

      // Procesar según el tipo de quest
      if (targetState == 'N') {
        // Quest tipo N: solo activar
        try {
          await qc.activateQuest(questId);
          debugPrint('✅ [CoordinatedPopupsHandler] Quest $questId activada');
        } catch (e) {
          debugPrint('❌ [CoordinatedPopupsHandler] Error activando quest $questId: $e');
          break;
        }
      } else if (targetState == 'P') {
        // Quest tipo P: mostrar formulario y enviar parámetros
        try {
          final result = await showQuestFormPopup(context, questId, questTitle, quest);
          if (!context.mounted) return processed;
          
          if (result == null || result.isEmpty) {
            debugPrint('⚠️ [CoordinatedPopupsHandler] Quest $questId: formulario cancelado o vacío');
          } else {
            debugPrint('✅ [CoordinatedPopupsHandler] Quest $questId: parámetros enviados correctamente');
          }
        } catch (e) {
          debugPrint('❌ [CoordinatedPopupsHandler] Error procesando quest $questId: $e');
          break;
        }
      }
    }

    return processed;
  }
}
