import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:biztonic_pos/services/sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService(),
      builder: (context, _) {
        final service = SyncService();
        final isOnline = service.isOnline;
        final pending = service.pendingUploadCount;
        final isSyncing = service.syncStatus == "Syncing...";
        
        Color statusColor = AppColors.adaptiveSuccess(context);
        IconData statusIcon = Icons.cloud_done;
        String tooltip = "Synced";

        if (!isOnline) {
          statusColor = AppColors.textSecondary(context);
          statusIcon = Icons.cloud_off;
          tooltip = "Offline";
          if (pending > 0) {
             tooltip = "Offline ($pending pending)";
             statusColor = AppColors.adaptiveWarning(context);
          }
        } else if (isSyncing || pending > 0) {
          statusColor = AppColors.adaptivePrimary(context);
          statusIcon = Icons.sync;
          tooltip = "Syncing ($pending pending)...";
        }

        return Tooltip(
          message: tooltip,
          child: Container(
             height: 40,
             padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
             margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
             alignment: Alignment.center,
             decoration: BoxDecoration(
               color: statusColor.withValues(alpha: 0.1),
               borderRadius: BorderRadius.zero,
               border: Border.all(color: statusColor.withValues(alpha: 0.3))
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 if (isSyncing)
                   SizedBox(
                     width: 12, height: 12,
                     child: CircularProgressIndicator(strokeWidth: 2, color: statusColor),
                   )
                 else
                   Icon(statusIcon, color: statusColor, size: 16),
                 
                 if (pending > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      "$pending", 
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                    )
                 ]
               ],
             ),
          ),
        );
      },
    );
  }
}



