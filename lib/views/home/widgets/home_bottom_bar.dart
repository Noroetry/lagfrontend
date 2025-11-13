import 'package:flutter/material.dart';

/// Widget that displays the bottom navigation bar with game functionality icons.
class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            color: Colors.white,
            tooltip: 'Mensajes',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.groups),
            color: Colors.white,
            tooltip: 'Social',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.backpack),
            color: Colors.white,
            tooltip: 'Inventario',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            color: Colors.white,
            tooltip: 'Histórico de Quests',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.store),
            color: Colors.white,
            tooltip: 'Tienda',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not implemented yet')),
              );
            },
          ),
        ],
      ),
    );
  }
}
