import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'dart:io';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final Function(String, String) onUpload;

  const MediaGrid({
    super.key,
    required this.items,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return MediaGridItem(
          item: item,
          onTap: (item) {
            // Handle tap
          },
          onSelect: (item) {
            // Handle selection using copyWith
            final updatedItem = item.copyWith(isSelected: !item.isSelected);
            final itemIndex = items.indexOf(item);
            if (itemIndex != -1) {
              items[itemIndex] = updatedItem;
            }
          },
        );
      },
    );
  }
}

class MediaGridItem extends StatelessWidget {
  final MediaItem item;
  final Function(MediaItem) onTap;
  final Function(MediaItem) onSelect;

  const MediaGridItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(item),
      child: GridTile(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: item.isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.type == 'image' || (item.type == 'video' && item.thumbnailPath != null))
                Image.file(
                  File(item.thumbnailPath ?? item.filePath),
                  fit: BoxFit.cover,
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 50,
                      color: item.isSelected ? Colors.blue : Colors.black54,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.isSelected ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              if (item.isUploading)
                Container(
                  color: Colors.black45,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: item.uploadProgress,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}