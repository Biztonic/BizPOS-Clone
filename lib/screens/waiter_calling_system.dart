import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import '../core/design/layouts/pos_scaffold.dart';

class WaiterCallingSystem extends StatelessWidget {
  const WaiterCallingSystem({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data for calls
    final calls = [
      {'table': 'T-5', 'time': '2m ago', 'type': 'Service'},
      {'table': 'T-12', 'time': '5m ago', 'type': 'Bill'},
      {'table': 'Outside-2', 'time': 'Just now', 'type': 'Water'},
    ];

    return PosScaffold(
      title: "Waiter Calling System",
      mainContent: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: calls.length,
        separatorBuilder: (_,__) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final call = calls[index];
          final isUrgent = call['type'] == 'Bill';
          return Card(
            elevation: 4,
            color: isUrgent ? AppColors.warning : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: isUrgent ? const BorderSide(color: AppColors.warning, width: 2) : BorderSide.none),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isUrgent ? AppColors.warning : AppColors.primaryLight,
                    child: Text(
                      call['table']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Request for ${call['type']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(call['time']!, style: TextStyle(fontSize: 16, color: AppColors.textSecondary(context))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (){},
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md)),
                    child: Text(AppLocalizations.t(context, 'Attend')),
                  )
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){}, 
        label: Text(AppLocalizations.t(context, 'Clear All')),
        icon: const Icon(Icons.clear_all),
      ),
    );
  }
}



