import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/quest_controller.dart';
import 'package:lagfrontend/widgets/quest_detail_popup.dart';
import 'package:lagfrontend/views/home/widgets/quest_countdown.dart';

/// Widget that displays the list of active quests (state 'L' or 'C').
class ActiveQuestsPanel extends StatelessWidget {
  const ActiveQuestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Consumer<QuestController>(builder: (context, qc, child) {
        if (qc.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final active = qc.quests.where((q) {
          try {
            final s = q is Map && q['state'] != null ? q['state'].toString() : '';
            return s == 'L' || s == 'C';
          } catch (_) {
            return false;
          }
        }).toList();

        if (active.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No hay misiones activas',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: active.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white24),
          itemBuilder: (ctx, idx) {
            final q = active[idx];
            String questTitle = 'Misión';
            String questState = '';
            try {
              if (q is Map) {
                final header = q['header'];
                if (header is Map && header['title'] != null) {
                  questTitle = header['title'].toString();
                }
                questTitle = questTitle.isNotEmpty
                    ? questTitle
                    : (q['title']?.toString() ?? 'Misión');
                questState = q['state']?.toString() ?? '';
              }
            } catch (_) {}

            final checked = questState == 'C';

            return InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: () async {
                // Show detailed quest popup
                await showQuestDetailPopup(context, q);
              },
              child: SizedBox(
                height: 36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        questTitle,
                        style: TextStyle(
                          color: checked ? Colors.green[400] : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // If completed show a reward icon, otherwise show countdown
                    if (checked)
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined),
                        color: Colors.amber,
                        tooltip: 'Recompensas',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No implementado aún'),
                            ),
                          );
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                // Try to find duration in multiple places
                                int? durationMinutes;
                                if (q is Map) {
                                  // Check direct duration field
                                  if (q['duration'] != null) {
                                    durationMinutes = q['duration'] is int
                                        ? q['duration'] as int
                                        : int.tryParse(q['duration'].toString());
                                  }
                                  // Check in header
                                  else if (q['header'] is Map && q['header']['duration'] != null) {
                                    durationMinutes = q['header']['duration'] is int
                                        ? q['header']['duration'] as int
                                        : int.tryParse(q['header']['duration'].toString());
                                  }
                                  // Check in details
                                  else if (q['details'] is Map && q['details']['duration'] != null) {
                                    durationMinutes = q['details']['duration'] is int
                                        ? q['details']['duration'] as int
                                        : int.tryParse(q['details']['duration'].toString());
                                  }
                                }
                                
                                return QuestCountdown(
                                  dateExpirationRaw:
                                      q is Map ? q['dateExpiration'] : null,
                                  durationMinutes: durationMinutes,
                                  dateReadRaw: q is Map ? q['dateRead'] : null,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
