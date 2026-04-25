import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ImageCacheService {
  static final Dio _dio = Dio();

  /// Downloads an image and returns the local path.
  static Future<String?> downloadImage(String url, String fileName) async {
    if (kIsWeb) return null; // Web uses browser cache

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, 'inventory_images'));
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Extract extension or default to .png
      String ext = '.png';
      try {
        final uri = Uri.parse(url);
        final pathExt = p.extension(uri.path);
        if (pathExt.isNotEmpty) ext = pathExt;
      } catch (_) {}

      final localPath = p.join(imagesDir.path, '$fileName$ext');

      // Download
      await _dio.download(url, localPath);
      
      return localPath;
    } catch (e) {
      debugPrint('❌ ImageCacheService: Error downloading image: $e');
      return null;
    }
  }

  static Future<String?> getLocalPath(String fileName) async {
    if (kIsWeb) return null;
    
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(directory.path, 'inventory_images'));
    
    // We check for any extension
    final possibleExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];
    for (var ext in possibleExtensions) {
      final file = File(p.join(imagesDir.path, '$fileName$ext'));
      if (await file.exists()) {
        return file.path;
      }
    }
    return null;
  }
  
  /// Saves a local file (e.g. from image_picker) to the app's persistent storage.
  static Future<String?> saveLocalImage(File file, String itemId) async {
    if (kIsWeb) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, 'inventory_images'));
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Extract original extension
      final ext = p.extension(file.path).isEmpty ? '.png' : p.extension(file.path);
      final localPath = p.join(imagesDir.path, '$itemId$ext');

      // Copy file to permanent storage
      final savedFile = await file.copy(localPath);
      
      debugPrint('✅ ImageCacheService: Saved local image to ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      debugPrint('❌ ImageCacheService: Error saving local image: $e');
      return null;
    }
  }

  static Future<bool> isCached(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return false;
    return await File(localPath).exists();
  }
}
