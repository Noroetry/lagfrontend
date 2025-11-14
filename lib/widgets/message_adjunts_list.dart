import 'package:flutter/material.dart';
import 'package:lagfrontend/models/message_adjunt_model.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Widget that displays a list of message attachments (adjunts).
/// Shows different icons and styles based on the adjunt type.
class MessageAdjuntsList extends StatelessWidget {
  final List<MessageAdjunt> adjunts;

  const MessageAdjuntsList({super.key, required this.adjunts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: adjunts.map((adjunt) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: _AdjuntItem(adjunt: adjunt),
        );
      }).toList(),
    );
  }
}

class _AdjuntItem extends StatelessWidget {
  final MessageAdjunt adjunt;

  const _AdjuntItem({required this.adjunt});

  @override
  Widget build(BuildContext context) {
    final isPositive = adjunt.quantity >= 0;
    final icon = _getIconForType(adjunt.type);
    final color = _getColorForType(adjunt.type, isPositive);
    final quantityText = adjunt.quantity >= 0
        ? '+${adjunt.quantity}'
        : adjunt.quantity.toString();

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adjunt.objectName,
                  style: AppTheme.popupRewardsStyle(context).copyWith(
                    color: color,
                  ),
                ),
                if (adjunt.type == 'quest' &&
                    adjunt.questAssignedTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    adjunt.questAssignedTitle!,
                    style: AppTheme.popupContentDescriptionStyle(context).copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quantityText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            adjunt.shortName,
            style: AppTheme.popupRewardsStyle(context).copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'experience':
      case 'exp':
        return Icons.star;
      case 'coin':
      case 'coins':
      case 'moneda':
        return Icons.monetization_on;
      case 'quest':
      case 'mission':
      case 'misión':
        return Icons.assignment;
      case 'item':
        return Icons.inventory_2;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _getColorForType(String type, bool isPositive) {
    if (!isPositive) {
      return Colors.red;
    }

    switch (type.toLowerCase()) {
      case 'experience':
      case 'exp':
        return Colors.purple;
      case 'coin':
      case 'coins':
      case 'moneda':
        return Colors.amber;
      case 'quest':
      case 'mission':
      case 'misión':
        return Colors.blue;
      case 'item':
        return Colors.green;
      default:
        return Colors.white;
    }
  }
}
