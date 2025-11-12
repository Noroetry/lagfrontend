import 'package:flutter/material.dart';
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
              // This prevents popups from overlapping
              const CoordinatedPopupsHandler(),
            ],
          ),
        ),
      ),
    );
  }
}