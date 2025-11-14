import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/coordinated_popups_handler.dart';
import 'package:lagfrontend/views/home/widgets/home_settings_bar.dart';
import 'package:lagfrontend/views/home/widgets/home_bottom_bar.dart';
import 'package:lagfrontend/views/home/widgets/user_info_panel.dart';
import 'package:lagfrontend/views/home/widgets/active_quests_panel.dart';
import 'package:lagfrontend/views/home/widgets/unread_messages_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialLoadDone = false;
  bool _initialLoadInProgress = false;
  bool _popupsProcessed = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 [HomeScreen.initState] Called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔵 [HomeScreen.initState] PostFrameCallback executing');
      _initializeHomeScreen();
    });
  }

  /// Inicializa la pantalla: carga datos y luego procesa popups
  Future<void> _initializeHomeScreen() async {
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🔵 [$timestamp] [HomeScreen._initializeHomeScreen] Called (mounted=$mounted, done=$_initialLoadDone, inProgress=$_initialLoadInProgress)');
    
    if (!mounted || _initialLoadDone || _initialLoadInProgress) {
      debugPrint('⚠️ [$timestamp] [HomeScreen._initializeHomeScreen] Skipped (mounted=$mounted, done=$_initialLoadDone, inProgress=$_initialLoadInProgress)');
      return;
    }

    _initialLoadInProgress = true;
    debugPrint('🚀 [$timestamp] [HomeScreen] Iniciando carga inicial de datos...');

    final auth = Provider.of<AuthController>(context, listen: false);
    final mc = Provider.of<MessageController>(context, listen: false);
    final qc = Provider.of<QuestController>(context, listen: false);

    try {
      // 1. Verificar conexión
      final connected = await auth.verifyConnection();
      if (!connected) {
        debugPrint('⚠️ [$timestamp] [HomeScreen] Sin conexión al backend');
        if (mounted) {
          setState(() {
            _initialLoadInProgress = false;
          });
        }
        return;
      }

      // 2. Cargar datos usando el método centralizado
      await auth.refreshAllData(
        messageController: mc,
        questController: qc,
      );

      debugPrint('✅ [$timestamp] [HomeScreen] Datos cargados correctamente');

      if (mounted) {
        setState(() {
          _initialLoadDone = true;
          _initialLoadInProgress = false;
        });

        // 3. Procesar popups después de cargar datos
        await _processPopups();
      }
    } catch (e) {
      debugPrint('❌ [$timestamp] [HomeScreen] Error cargando datos: $e');
      if (mounted) {
        setState(() {
          _initialLoadInProgress = false;
        });
        
        // Reintentar después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_initialLoadInProgress && !_initialLoadDone) {
            _initializeHomeScreen();
          }
        });
      }
    }
  }

  /// Procesa todos los popups de mensajes y quests secuencialmente
  Future<void> _processPopups() async {
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🔵 [$timestamp] [HomeScreen._processPopups] Called (mounted=$mounted, popupsProcessed=$_popupsProcessed)');
    
    if (!mounted || _popupsProcessed) {
      debugPrint('⚠️ [$timestamp] [HomeScreen._processPopups] Skipped (mounted=$mounted, popupsProcessed=$_popupsProcessed)');
      return;
    }

    final mc = Provider.of<MessageController>(context, listen: false);
    final qc = Provider.of<QuestController>(context, listen: false);

    debugPrint('🔄 [$timestamp] [HomeScreen] Iniciando procesamiento de popups...');

    try {
      // Procesar popups de forma secuencial
      final processedAny = await CoordinatedPopupsHandler.processAllPopups(
        context,
        mc,
        qc,
      );

      if (!mounted) return;

      if (processedAny) {
        debugPrint('✅ [HomeScreen] Popups procesados, recargando datos usando refreshAllData...');
        
        final auth = Provider.of<AuthController>(context, listen: false);
        
        // Usar el método centralizado para garantizar consistencia
        await auth.refreshAllData(
          messageController: mc,
          questController: qc,
        );

        if (mounted) {
          setState(() {
            _popupsProcessed = true;
          });
          debugPrint('✅ [HomeScreen] Datos recargados después de popups');
        }
      } else {
        debugPrint('ℹ️ [HomeScreen] No había popups pendientes');
        if (mounted) {
          setState(() {
            _popupsProcessed = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error procesando popups: $e');
    }
  }

  /// Refresca los datos manualmente (ej. al hacer pull-to-refresh)
  Future<void> _refreshData() async {
    if (!mounted) return;

    final auth = Provider.of<AuthController>(context, listen: false);
    final mc = Provider.of<MessageController>(context, listen: false);
    final qc = Provider.of<QuestController>(context, listen: false);

    debugPrint('🔄 [HomeScreen] Refrescando datos usando refreshAllData...');

    try {
      // Usar el método centralizado para garantizar consistencia
      await auth.refreshAllData(
        messageController: mc,
        questController: qc,
      );

      debugPrint('✅ [HomeScreen] Datos refrescados');

      if (mounted) {
        // Resetear flag de popups procesados para permitir mostrar nuevos popups
        setState(() {
          _popupsProcessed = false;
        });
        
        // Procesar popups después del refresco
        await _processPopups();
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error refrescando datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top settings bar with support icons
                const HomeSettingsBar(),

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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: HomeBottomBar(),
      ),
    );
  }
}