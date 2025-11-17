import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/controllers/message_controller.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/coordinated_popups_handler.dart';
import 'package:lagfrontend/widgets/connection_status_banner.dart';
import 'package:lagfrontend/views/home/widgets/home_settings_bar.dart';
import 'package:lagfrontend/views/home/widgets/home_bottom_bar.dart';
import 'package:lagfrontend/views/home/widgets/user_info_panel.dart';

import 'package:lagfrontend/views/home/widgets/unread_messages_panel.dart';
import 'package:lagfrontend/views/home/widgets/active_quests_panel.dart';

import 'package:lagfrontend/services/connectivity_service.dart';

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
    debugPrint('🔵 [HomeScreen.initState] Called (hashCode=${identityHashCode(widget)})');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔵 [HomeScreen.initState] PostFrameCallback executing (hashCode=${identityHashCode(widget)})');
      _initializeHomeScreen();
    });
  }

  /// Inicializa la pantalla: carga datos y luego muestra todos los popups seguidos, refrescando solo al final
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
      // 3. Procesar todos los popups seguidos (sin refresh entre ellos)
      await _processPopupsSequentially();
      // 4. Refrescar datos solo una vez después de cerrar todos los popups
      await auth.refreshAllData(
        messageController: mc,
        questController: qc,
      );
      debugPrint('✅ [$timestamp] [HomeScreen] Datos recargados después de popups');
      if (mounted) {
        setState(() {
          _initialLoadDone = true;
          _initialLoadInProgress = false;
          _popupsProcessed = true;
        });
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

  /// Procesa todos los popups de mensajes y quests secuencialmente, sin refresh entre ellos
  Future<void> _processPopupsSequentially() async {
    final timestamp = DateTime.now().toString().substring(11, 23);
    debugPrint('🔵 [$timestamp] [HomeScreen._processPopupsSequentially] Called (mounted=$mounted, popupsProcessed=$_popupsProcessed)');
    if (!mounted || _popupsProcessed) {
      debugPrint('⚠️ [$timestamp] [HomeScreen._processPopupsSequentially] Skipped (mounted=$mounted, popupsProcessed=$_popupsProcessed)');
      return;
    }
    final mc = Provider.of<MessageController>(context, listen: false);
    final qc = Provider.of<QuestController>(context, listen: false);
    debugPrint('🔄 [$timestamp] [HomeScreen] Iniciando procesamiento de popups secuencial...');
    try {
      // Procesar popups de forma secuencial, sin refresh entre ellos
      await CoordinatedPopupsHandler.processAllPopups(
        context,
        mc,
        qc,
      );
    } catch (e) {
      debugPrint('❌ [$timestamp] [HomeScreen] Error procesando popups: $e');
    }
  }

  // ...el método _processPopups original se elimina, ya que ahora usamos _processPopupsSequentially

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
        // Llamada eliminada: _processPopups() ya no existe ni es necesaria
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error refrescando datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ConnectivityService>(
          builder: (context, connectivity, _) {
            if (connectivity.shouldBlockUI) {
              // Bloquear la UI completamente si no hay conexión o backend arrancando
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      connectivity.getConnectionStatusMessage(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (connectivity.status == ConnectionStatus.backendStarting)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'El servidor está arrancando (puede tardar ~30s)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              );
            }
            // UI normal si hay conexión
            return RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Connection status banner (solo visible cuando hay problemas)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: ConnectionStatusBanner(),
                    ),
                    const SizedBox(height: 8),
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
            );
          },
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: HomeBottomBar(),
      ),
    );
  }
}