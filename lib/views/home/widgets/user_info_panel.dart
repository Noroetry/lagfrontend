import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/user_controller.dart';
import 'package:lagfrontend/utils/user_helpers.dart';

/// Widget that displays the user's information panel including level, title, job, rank, and XP bar.
class UserInfoPanel extends StatelessWidget {
  const UserInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Builder(
        builder: (context) {
          final user = userController.currentUser;
          final additional = user?.additionalData ?? {};

          // Try to read some commonly used keys from additionalData.
          // The backend will provide new fields:
          // - level_number
          // - totalExp
          // - minExpRequired
          // - nextRequiredLevel
          final title =
              additional['title'] ??
              additional['titulo'] ??
              additional['rankTitle'];
          final job =
              additional['job'] ??
              additional['profesion'] ??
              additional['role'];
          final range = additional['range'] ?? additional['rango'];

          // Level: prefer explicit backend field, fall back to older keys
          final levelNumber =
              additional['level_number'] ??
              additional['level'] ??
              additional['nivel'] ??
              additional['xpLevel'];

          // XP fields
          final num? totalExp = parseNum(
            additional['totalExp'] ?? additional['exp'] ?? additional['xp'],
          );
          final num? minExp = parseNum(
            additional['minExpRequired'] ?? additional['minExp'],
          );
          final num? nextReq = parseNum(
            additional['nextRequiredLevel'] ??
                additional['expToNext'] ??
                additional['xpToNext'] ??
                additional['next'],
          );

          // Compute ratio using helper
          final expRatio = calculateXpRatio(
            totalExp: totalExp,
            minExp: minExp,
            nextReq: nextReq,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nivel: ${levelNumber ?? '—'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Rango: ${range ?? '—'}',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Título: ${title ?? '—'}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Trabajo: ${job ?? '—'}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${user?.coins ?? 0}cs',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // EXP bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: expRatio != null
                        ? LinearProgressIndicator(
                            value: expRatio,
                            minHeight: 10,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          )
                        : LinearProgressIndicator(
                            value: 0.0,
                            minHeight: 10,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 6),
                  // Numeric XP label when we have values
                  Builder(
                    builder: (context) {
                      try {
                        if (totalExp != null && nextReq != null) {
                          final percent = expRatio != null
                              ? (expRatio * 100).toStringAsFixed(2)
                              : '0.00';
                          return Center(
                            child: Text(
                              '${totalExp.toInt()} / ${nextReq.toInt()} EXP ($percent%)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                      } catch (_) {}
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
