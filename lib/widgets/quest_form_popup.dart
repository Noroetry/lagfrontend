import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/theme/app_theme.dart';
import 'package:lagfrontend/utils/quest_helpers.dart';

/// Shows the form-style quest popup (state 'P').
/// Returns the list returned by the backend or null if cancelled.
Future<List<dynamic>?> showQuestFormPopup(BuildContext context, dynamic id, String questTitle, dynamic quest) async {
  if (!Navigator.of(context).mounted) return null;

  final questId = id?.toString() ?? 'unknown';
  debugPrint('📝 [showQuestFormPopup] Presenting quest $questId form');

  final details = (quest is Map && quest['details'] is List) ? List.from(quest['details']) : <dynamic>[];

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

            // Capture context-dependent values BEFORE any async operations
            final auth = Provider.of<AuthController>(context, listen: false);
            final qc = Provider.of<QuestController>(context, listen: false);
            final parentNav = Navigator.of(context);
            final rootNav = Navigator.of(context, rootNavigator: true);
            final dialogNav = Navigator.of(ctx);
            
            // Verificar conexión antes de enviar
            final isConnected = await auth.verifyConnection(setErrorMessage: false);
            
            if (!isConnected) {
              // Mostrar mensaje de error de conexión
              if (!parentNav.mounted) return;
              await showDialog<void>(
                context: parentNav.context,
                barrierDismissible: true,
                builder: (errCtx) => PopupForm(
                  icon: const Icon(Icons.cloud_off, color: Colors.orange),
                  title: 'Sin conexión',
                  description: 'No se pueden enviar los parámetros sin conexión al servidor. Por favor, verifica tu conexión e inténtalo de nuevo.',
                  actions: [PopupActionButton(label: 'Entendido', onPressed: () => Navigator.of(errCtx).pop())],
                ),
              );
              return;
            }

            final inputValues = controllers.map((c) => c.text).toList();

            try {
              // Show loading dialog - check mounted state first
              if (parentNav.mounted) {
                unawaited(
                  showDialog<void>(
                    context: parentNav.context,
                    barrierDismissible: false,
                    builder: (ctxLoading) => const Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final submitted = await qc.submitParamsForQuest(quest, inputValues);

              // Check the captured navigator's mounted state instead of
              // using BuildContext across async gaps.
              if (!rootNav.mounted) return;

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

              // Mensaje de error más descriptivo
              String errorMsg = e.toString();
              if (errorMsg.toLowerCase().contains('timeout') || 
                  errorMsg.toLowerCase().contains('conexión') ||
                  errorMsg.toLowerCase().contains('connection')) {
                errorMsg = 'Error de conexión al servidor. El servidor puede estar arrancando (tarda ~30s). Por favor, inténtalo de nuevo.';
              }

              await showDialog<void>(
                context: parentNav.context,
                barrierDismissible: false,
                builder: (ctxErr) => PopupForm(
                  icon: const Icon(Icons.error_outline),
                  title: 'Error',
                  description: errorMsg,
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

                final missionLine = periodLabel.isNotEmpty ? 'Misión $periodLabel:' : 'Misión:';

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
                          Text(
                            missionLine,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '[$title]',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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

  debugPrint('📝 [showQuestFormPopup] Quest $questId form dialog returned (${result?.length ?? 0} items)');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final c in controllers) {
      try {
        c.dispose();
      } catch (_) {}
    }
  });

  return result;
}
