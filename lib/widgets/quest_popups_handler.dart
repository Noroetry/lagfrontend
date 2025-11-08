import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/popup_form.dart';

/// Widget that listens to QuestController and shows sequential popups for
/// quests with state 'N' (notification) or 'P' (parameter form), reusing
/// the app's `PopupForm` styling.
class QuestPopupsHandler extends StatefulWidget {
  const QuestPopupsHandler({super.key});

  @override
  State<QuestPopupsHandler> createState() => _QuestPopupsHandlerState();
}

class _QuestPopupsHandlerState extends State<QuestPopupsHandler> {
  final Set<dynamic> _shownQuestIds = {}; // track shown quests to avoid repeats
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processQuests());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestController>(builder: (context, qc, child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processQuests());
      return const SizedBox.shrink();
    });
  }

  Future<void> _processQuests() async {
    if (!mounted) return;
    if (_isShowing) return;
    final qc = Provider.of<QuestController>(context, listen: false);
    final quests = qc.quests;
    if (quests.isEmpty) return;

    final pending = <dynamic>[];
    for (final q in quests) {
      try {
        final state = (q is Map && q['state'] != null) ? q['state'].toString() : null;
        final id = (q is Map && q['id'] != null) ? q['id'] : null;
        if (state != null && (state == 'N' || state == 'P') && id != null && !_shownQuestIds.contains(id)) {
          pending.add(q);
        }
      } catch (_) {}
    }

    if (pending.isEmpty) return;

    _isShowing = true;
    for (final q in pending) {
      if (!mounted) break;
      final id = q['id'];
      final state = q['state'];
      final header = q['header'] ?? {};
      final questTitle = header is Map && header['title'] != null ? header['title'].toString() : 'Quest';

      if (state == 'N') {
        await _showNotificationPopup(id, questTitle);
      } else if (state == 'P') {
        await _showFormPopup(id, questTitle, q);
      }

      _shownQuestIds.add(id);
    }
    _isShowing = false;
  }

  Future<void> _showNotificationPopup(dynamic id, String questTitle) async {
    if (!mounted) return;
    // When user accepts, call backend activate and then show QUEST INFO popup
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopupForm(
        icon: const Icon(Icons.priority_high),
        title: 'QUEST',
        description: '$questTitle\nEstado: N\nID: $id',
        actions: [
          PopupActionButton(
            label: 'Aceptar',
            onPressed: () async {
              // Capture controller reference synchronously to avoid using BuildContext across await
              final qc = Provider.of<QuestController>(context, listen: false);
              // Close the notification dialog first
              Navigator.of(ctx).pop();
              try {
                final activated = await qc.activateQuest(id);
                if (!mounted) return;
                if (activated.isNotEmpty) {
                  final info = activated.first;
                  // show info popup
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx2) => PopupForm(
                      icon: const Icon(Icons.menu_book),
                      title: 'QUEST INFO',
                      description: _buildQuestInfoSummary(info),
                      actions: [PopupActionButton(label: 'Aceptar', onPressed: () => Navigator.of(ctx2).pop())],
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ [QuestPopupsHandler] activate error: $e');
                // Optionally show an error dialog here
              }
            },
          ),
        ],
      ),
    );
  }

  String _buildQuestInfoSummary(dynamic info) {
    try {
      if (info is Map<String, dynamic>) {
        final header = info['header'] ?? {};
        final title = header is Map && header['title'] != null ? header['title'].toString() : '—';
        final description = header is Map && header['description'] != null ? header['description'].toString() : '';
        final state = info['state']?.toString() ?? '';
        return 'Título: $title\nEstado: $state\n\n$description';
      }
    } catch (_) {}
    return 'Información de la quest';
  }

  Future<void> _showFormPopup(dynamic id, String questTitle, dynamic quest) async {
    if (!mounted) return;
    final details = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

    // Helper to treat several possible truthy representations from backend
    bool needsParam(Object? v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
      }
      return false;
    }

    // Collect only the details that require an initial parameter and keep them
    // paired with controllers so we can show description per field.
    final paramDetails = <Map<String, dynamic>>[];
    for (final d in details) {
      if (d is Map && needsParam(d['needParam'])) paramDetails.add(Map<String, dynamic>.from(d));
    }

    final controllers = List<TextEditingController>.generate(paramDetails.length, (_) => TextEditingController());
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopupForm(
        icon: const Icon(Icons.priority_high),
        title: 'QUEST',
        description: '$questTitle\nEstado: P\nID: $id',
        actions: [
          PopupActionButton(
            label: 'Aceptar',
            onPressed: () {
              // Validate form before closing
              final valid = formKey.currentState?.validate() ?? true;
              if (valid) Navigator.of(ctx).pop();
            },
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  if (controllers.isEmpty) const Text('No se requieren parámetros iniciales.'),
                  ...List<Widget>.generate(controllers.length, (i) {
                    final detail = paramDetails[i];
                    final label = detail['description']?.toString() ?? 'Valor inicial';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: TextFormField(
                        controller: controllers[i],
                        decoration: InputDecoration(labelText: label),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          return null;
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Dispose controllers after the dialog has fully popped and a frame has
    // been rendered to avoid "used after disposed" errors when the
    // TextFormField still rebuilds during the pop animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        try {
          c.dispose();
        } catch (_) {}
      }
    });
  }
}
