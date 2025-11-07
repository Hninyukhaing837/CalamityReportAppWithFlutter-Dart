import 'package:flutter/material.dart';

class MediaGridItem extends StatelessWidget {
  final MediaItem item;

  const MediaGridItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ...existing stack children...
        if (item.isFavorite)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}

class MediaItem {
  final bool isFavorite;

  MediaItem({required this.isFavorite});
}

/* File type filtering (All, Images, Videos, Favorites)
 * - Multiple sort options (Date, Name, Size)
 * - Ascending/Descending sort order
 * - Favorites system
 * - Share functionality (needs implementation with share_plus)
 * - Filter and sort dialogs
 * - Visual indicators for favorites
 * - Enhanced model with date and size information
 */