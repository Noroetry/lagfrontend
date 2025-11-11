import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Shows the form-style quest popup (state 'P').
/// Returns the list returned by the backend or null if cancelled.
Future<List<dynamic>?> showQuestFormPopup(BuildContext context, dynamic id, String questTitle, dynamic quest) async {
  if (!Navigator.of(context).mounted) return null;

  final details = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

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
      icon: const Icon(Icons.edit),
      title: 'REQUISITOS MISIÓN',
      actions: [
        PopupActionButton(
          label: 'Enviar',
          onPressed: () async {
            final valid = formKey.currentState?.validate() ?? true;
            if (!valid) return;

            final inputValues = controllers.map((c) => c.text).toList();

            final qc = Provider.of<QuestController>(context, listen: false);
            // Capture NavigatorStates before any awaits to avoid using
            // the BuildContext across async gaps.
            final parentNav = Navigator.of(context);
            final rootNav = Navigator.of(context, rootNavigator: true);
            final dialogNav = Navigator.of(ctx);

            try {
              showDialog<void>(
                context: parentNav.context,
                barrierDismissible: false,
                builder: (ctxLoading) => const Center(child: CircularProgressIndicator()),
              );

              final submitted = await qc.submitParamsForQuest(quest, inputValues);

              // Check the captured navigator's mounted state instead of
              // using the original BuildContext after an await.
              if (!parentNav.mounted) return;

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

              // If the parent navigator was unmounted while awaiting, stop.
              if (!parentNav.mounted) return;

              await showDialog<void>(
                context: parentNav.context,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Builder(builder: (ctx2) {
                Map<String, dynamic> header = {};
                String title = questTitle;
                try {
                  if (quest is Map) {
                    final h = quest['header'];
                    if (h is Map<String, dynamic>) header = h;
                    title = header['title']?.toString() ?? title;
                  }
                } catch (_) {}

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

                final missionLine = periodLabel.isNotEmpty ? 'Requisitos de nueva misión $periodLabel:' : 'Requisitos de nueva misión:';

                // Constrain height so large forms become scrollable and
                // allow the keyboard inset to be respected.
                return LayoutBuilder(builder: (ctxLayout, constraints) {
                  final maxHeight = MediaQuery.of(ctxLayout).size.height * 0.8;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(ctxLayout).viewInsets.bottom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$missionLine ',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                TextSpan(
                                  text: '[$title]',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (controllers.isEmpty) const Text('No se requieren parámetros iniciales.'),
                                ...List<Widget>.generate(controllers.length, (i) {
                            final detail = paramDetails[i];
                            final labelAbove = (detail['descriptionParam'] ?? detail['description'])?.toString() ?? 'Valor inicial';

                            final rawParamType = (detail['paramtype'] ?? detail['paramType'])?.toString().toLowerCase();
                            final isNumber = rawParamType == 'number';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(labelAbove, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.left),
                                  const SizedBox(height: 2),
                                  TextFormField(
                                    controller: controllers[i],
                                    decoration: const InputDecoration(
                                      labelText: '',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
                                    ),
                                    keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
                                    inputFormatters: isNumber ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[-0-9\.]'))] : null,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Requerido';
                                      final value = v.trim();
                                      if (isNumber) {
                                        final parsed = num.tryParse(value);
                                        if (parsed == null) return 'Debe ser un número válido';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              }),
            ],
          ),
        ),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final c in controllers) {
      try {
        c.dispose();
      } catch (_) {}
    }
  });

  return result;
}
