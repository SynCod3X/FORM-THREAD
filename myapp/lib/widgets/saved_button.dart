import 'package:flutter/material.dart';

import '../models/saved_items.dart';

class SavedButton extends StatelessWidget {
  const SavedButton({super.key, required this.item, this.size = 32});

  final SavedItem item;
  final double size;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<SavedItem>>(
    valueListenable: SavedItems.items,
    builder: (context, savedItems, _) {
      final isSaved = savedItems.contains(item);
      return Material(
        color: const Color(0xFFF8F6F1).withValues(alpha: .94),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () async {
            try {
              await SavedItems.toggle(item);
            } catch (error) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not update saved items: $error'),
                  ),
                );
            }
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              size: size * .5,
              color: isSaved
                  ? const Color(0xFF68715A)
                  : const Color(0xFF25231F),
            ),
          ),
        ),
      );
    },
  );
}
