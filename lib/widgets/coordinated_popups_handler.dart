import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/message_detail_popup.dart';
import 'package:lagfrontend/widgets/quest_notification_popup.dart';
import 'package:lagfrontend/widgets/quest_form_popup.dart';

/// Coordinated handler that shows messages FIRST (one by one), then quests.
/// This ensures popups don't overlap and messages have priority.
/// 
/// WORKFLOW:
/// 1. Wait for both MessageController and QuestController to finish loading
/// 2. Show ALL unread messages one by one (user must accept each one)
/// 3. After all messages are shown, show quests (state 'N' first, then 'P')
/// 4. Each popup closes completely before the next one opens
/// 5. When ALL popups are done, calls onComplete callback to trigger a refresh
/// 
/// KEY PRINCIPLES:
/// - Uses manual listeners instead of Consumer to avoid rebuild loops
/// - Operations (markAsRead, activateQuest) update local state only
/// - NO intermediate reloads from backend during processing
/// - Single refresh at the end via onComplete callback
class CoordinatedPopupsHandler extends StatefulWidget {
  /// Callback invoked when all popups have been processed
  /// Use this to refresh data from backend if needed
  final VoidCallback? onComplete;
  
  const CoordinatedPopupsHandler({super.key, this.onComplete});

  @override
  State<CoordinatedPopupsHandler> createState() => _CoordinatedPopupsHandlerState();
}

class _CoordinatedPopupsHandlerState extends State<CoordinatedPopupsHandler> {
  final Set<String> _shownMessageIds = <String>{};
  final Set<String> _shownQuestIds = <String>{};
  Completer<void>? _processingCompleter;
  bool _isProcessing = false;
  Timer? _debounceTimer;
  
  // Track listeners to avoid duplicate registrations
  bool _listenersRegistered = false;

  @override
  void initState() {
    super.initState();
    // Register listeners in initState to ensure it's only called once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_listenersRegistered) {
        _registerListeners();
        _listenersRegistered = true;
        // Initial check after listeners are ready
        _scheduleCheck();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies can be called multiple times
    // We ensure listeners are registered only once via the flag
  }

