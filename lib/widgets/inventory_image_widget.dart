import '../core/design/tokens/app_colors.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InventoryImageWidget extends StatelessWidget {
  final dynamic item; // Supports InventoryItem or InventoryEntity
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

  /// Returns the pixel-density-aware cache dimension for image decoding.
  /// This forces Flutter's image codec to decode at 2x display size (for retina),
  /// saving massive amounts of GPU memory on low-end devices.
  int _cacheSize(double displaySize) => (displaySize * 2).toInt();

  static ImageProvider getImageProvider(dynamic item) {
    final String? localImage = item.localImage;
    final String? image = item.image;

    // 1. Check localImage field
    if (localImage != null && localImage.isNotEmpty) {
      final file = File(localImage);
      if (file.existsSync()) return FileImage(file);
    }
    
    // 2. Check image field (might be a local path now)
    if (image != null && image.isNotEmpty) {
      if (image.startsWith('/') || image.contains(':\\')) {
        final file = File(image);
        if (file.existsSync()) return FileImage(file);
      }
      return CachedNetworkImageProvider(image);
    }
    
    return const CachedNetworkImageProvider("https://via.placeholder.com/300");
  }

  @override
  Widget build(BuildContext context) {
    final String? localImage = item.localImage;
    final String? image = item.image;
    final hasLocal = localImage != null && localImage.isNotEmpty;
    final hasRemote = image != null && image.isNotEmpty;

    if (!hasLocal && !hasRemote) {
      return _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: width,
        height: height,
        child: _buildImage(context, hasLocal, hasRemote),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool hasLocal, bool hasRemote) {
    if (hasLocal) {
      final file = File(item.localImage!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: _cacheSize(width),
          cacheHeight: _cacheSize(height),
          errorBuilder: (context, error, stackTrace) {
            if (hasRemote) return _buildRemoteImage(context);
            return _buildPlaceholder(context);
          },
        );
      }
    }

    if (hasRemote) {
      return _buildRemoteImage(context);
    }

    return _buildPlaceholder(context);
  }

  Widget _buildRemoteImage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: item.image!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: _cacheSize(width),
      memCacheHeight: _cacheSize(height),
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => Container(
        color: AppColors.border(context),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.zero,
      ),
      child: Icon(Icons.inventory_2, color: AppColors.textHint(context), size: width * 0.4),
    );
  }
}



