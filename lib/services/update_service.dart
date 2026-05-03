import '../core/design/tokens/app_colors.dart';
// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  
  static Future<void> checkUpdate(BuildContext context) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      String currentBuild = packageInfo.buildNumber;
      
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_version').get();
      
      if (!doc.exists) return;
      
      final data = doc.data()!;
      String latestVersion = data['version'] ?? currentVersion;
      int latestBuild = int.tryParse(data['build']?.toString() ?? '0') ?? 0;
      int myBuild = int.tryParse(currentBuild) ?? 0;
      
      bool updateAvailable = false;
      
      if (latestBuild > myBuild) {
        updateAvailable = true;
      } else if (latestVersion != currentVersion) {
         if (_compareVersions(latestVersion, currentVersion) > 0) {
           updateAvailable = true;
         }
      }
      
      if (updateAvailable) {
         bool force = data['force'] ?? false;
         
         // Throttle non-force updates to once per day
         if (!force) {
            final prefs = await SharedPreferences.getInstance();
            final lastPromptStr = prefs.getString('last_update_prompt_date');
            final todayStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
            
            if (lastPromptStr == todayStr) {
              return; // Already prompted today, skip
            }
            
            // Save today's date
            await prefs.setString('last_update_prompt_date', todayStr);
         }
         
         _showUpdateDialog(
           context, 
           data['url'] ?? '', 
           latestVersion, 
           data['notes'] ?? 'New improvements available.',
           data['force'] ?? false
         );
      }
      
    } catch (e) { /* Error ignored */ }
  }
  
  static int _compareVersions(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      int p1 = i < v1Parts.length ? v1Parts[i] : 0;
      int p2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }
  
  static void _showUpdateDialog(BuildContext context, String url, String version, String notes, bool force) {
    if (force) {
      // For forced updates, just show a dialog saying it's downloading in the background
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Row(
               children: [
                 Icon(Icons.system_update, color: AppColors.primaryLight),
                 SizedBox(width: 10),
                 Text("Critical Update"),
               ]
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Version $version is required."),
                const SizedBox(height: 8),
                const Text("This update is mandatory. It is now downloading in the background. Please wait...", style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            // No actions, it will sit there while the background downloader does its thing and installs.
            // But they can still use the app behind it? Actually, for forced updates it's better to NOT let them use the app
            // However user requested "in app update should work while user is working on application", 
            // so let's just make it a dismissible informational dialog that auto-starts the download.
            actions: [
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text("Got it"),
               )
            ],
          ),
        ),
      );
      _startBackgroundDownload(context, url);
      return;
    }

    // Non-forced update dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
           children: [
             Icon(Icons.system_update, color: AppColors.primaryLight),
             SizedBox(width: 10),
             Text("Update Available"),
           ]
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version $version is available."),
            const SizedBox(height: 8),
            if (notes.isNotEmpty) ...[
               const Text("What's New:", style: TextStyle(fontWeight: FontWeight.bold)),
               Text(notes),
               const SizedBox(height: 12),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context);
               _startBackgroundDownload(context, url);
            },
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  static void _startBackgroundDownload(BuildContext context, String url) {
    _GlobalDownloadManager.startDownload(context, url);
  }
}

class _GlobalDownloadManager {
  static OverlayEntry? _overlayEntry;
  static final CancelToken _cancelToken = CancelToken();
  static bool _isDownloading = false;

  static void startDownload(BuildContext context, String url) async {
    if (_isDownloading) return; // Already downloading
    _isDownloading = true;

    final overlay = Overlay.of(context, rootOverlay: true);
    
    // Create ValueNotifiers to update the overlay without setState
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>("Preparing...");

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.downloading, color: AppColors.primaryLight, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: statusNotifier,
                        builder: (context, status, _) => Text(
                          status,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<double>(
                        valueListenable: progressNotifier,
                        builder: (context, prog, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: prog,
                            minHeight: 4,
                            backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    _cancelToken.cancel();
                    _removeOverlay();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: AppColors.textSecondary(context), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    try {
      final dir = await getExternalStorageDirectory(); 
      if (dir == null) throw Exception("Cannot get storage directory");
      
      final savePath = "${dir.path}/app-release.apk";
      
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      await Dio().download(
        url, 
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
           if (total != -1) {
               final prog = received / total;
               progressNotifier.value = prog;
               final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
               final totalMB = (total / 1024 / 1024).toStringAsFixed(1);
               statusNotifier.value = "Downloading Update... $receivedMB/$totalMB MB";
           }
        }
      );

      // Validate Header
      try {
        final downloadedFile = File(savePath);
        if (await downloadedFile.exists()) {
           final bytes = await downloadedFile.openRead(0, 4).first;
           if (!(bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B)) {
              throw Exception("Downloaded file is not a valid APK.");
           }
        }
      } catch (_) {}

      progressNotifier.value = 1.0;
      statusNotifier.value = "Installing logic started...";
      
      // Delay briefly so user sees 100%
      await Future.delayed(const Duration(seconds: 1));
      
      // Request Install Permission (Android 8+)
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
         status = await Permission.requestInstallPackages.request();
      }

      if (status.isGranted) {
          statusNotifier.value = "Installing Update...";
          final result = await OpenFile.open(savePath);
           if (result.type != ResultType.done) {
             statusNotifier.value = "Install Error: ${result.message}";
             await Future.delayed(const Duration(seconds: 3));
             _removeOverlay();
          } else {
             // Install success (app will restart or close)
             _removeOverlay();
          }
      } else {
          statusNotifier.value = "Install Permission Denied.";
          await Future.delayed(const Duration(seconds: 3));
          _removeOverlay();
          openAppSettings();
      }
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
         // Silently removed
      } else {
         statusNotifier.value = "Download Failed!";
         await Future.delayed(const Duration(seconds: 3));
         _removeOverlay();
      }
    }
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isDownloading = false;
  }
}
