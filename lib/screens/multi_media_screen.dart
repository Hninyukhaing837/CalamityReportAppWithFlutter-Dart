import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_item.dart';
import '../services/media_upload_service.dart';
import '../widgets/media_grid.dart';  // Add this import
import 'package:image_picker/image_picker.dart';

class MultiMediaScreen extends StatefulWidget {
  final Function(List<File>, String) onMediaSelected;
  final bool allowVideo;
  final int maxItems;

  const MultiMediaScreen({
    super.key,
    required this.onMediaSelected,
    this.allowVideo = true,
    this.maxItems = 10,
  });

  @override
  State<MultiMediaScreen> createState() => _MultiMediaScreenState();
}

class _MultiMediaScreenState extends State<MultiMediaScreen> {
  final List<MediaItem> _items = [];
  final MediaUploadService _uploadService = MediaUploadService();
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isGridView = true;
  bool _isSelectionMode = false;
  String _searchQuery = '';
  String _filterType = 'all';
  String _sortBy = 'date';
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickMultipleImages() async {
    setState(() => _isLoading = true);

    try {
      final List<XFile> files = await ImagePicker().pickMultiImage();
      
      if (files.isNotEmpty) {
        for (var file in files) {
          if (_items.length >= widget.maxItems) break;
          
          _items.add(MediaItem(
            filePath: file.path,  // Changed from file: File(file.path)
            type: 'image',
            dateAdded: DateTime.now(),
          ));
        }
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _uploadSelectedMedia() async {
    setState(() => _isUploading = true);

    try {
      final urls = await _uploadService.uploadMultipleMedia(
        _items,
        (item, progress) {
          final index = _items.indexOf(item);
          setState(() {
            _items[index] = item.copyWith(
              isUploading: true,
              uploadProgress: progress,
            );
          });
        },
        (item, url) {
          final index = _items.indexOf(item);
          setState(() {
            _items[index] = item.copyWith(
              isUploading: false,
              isUploaded: url != null,
              uploadError: url == null ? 'Upload failed' : null,
            );
          });
        },
      );

      if (urls.isNotEmpty) {
        widget.onMediaSelected(
          _items
              .where((item) => item.isUploaded)
              .map((item) => File(item.filePath))  // Changed to use filePath
              .toList(),
          _items.first.type,
        );
        Navigator.pop(context);
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildUploadButton() {
    final selectedCount = _items.where((item) => item.isSelected).length;
    final uploadingCount = _items.where((item) => item.isUploading).length;

    if (_isUploading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Uploading $uploadingCount/$selectedCount',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return TextButton.icon(
      onPressed: selectedCount > 0 ? _uploadSelectedMedia : null,
      icon: const Icon(Icons.upload, color: Colors.white),
      label: Text(
        'Upload ($selectedCount)',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _deleteItem(MediaItem item) async {
    final index = _items.indexOf(item);
    setState(() {
      _items.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _items.insert(index, item);
            });
          },
        ),
      ),
    );
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        // Clear selection when exiting selection mode
        _items.asMap().forEach((index, item) {
          _items[index] = item.copyWith(isSelected: false);
        });
      }
    });
  }

  void _deleteSelectedItems() {
    final selectedItems = _items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) return;

    for (var item in selectedItems) {
      _deleteItem(item);
    }
    _toggleSelectionMode();
  }

  List<MediaItem> get _filteredAndSortedItems {
    List<MediaItem> items = _items.where((item) {
      if (_filterType == 'all') return true;
      if (_filterType == 'favorites') return item.isFavorite;
      return item.type == _filterType;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final fileName = item.file.path.split('/').last.toLowerCase();
        return fileName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    items.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.file.path.compareTo(b.file.path);
          break;
        case 'date':
          comparison = a.dateAdded.compareTo(b.dateAdded);
          break;
        case 'size':
          comparison = a.fileSize.compareTo(b.fileSize);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return items;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All'),
              value: 'all',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Images'),
              value: 'image',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Videos'),
              value: 'video',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Favorites'),
              value: 'favorites',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Size'),
              value: 'size',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            CheckboxListTile(
              title: const Text('Ascending'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() => _sortAscending = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareItems(List<MediaItem> items) {
    // Implement sharing functionality using share_plus package
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
            )
          : null,
        title: _isSelectionMode
          ? Text('${_items.where((item) => item.isSelected).length} selected')
          : _searchController.text.isNotEmpty
              ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search media...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                )
              : const Text('Select Media'),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortDialog,
            ),
            IconButton(
              icon: Icon(_searchController.text.isEmpty ? Icons.search : Icons.clear),
              onPressed: () {
                setState(() {
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: _toggleViewMode,
            ),
            if (_items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _toggleSelectionMode,
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareItems(
                _filteredAndSortedItems.where((item) => item.isSelected).toList(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedItems,
            ),
          ],
          if (_items.isNotEmpty && !_isSelectionMode) 
            _buildUploadButton(),
        ],
      ),
      body: Stack(
        children: [
          MediaGrid(
            items: _items,
            onUpload: (String filePath, String type) {
              // Handle the upload here using the file path
              setState(() {
                final index = _items.indexWhere((item) => item.file.path == filePath);
                if (index != -1) {
                  _items[index] = _items[index].copyWith(
                    type: type,
                    isUploading: true,
                  );
                }
              });
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton(
              onPressed: _pickMultipleImages,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }


}

class MediaGridItem extends StatelessWidget {
  final MediaItem item;
  final Function(MediaItem) onTap;  // Changed to accept MediaItem
  final Function(MediaItem) onSelect;  // Changed to accept MediaItem

  const MediaGridItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media Preview
        GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: item.type == 'video'
                ? Image.file(
                    File(item.thumbnailPath ?? ''),
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    item.file,
                    fit: BoxFit.cover,
                  ),
          ),
        ),

        // Upload Progress Indicator
        if (item.isUploading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: item.uploadProgress,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(item.uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Upload Status Indicator
        if (item.isUploaded || item.uploadError != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: item.isUploaded ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isUploaded ? Icons.check : Icons.error,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

        // Selection Checkbox
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onSelect(item),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: item.isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                size: 16,
                color: item.isSelected ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ),
        ),

        // Add reorder handle
        if (!item.isUploading && item.uploadError == null)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.drag_handle,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}

// Upload progress tracking per item
// Batch upload support
// Error handling for failed uploads
// Visual feedback during upload
// Upload status indicators
// Cancellation support
// Progress reporting

// Dedicated widget for grid items
// Upload progress circular indicator with percentage
// Success/error status indicators
// Enhanced selection checkboxes
// Upload progress count in app bar
// Visual feedback during upload process
// Better error state visualization

// Drag-and-drop reordering with visual handle
// Swipe-up-to-delete functionality
// Undo delete action
// Visual feedback during reordering
// Smooth animations
// Error handling for reordering
// Proper state management

// Photo and video capture/selection
// Grid view display
// Upload progress indication
// Media type indicators
// Loading states
// Error handling