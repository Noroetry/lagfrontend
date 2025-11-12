import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
// app_theme not required here; styles come from global theme
import 'package:lagfrontend/controllers/quest_controller.dart';

/// Shows a detailed quest popup when tapping a quest on the Home screen.
/// - [quest] is the raw quest object (Map-like) returned by the backend.
/// Behavior:
/// - Title: 'MISIÓN', icon book.
/// - Shows header title, then:
///   - If state == 'C' -> green 'Completada'
///   - If state == 'L' -> header.description
/// - Shows each detail description with {value} replaced by the matching
///   value from quest user's details (idQuestUserDetail -> value mapping).
/// - Each detail shows a check at right. If state == 'C' checks are disabled.
///   If state == 'L' checks are interactive and toggle via
///   `QuestController.checkQuestDetail` which calls `/check-detail-quest`.
Future<void> showQuestDetailPopup(BuildContext context, dynamic quest) async {
  if (!Navigator.of(context).mounted) return;

  final header = (quest is Map && quest['header'] is Map) ? Map<String, dynamic>.from(quest['header']) : <String, dynamic>{};
  final title = header['title']?.toString() ?? 'Misión';
  final description = header['description']?.toString() ?? '';
  final state = quest is Map && quest['state'] != null ? quest['state'].toString() : '';

  // Build a robust map from quest_users_detail entries to their stored value.
  // We map both by the per-user detail id (e.g. idQuestUserDetail) and by the
  // referenced detail id (e.g. idQuestDetail) so we can match against the
  // static `details` definitions in the quest payload regardless of which
  // id the backend provides in each section.
  final Map<dynamic, dynamic> userDetailValues = {};
  try {
    final detailsList = (quest is Map && quest['quest_users_detail'] is List) ? List.from(quest['quest_users_detail']) : <dynamic>[];
    for (final u in detailsList) {
      if (u is Map) {
        final perUserId = u['idQuestUserDetail'] ?? u['id'] ?? u['idQuestUserDetalle'];
        final refDetailId = u['idQuestDetail'] ?? u['id_detail'] ?? u['idDetail'] ?? u['idQuestDetalle'];
        // value may be directly stored or inside a nested object
        dynamic value = u['value'] ?? u['valor'] ?? u['valueParam'];
        if (value is Map && value.containsKey('value')) value = value['value'];

        if (perUserId != null) userDetailValues[perUserId] = value;
        if (refDetailId != null) userDetailValues['ref:${refDetailId.toString()}'] = value;
      }
    }
  } catch (_) {}

  // Details to show: prefer quest['details'] array
  final showDetails = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

  // Capture navigator state before async ops
  final rootNav = Navigator.of(context, rootNavigator: true);

  // Track whether the dialog is still open to avoid accidental double-pop
  bool dialogOpen = true;

  await showDialog<void>(
    context: context,
    // For detail popup: tapping outside should behave like pressing "Aceptar"
    barrierDismissible: true,
    builder: (ctx) {
      // Prepare mutable state captured by the StatefulBuilder below.
      final Map<dynamic, bool> checkedMap = {};
      final Map<dynamic, String> renderedMap = {};
      final List<dynamic> detailKeys = [];
      bool locked = false; // when true, all checkboxes are disabled

      // helper to lookup a value in userDetailValues using several keys
      dynamic lookupVal(dynamic key) {
        if (key == null) return null;
        if (userDetailValues.containsKey(key)) return userDetailValues[key];
        final sk = key.toString();
        if (userDetailValues.containsKey('ref:$sk')) return userDetailValues['ref:$sk'];
        final ik = int.tryParse(sk);
        if (ik != null && userDetailValues.containsKey(ik)) return userDetailValues[ik];
        if (userDetailValues.containsKey(sk)) return userDetailValues[sk];
        return null;
      }

      // Initialize maps from showDetails
      for (var i = 0; i < showDetails.length; i++) {
        final d = showDetails[i];
        String rawDesc = '';
        dynamic idDetail;
        try {
          if (d is Map) {
            rawDesc = (d['description'] ?? d['descripcion'] ?? '').toString();
            idDetail = d['idQuestUserDetail'] ?? d['id'] ?? d['idDetail'] ?? d['idQuestDetail'];
          }
        } catch (_) {}

        // Find value/checked as before (prefer explicit fields on detail)
        dynamic foundVal;
        dynamic explicitChecked;
        try {
          if (d is Map) {
            if (d.containsKey('value')) {
              foundVal = d['value'];
              if (foundVal is Map && foundVal.containsKey('value')) foundVal = foundVal['value'];
            } else if (d.containsKey('valor')) {
              foundVal = d['valor'];
            }
            if (d.containsKey('checked')) explicitChecked = d['checked'];
          }
          foundVal ??= lookupVal(idDetail);
          if (foundVal == null && d is Map) {
            final altId = d['idQuestDetail'] ?? d['id_detail'] ?? d['idDetail'] ?? d['id'] ?? d['idQuestDetalle'];
            foundVal = lookupVal(altId);
          }
        } catch (_) {
          foundVal = null;
          explicitChecked = null;
        }

        String rendered = rawDesc;
        try {
          rendered = rawDesc.replaceAll('{value}', foundVal?.toString() ?? '');
        } catch (_) {}

        bool checked = false;
        try {
          if (explicitChecked != null) {
            final chk = explicitChecked;
            if (chk is bool) {
              checked = chk;
            } else if (chk is num) {
              checked = chk != 0;
            } else if (chk is String) {
              final s = chk.trim().toLowerCase();
              checked = s == 'true' || s == '1' || s == 'yes' || s == 'y';
            }
          } else {
            final val = foundVal;
            if (val is bool) {
              checked = val;
            } else if (val is num) {
              checked = val != 0;
            } else if (val is String) {
              final s = val.trim().toLowerCase();
              checked = s == 'true' || s == '1' || s == 'yes' || s == 'y';
            }
          }
        } catch (_) {}

        final key = idDetail ?? i;
        detailKeys.add(key);
        checkedMap[key] = checked;
        renderedMap[key] = rendered;
      }

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          // When user dismisses by tapping outside or back, treat as Accept
          if (didPop) {
            dialogOpen = false;
          }
        },
        child: PopupForm(
          icon: const Icon(Icons.menu_book),
          title: 'MISIÓN',
          actions: [
            PopupActionButton(
              label: 'Aceptar',
              onPressed: () {
                dialogOpen = false;
                Navigator.of(ctx).pop();
              },
            )
          ],
          child: StatefulBuilder(builder: (ctxSb, setStateSb) {
          return Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (state == 'C')
                    Text('Completada', style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold))
                  else if (state == 'L' && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  const SizedBox(height: 12),

                  // List of details using the prepared maps
                  ...detailKeys.map((key) {
                    final rendered = renderedMap[key] ?? '';
                    final checked = checkedMap[key] ?? false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Expanded(child: Text(rendered, style: Theme.of(context).textTheme.bodyMedium)),
                          const SizedBox(width: 8),
                          if (state == 'C')
                            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, color: Colors.green)
                          else
                            // Disable checkboxes while locked; otherwise allow toggling
                            AbsorbPointer(
                              absorbing: locked,
                              child: Builder(builder: (ctxItem) {
                                return Checkbox(
                                  value: checkedMap[key],
                                  onChanged: (v) async {
                                    if (v == null) return;

                                    // Determine whether this toggle will complete the quest
                                    final currentlyCheckedCount = checkedMap.values.where((e) => e).length;
                                    final willBeChecked = v == true;
                                    final willBeAllChecked = willBeChecked && (currentlyCheckedCount + 1 >= detailKeys.length);

                                    // If this is the final check, lock UI immediately to prevent race conditions
                                    if (willBeAllChecked) {
                                      setStateSb(() {
                                        locked = true;
                                        checkedMap[key] = v;
                                      });
                                    } else {
                                      // optimistically update this checkbox only
                                      setStateSb(() => checkedMap[key] = v);
                                    }

                                    try {
                                      final qc = Provider.of<QuestController>(rootNav.context, listen: false);
                                      final updated = await qc.checkQuestDetail(idQuestUserDetail: key, checked: v);

                                      // Merge server response: if quest completed, close dialog
                                      try {
                                        if (updated.isNotEmpty) {
                                          dynamic updatedQuest;
                                          for (final u in updated) {
                                            try {
                                              final uId = u is Map && u['idQuestUser'] != null ? u['idQuestUser'] : (u is Map && u['id'] != null ? u['id'] : null);
                                              final qId = quest is Map && (quest['idQuestUser'] ?? quest['id']) != null ? (quest['idQuestUser'] ?? quest['id']) : null;
                                              if (uId != null && qId != null && uId == qId) {
                                                updatedQuest = u;
                                                break;
                                              }
                                            } catch (_) {}
                                          }

                                          if (updatedQuest != null) {
                                            final newState = updatedQuest is Map && updatedQuest['state'] != null ? updatedQuest['state'].toString() : null;
                                            if (newState == 'C') {
                                              try {
                                                if (dialogOpen) {
                                                  rootNav.pop();
                                                  return;
                                                }
                                              } catch (_) {}
                                            }
                                          }
                                        }
                                      } catch (_) {}

                                      // If we reached here and UI was locked for final check, unlock now
                                      if (willBeAllChecked) {
                                        try {
                                          setStateSb(() => locked = false);
                                        } catch (_) {}
                                      }
                                    } catch (e) {
                                      // revert optimistic change and unlock
                                      setStateSb(() {
                                        checkedMap[key] = !checkedMap[key]!;
                                        locked = false;
                                      });
                                      try {
                                        if (!rootNav.mounted) return;
                                        await showDialog<void>(
                                          context: rootNav.context,
                                          barrierDismissible: false,
                                          builder: (errCtx) => PopupForm(
                                            icon: const Icon(Icons.error_outline),
                                            title: 'Error',
                                            description: e.toString(),
                                            actions: [PopupActionButton(label: 'Aceptar', onPressed: () => Navigator.of(errCtx).pop())],
                                          ),
                                        );
                                      } catch (_) {}
                                    }
                                  },
                                );
                              }),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        }),
        ),
      );
    },
  );

  // ✅ NO recargar quests desde el servidor aquí - el controller ya actualiza
  // su estado localmente cuando se marcan detalles. Recargar causaría que
  // los popups se muestren múltiples veces si el backend aún devuelve quests
  // en estado 'N' o 'P'.
  // La sincronización local en checkQuestDetail() es suficiente.
}
