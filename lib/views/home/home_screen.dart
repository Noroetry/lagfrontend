import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/coordinated_popups_handler.dart';
import 'package:lagfrontend/views/home/widgets/home_app_bar.dart';
import 'package:lagfrontend/views/home/widgets/user_info_panel.dart';
import 'package:lagfrontend/views/home/widgets/active_quests_panel.dart';
import 'package:lagfrontend/views/home/widgets/unread_messages_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRefreshing = false;
  bool _initialLoadDone = false;
  bool _initialLoadInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInitialDataLoaded());
  }

  Future<void> _ensureInitialDataLoaded() async {
    if (!mounted || _initialLoadDone || _initialLoadInProgress) return;

    _initialLoadInProgress = true;
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🚀 [$timestamp] [HomeScreen] Starting initial data bootstrap...');

    var success = false;
    try {
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);

      await Future.wait([
        mc.loadMessages(),
        qc.loadQuests(),
      ]);

      debugPrint('✅ [$timestamp] [HomeScreen] Initial data bootstrap completed');
      success = true;
    } catch (e) {
      debugPrint('❌ [$timestamp] [HomeScreen] Initial data bootstrap failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initialLoadInProgress = false;
          _initialLoadDone = success;
        });

        if (!success) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            if (!_initialLoadInProgress && !_initialLoadDone) {
              _ensureInitialDataLoaded();
            }
          });
        }
      }
    }
  }

  /// Called when CoordinatedPopupsHandler finishes processing all popups
  /// Refreshes data from backend and triggers popup processing again if needed
  Future<void> _onPopupsComplete() async {
    if (!mounted || _isRefreshing || _initialLoadInProgress) return;
    
    setState(() => _isRefreshing = true);
    
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🔄 [$timestamp] [HomeScreen] Refreshing data after popups completed...');
    
    try {
      final mc = Provider.of<MessageController>(context, listen: false);
      final qc = Provider.of<QuestController>(context, listen: false);
      
      // Refresh messages and quests from backend
      await Future.wait([
        mc.loadMessages(),
        qc.loadQuests(),
      ]);
      
      debugPrint('✅ [$timestamp] [HomeScreen] Refresh completed');
      // CoordinatedPopupsHandler will detect new data and process if needed
    } catch (e) {
      debugPrint('❌ [$timestamp] [HomeScreen] Error refreshing: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top action bar with icons
              const HomeAppBar(),

              const SizedBox(height: 12),

              // User info panel
              const UserInfoPanel(),

              const SizedBox(height: 8),

              // Messages section title
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Mensajes pendientes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Unread messages panel
              const UnreadMessagesPanel(),

              const SizedBox(height: 8),

              // Quests section title
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Misiones',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Active quests panel
              const ActiveQuestsPanel(),

              // Coordinated handler that shows messages FIRST, then quests
              // When all popups are done, triggers a refresh to check for new data
              CoordinatedPopupsHandler(onComplete: _onPopupsComplete),
            ],
          ),
        ),
      ),
    );
  }
}