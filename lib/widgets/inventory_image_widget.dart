import '../core/design/tokens/app_colors.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

    // 1. Check localImage field (Web blob/base64 vs Mobile path)
    if (localImage != null && localImage.isNotEmpty) {
      if (localImage.startsWith('data:image')) {
        try {
          final uri = Uri.parse(localImage);
          final base64Data = uri.data?.contentAsBytes();
          if (base64Data != null) return MemoryImage(base64Data);
        } catch (e) {
          debugPrint("Error parsing base64 in getImageProvider: $e");
        }
      }
      if (kIsWeb) {
        return NetworkImage(localImage);
      }
      final file = File(localImage);
      if (file.existsSync()) return FileImage(file);
    }
    
    // 2. Check image field (might be a local path or URL)
    if (image != null && image.isNotEmpty) {
      if (image.startsWith('/') || image.contains(':\\') || image.startsWith('file://')) {
        if (kIsWeb) return NetworkImage(image);
        final file = File(image);
        if (file.existsSync()) return FileImage(file);
      }
      if (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('blob:')) {
        return CachedNetworkImageProvider(image);
      }
      if (kIsWeb) {
        return NetworkImage(image);
      }
      final file = File(image);
      if (file.existsSync()) return FileImage(file);
    }
    
    return const CachedNetworkImageProvider("https://via.placeholder.com/300");
  }

  @override
  Widget build(BuildContext context) {
    final String? localImage = item.localImage;
    final String? image = item.image;
    final hasLocal = localImage != null && localImage.isNotEmpty;
    final hasRemote = image != null && image.isNotEmpty && (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('blob:'));

    if (!hasLocal && !hasRemote) {
      return _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: _buildImage(context, hasLocal, hasRemote),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool hasLocal, bool hasRemote) {
    final localImage = item.localImage;
    if (hasLocal && localImage != null) {
      if (localImage.startsWith('data:image')) {
        try {
          final uri = Uri.parse(localImage);
          final base64Data = uri.data?.contentAsBytes();
          if (base64Data != null) {
            return Image.memory(
              base64Data,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                if (hasRemote) return _buildRemoteImage(context);
                return _buildPlaceholder(context);
              },
            );
          }
        } catch (e) {
          debugPrint("Error rendering base64 image: $e");
        }
      }

      if (kIsWeb) {
        return Image.network(
          localImage,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            if (hasRemote) return _buildRemoteImage(context);
            return _buildPlaceholder(context);
          },
        );
      } else {
        final file = File(localImage);
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
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.inventory_2, color: AppColors.textHint(context), size: width * 0.4),
    );
  }
}