  /// Register manual listeners to avoid excessive rebuilds from Consumer2
  void _registerListeners() {
    try {
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);
      
      mc.addListener(_scheduleCheck);
      qc.addListener(_scheduleCheck);
      
      debugPrint('👂 [CoordinatedPopupsHandler] Listeners registered');
    } catch (e) {
      debugPrint('⚠️ [CoordinatedPopupsHandler] Error registering listeners: $e');
    }
  }

  /// Schedule a check with debouncing to avoid rapid-fire calls
  void _scheduleCheck() {
    if (!mounted) return;
    
    // Cancel any pending check
    _debounceTimer?.cancel();
    
    // Schedule a new check after a short delay
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isProcessing) {
        _checkAndProcess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Simple widget that doesn't rebuild on every controller change
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    
    // Unregister listeners
    try {
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);
      
      mc.removeListener(_scheduleCheck);
      qc.removeListener(_scheduleCheck);
      
      debugPrint('👋 [CoordinatedPopupsHandler] Listeners removed');
    } catch (e) {
      debugPrint('⚠️ [CoordinatedPopupsHandler] Error removing listeners: $e');
    }
    
    super.dispose();
  }

  /// Check if both controllers are ready and start processing
  Future<void> _checkAndProcess() async {
    if (!mounted) return;
    
    final timestamp = DateTime.now().toString().substring(11, 23); // HH:MM:SS.mmm
    
    // If already processing, return immediately (check and set atomically)
    if (_isProcessing) {
      debugPrint('⚠️ [$timestamp] [CoordinatedPopupsHandler] Already processing, skipping...');
      return;
    }
    
    // Mark as processing IMMEDIATELY to prevent race conditions
    _isProcessing = true;
    debugPrint('🔒 [$timestamp] [CoordinatedPopupsHandler] Lock acquired, starting processing');

    try {
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);

      // Wait until both controllers finish loading
      if (mc.isLoading || qc.isLoading) {
        debugPrint('⏳ [$timestamp] [CoordinatedPopupsHandler] Waiting for data... MC:${mc.isLoading} QC:${qc.isLoading}');
        return;
      }

      // Check if there's anything to process
      final hasUnreadMessages = mc.unreadMessages.any((msg) => !_shownMessageIds.contains(msg.id.toString()));
      final hasNewQuests = qc.quests.any((q) {
        if (q is! Map) return false;
        final state = q['state']?.toString();
        final id = q['idQuestUser'] ?? q['id'];
        final idKey = id?.toString();
        return idKey != null &&
               (state == 'N' || state == 'P') &&
               !_shownQuestIds.contains(idKey);
      });

      if (!hasUnreadMessages && !hasNewQuests) {
        debugPrint('ℹ️ [$timestamp] [CoordinatedPopupsHandler] Nothing to process (shown: ${_shownMessageIds.length} msgs, ${_shownQuestIds.length} quests)');
        return;
      }

      debugPrint('🎬 [$timestamp] [CoordinatedPopupsHandler] Starting popup processing (${mc.unreadMessages.length} msgs, ${qc.quests.length} quests)...');
      
      _processingCompleter = Completer<void>();
      await _processAllPopups();
      
      if (!_processingCompleter!.isCompleted) {
        _processingCompleter!.complete();
      }
      
      debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Processing completed successfully');
    } catch (e) {
      debugPrint('❌ [$timestamp] [CoordinatedPopupsHandler] Error during processing: $e');
    } finally {
      // Always reset processing flag
      _isProcessing = false;
      debugPrint('🔓 [$timestamp] [CoordinatedPopupsHandler] Lock released');
    }
  }

  /// Main processing logic: messages first, then quests
  Future<void> _processAllPopups() async {
    if (!mounted) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('📬 [$timestamp] [CoordinatedPopupsHandler] Step 1: Processing messages...');
    await _processAllMessages();
    
    debugPrint('⚔️ [$timestamp] [CoordinatedPopupsHandler] Step 2: Processing quests...');
    await _processAllQuests();
    
    debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] All popups processed');
    
    // Call onComplete callback to signal HomeScreen to refresh if needed
    if (widget.onComplete != null) {
      debugPrint('🔄 [$timestamp] [CoordinatedPopupsHandler] Calling onComplete callback for refresh...');
      widget.onComplete!();
    }
  }

  // ==================== MESSAGES ====================
  
  /// Process all unread messages one by one
  Future<void> _processAllMessages() async {
    if (!mounted) return;

    final mc = Provider.of<MessageController>(context, listen: false);

    while (mounted) {
      final unreadMessages = mc.unreadMessages;

      // Find the next unshown message
      final nextMessage = unreadMessages.where(
        (msg) => !_shownMessageIds.contains(msg.id.toString()),
      ).firstOrNull;

      if (nextMessage == null) {
        debugPrint('📭 [CoordinatedPopupsHandler] No more unread messages');
        break;
      }

      await _showAndProcessMessage(nextMessage, mc);
    }
  }

  /// Show a single message popup and wait for user to accept
  Future<void> _showAndProcessMessage(dynamic message, MessageController mc) async {
    if (!mounted) return;
    if (message == null) return;

  final messageId = message.id as int;
  final messageKey = messageId.toString();
  if (_shownMessageIds.contains(messageKey)) return;

    // Mark as shown BEFORE displaying to prevent duplicate popups
  _shownMessageIds.add(messageKey);

    debugPrint('📨 [CoordinatedPopupsHandler] Showing message $messageId');

    // Show the message popup and WAIT for user to close it
    await showMessageDetailPopup(context, message);

    debugPrint('✅ [CoordinatedPopupsHandler] Message $messageId popup closed');

    // IMPORTANT: Wait for dialog animation to complete (Flutter's default is ~200ms)
    await Future.delayed(const Duration(milliseconds: 300));

    // AFTER the popup is closed, mark as read
    if (!mounted) return;
    try {
      await mc.markAsRead(messageId);
      debugPrint('✅ [CoordinatedPopupsHandler] Message $messageId marked as read');
    } catch (e) {
      debugPrint('❌ [CoordinatedPopupsHandler] Error marking message $messageId as read: $e');
    }

    // Small delay before showing next popup
    await Future.delayed(const Duration(milliseconds: 150));
  }

  // ==================== QUESTS ====================
  
  /// Process all new quests (state 'N' first, then 'P')
  Future<void> _processAllQuests() async {
    if (!mounted) return;

    // Process all 'N' quests first
    await _processQuestsWithState('N');
    
    // Then process all 'P' quests
    await _processQuestsWithState('P');
  }

  /// Process all quests with a specific state
  Future<void> _processQuestsWithState(String targetState) async {
    if (!mounted) return;

    final qc = Provider.of<QuestController>(context, listen: false);

    while (mounted) {
      final allQuests = qc.quests;

      // Find the next unshown quest with the target state
      dynamic nextQuest;
      for (final q in allQuests) {
        if (q is! Map) continue;
        
        final state = q['state']?.toString();
        final id = q['idQuestUser'] ?? q['id'];
        final idKey = id?.toString();

        if (state == targetState && idKey != null && !_shownQuestIds.contains(idKey)) {
          nextQuest = q;
          break;
        }
      }

      if (nextQuest == null) {
        debugPrint('⚔️ [CoordinatedPopupsHandler] No more quests with state $targetState');
        break;
      }

      await _showAndProcessQuest(nextQuest, qc);
    }
  }

  /// Show and process a single quest
  Future<void> _showAndProcessQuest(dynamic quest, QuestController qc) async {
    if (!mounted) return;
    if (quest is! Map) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    final id = quest['idQuestUser'] ?? quest['id'];
    if (id == null) return;
    final idKey = id.toString();
    
    // CRITICAL: Check if already shown to prevent duplicates
    if (_shownQuestIds.contains(idKey)) {
      debugPrint('⚠️ [$timestamp] [CoordinatedPopupsHandler] Quest $id already shown, skipping DUPLICATE');
      return;
    }

    // Mark as shown BEFORE displaying
    _shownQuestIds.add(idKey);

    final state = quest['state']?.toString();
    final header = quest['header'] as Map<String, dynamic>? ?? {};
    final title = header['title']?.toString() ?? 'Quest';

    debugPrint('⚔️ [$timestamp] [CoordinatedPopupsHandler] Showing quest $id (state: $state, title: "$title")');

    if (state == 'N') {
      await _processNormalQuest(id, quest, title, qc);
    } else if (state == 'P') {
      await _processParametricQuest(id, quest, title, qc);
    }
  }

  /// Process a normal quest (state 'N')
  Future<void> _processNormalQuest(dynamic id, Map quest, String title, QuestController qc) async {
    if (!mounted) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    
    // Show notification popup
    final accepted = await showQuestNotificationPopup(context, quest);
    
    debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Quest $id notification closed (accepted: $accepted)');
    
    // IMPORTANT: Wait for dialog animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    if (!accepted) {
      debugPrint('❌ [$timestamp] [CoordinatedPopupsHandler] Quest $id rejected by user');
      return;
    }

    // User accepted, activate the quest
    if (!mounted) return;
    try {
      debugPrint('🔄 [$timestamp] [CoordinatedPopupsHandler] Activating quest $id...');
      final activated = await qc.activateQuest(id);
      debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Quest $id activated (returned ${activated.length} quests)');
      
      // If activation returns new quests, process them recursively
      if (activated.isNotEmpty) {
        debugPrint('🔁 [$timestamp] [CoordinatedPopupsHandler] Processing ${activated.length} new quests from activation...');
        for (final newQuest in activated) {
          await _showAndProcessQuest(newQuest, qc);
        }
      }
    } catch (e) {
      debugPrint('❌ [$timestamp] [CoordinatedPopupsHandler] Error activating quest $id: $e');
    }

    // Small delay before next quest
    await Future.delayed(const Duration(milliseconds: 150));
  }

  /// Process a parametric quest (state 'P')
  Future<void> _processParametricQuest(dynamic id, Map quest, String title, QuestController qc) async {
    if (!mounted) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    
    // Show notification popup
    final accepted = await showQuestNotificationPopup(context, quest);
    
    debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Quest $id notification closed (accepted: $accepted)');
    
    // IMPORTANT: Wait for dialog animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    if (!accepted) {
      debugPrint('❌ [$timestamp] [CoordinatedPopupsHandler] Quest $id rejected by user');
      return;
    }

    // Show form popup - this internally calls submitParamsForQuest which activates the quest
    if (!mounted) return;
    debugPrint('📝 [$timestamp] [CoordinatedPopupsHandler] Showing form for quest $id...');
    final params = await showQuestFormPopup(context, id, title, quest);
    
    debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Quest $id form closed (params: ${params?.length ?? 0})');
    
    // IMPORTANT: Wait for dialog animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    if (params == null || params.isEmpty) {
      debugPrint('❌ [$timestamp] [CoordinatedPopupsHandler] Quest $id form cancelled or empty');
      return;
    }

  // Form was submitted con éxito; el backend procesa submit-params y activa la quest en la misma transacción,
  // devolviendo el payload actualizado (generalmente la quest ya en estado activo o nuevas dependencias).
  debugPrint('✅ [$timestamp] [CoordinatedPopupsHandler] Quest $id activated with params (returned ${params.length} quests)');
    
    // If submission returns new quests, process them recursively
    if (params.isNotEmpty) {
      debugPrint('🔁 [$timestamp] [CoordinatedPopupsHandler] Processing ${params.length} new quests from form submission...');
      for (final newQuest in params) {
        if (newQuest is Map) {
          await _showAndProcessQuest(newQuest, qc);
        }
      }
    }

    // Small delay before next quest
    await Future.delayed(const Duration(milliseconds: 150));
  }
}
