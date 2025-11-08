import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      _isShowing = true;
      try {
        while (mounted) {
          // ignore: use_build_context_synchronously
          final qc = Provider.of<QuestController>(context, listen: false);
          final questsNow = qc.quests;

          // Helper to get state/id safely
          String? stateOf(dynamic q) {
            try {
              return (q is Map && q['state'] != null) ? q['state'].toString() : null;
            } catch (_) {
              return null;
            }
          }

          dynamic idOf(dynamic q) {
            try {
              if (q is Map && q['idQuestUser'] != null) return q['idQuestUser'];
              if (q is Map && q['id'] != null) return q['id'];
              return null;
            } catch (_) {
              return null;
            }
          }

          // Find any unshown 'N' quest first
          dynamic nextQuest;
          for (final q in questsNow) {
            final s = stateOf(q);
            final id = idOf(q);
            if (s != null && s == 'N' && id != null && !_shownQuestIds.contains(id)) {
              nextQuest = q;
              break;
            }
          }

          // If no 'N', find an unshown 'P' quest
          if (nextQuest == null) {
            for (final q in questsNow) {
              final s = stateOf(q);
              final id = idOf(q);
              if (s != null && s == 'P' && id != null && !_shownQuestIds.contains(id)) {
                nextQuest = q;
                break;
              }
            }
          }

          if (nextQuest == null) break; // nothing left to show

          await _processQuest(nextQuest);

        }
      } finally {
        _isShowing = false;
      }
    }

  Future<bool> _showNotificationPopup(dynamic id, String questTitle) async {
    if (!mounted) return false;

  // ignore: use_build_context_synchronously
  final parentNav = Navigator.of(context);
    final accepted = await showDialog<bool>(
      context: parentNav.context,
      barrierDismissible: false,
      builder: (ctx) => PopupForm(
        icon: const Icon(Icons.priority_high),
        title: 'QUEST',
        description: '$questTitle\nEstado: N\nID: $id',
        actions: [
          PopupActionButton(
            label: 'Aceptar',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  Future<void> _processQuest(dynamic quest) async {
    if (!mounted) return;
    if (quest == null) return;

    final id = (quest is Map && quest['idQuestUser'] != null)
        ? quest['idQuestUser']
        : (quest is Map && quest['id'] != null ? quest['id'] : null);
    if (id == null) return;
    if (_shownQuestIds.contains(id)) return;

    final state = quest is Map && quest['state'] != null ? quest['state'].toString() : null;
    final header = quest is Map ? (quest['header'] ?? {}) : {};
    final title = header is Map && header['title'] != null ? header['title'].toString() : 'Quest';

    final qc = Provider.of<QuestController>(context, listen: false);

    if (state == 'N') {
      final accepted = await _showNotificationPopup(id, title);
      if (!accepted) {
        _shownQuestIds.add(id);
        return;
      }

  // ignore: use_build_context_synchronously
  final parentNav = Navigator.of(context);
      try {
        final activated = await qc.activateQuest(id);
        if (!mounted) return;
        if (activated.isNotEmpty) {
          final info = activated.first;
          await showDialog<void>(
            context: parentNav.context,
            barrierDismissible: false,
            builder: (ctx2) => PopupForm(
              icon: const Icon(Icons.menu_book),
              title: 'QUEST INFO',
              description: _buildQuestInfoSummary(info),
              actions: [PopupActionButton(label: 'Aceptar', onPressed: () => Navigator.of(ctx2).pop())],
            ),
          );

          // Recursively process any quest returned by the backend.
          await _processQuest(info);
        }
      } catch (e) {
        debugPrint('❌ [_processQuest activate] error: $e');
      } finally {
        _shownQuestIds.add(id);
      }
    } else if (state == 'P') {
      try {
        final submitted = await _showFormPopup(id, title, quest);

        if (submitted != null && submitted.isNotEmpty) {
          final next = submitted.first;
          // Process any quest returned by the backend before marking this
          // quest as shown. This allows the backend to return the same
          // quest with updated state (e.g., from 'P' -> 'N') and have it
          // processed immediately.
          await _processQuest(next);
        }
      } catch (e) {
        debugPrint('❌ [_processQuest submit] error: $e');
      } finally {
        // Mark this quest as shown regardless to avoid re-showing the same
        // form repeatedly on subsequent cycles.
        _shownQuestIds.add(id);
      }
    }
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

  Future<List<dynamic>?> _showFormPopup(dynamic id, String questTitle, dynamic quest) async {
    if (!mounted) return null;
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

    final result = await showDialog<List<dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopupForm(
        icon: const Icon(Icons.priority_high),
        title: 'QUEST',
        description: '$questTitle\nEstado: P\nID: $id',
        actions: [
          PopupActionButton(
            label: 'Aceptar',
            onPressed: () async {
              // Validate form before attempting submit
              final valid = formKey.currentState?.validate() ?? true;
              if (!valid) return;

              // Collect raw input values
              final inputValues = controllers.map((c) => c.text).toList();

              // Call controller to validate and submit
              final qc = Provider.of<QuestController>(context, listen: false);
              // Capture navigator states before awaiting to avoid using BuildContext
              final parentNav = Navigator.of(context);
              final rootNav = Navigator.of(context, rootNavigator: true);
              final dialogNav = Navigator.of(ctx);

              try {
                showDialog<void>(context: parentNav.context, barrierDismissible: false, builder: (ctxLoading) => const Center(child: CircularProgressIndicator()));

                final submitted = await qc.submitParamsForQuest(quest, inputValues);

                if (!mounted) return;

                try {
                  rootNav.pop();
                } catch (_) {}

                try {
                  dialogNav.pop(submitted);
                } catch (_) {}
              } catch (e) {
                try {
                  rootNav.pop();
                } catch (_) {}

                // If the state was disposed while awaiting, stop here
                if (!mounted) return;

                // Show error to user
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctxErr) => PopupForm(
                    icon: const Icon(Icons.error_outline),
                    title: 'Error',
                    description: e.toString(),
                    actions: [PopupActionButton(label: 'Aceptar', onPressed: () => Navigator.of(ctxErr).pop())],
                  ),
                );
              }
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

                    // Accept param type in either 'paramtype' or 'paramType' to be tolerant
                    final rawParamType = (detail['paramtype'] ?? detail['paramType'])?.toString().toLowerCase();
                    final isNumber = rawParamType == 'number';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: TextFormField(
                        controller: controllers[i],
                        decoration: InputDecoration(labelText: label),
                        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
                        inputFormatters: isNumber ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[-0-9\.]'))] : null,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final value = v.trim();
                          if (isNumber) {
                            // Accept both integer and decimal values; reject if not parseable
                            final parsed = num.tryParse(value);
                            if (parsed == null) return 'Debe ser un número válido';
                          }
                          // For 'text' or unknown types, only required check is applied
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

    return result;
  }
}
