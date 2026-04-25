import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inventory_item.dart';

class InventoryImageWidget extends StatelessWidget {
  final InventoryItem item;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const InventoryImageWidget({
    super.key,
    required this.item,
    this.width = 70,
    this.height = 70,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  static ImageProvider getImageProvider(InventoryItem item) {
    // 1. Check localImage field
    if (item.localImage != null && item.localImage!.isNotEmpty) {
      final file = File(item.localImage!);
      if (file.existsSync()) return FileImage(file);
    }
    
    // 2. Check image field (might be a local path now)
    if (item.image != null && item.image!.isNotEmpty) {
      if (item.image!.startsWith('/') || item.image!.contains(':\\')) {
        final file = File(item.image!);
        if (file.existsSync()) return FileImage(file);
      }
      return CachedNetworkImageProvider(item.image!);
    }
    
    return const CachedNetworkImageProvider("https://via.placeholder.com/300");
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = item.localImage != null && item.localImage!.isNotEmpty;
    final hasRemote = item.image != null && item.image!.isNotEmpty;

    if (!hasLocal && !hasRemote) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: _buildImage(hasLocal, hasRemote),
      ),
    );
  }

  Widget _buildImage(bool hasLocal, bool hasRemote) {
    if (hasLocal) {
      final file = File(item.localImage!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            if (hasRemote) return _buildRemoteImage();
            return _buildPlaceholder();
          },
        );
      }
    }

    if (hasRemote) {
      return _buildRemoteImage();
    }

    return _buildPlaceholder();
  }

  Widget _buildRemoteImage() {
    return CachedNetworkImage(
      imageUrl: item.image!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.inventory_2, color: Colors.grey[400], size: width * 0.4),
    );
  }
}
