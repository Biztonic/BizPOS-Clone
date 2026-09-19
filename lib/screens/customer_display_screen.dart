import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class CustomerDisplayScreen extends StatelessWidget {
  const CustomerDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final storeId = provider.activeStoreId;

    if (storeId == null) {
      return Scaffold(
          body: Center(
              child: Text(AppLocalizations.t(
                  context, 'Please select a store first.'))));
    }

    final Stream<List<Map<String, dynamic>>> statusStream =
        provider.watchCustomerDisplayOrders(storeId);

    return Scaffold(
      backgroundColor:
          AppColors.textPrimaryLight, // High contrast for TV/Display
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'Order Status')),
        backgroundColor: AppColors.textPrimaryLight,
        foregroundColor: AppColors.surfaceLight,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: statusStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Often index error initially
            return Center(
                child: Text('Waiting for system... (${snapshot.error})',
                    style: const TextStyle(color: AppColors.surfaceLight)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<Map<String, dynamic>>.from(snapshot.data ?? []);
          // Client-side sort: Oldest first (FIFO)
          docs.sort((a, b) {
            dynamic dateA = a['date'];
            dynamic dateB = b['date'];

            DateTime? dA, dB;

            // Robust Parse A
            if (dateA is DateTime) {
              dA = dateA;
            } else if (dateA != null &&
                dateA.runtimeType.toString().contains('Timestamp')) {
              dA = (dateA as dynamic).toDate();
            } else if (dateA is String) {
              dA = DateTime.tryParse(dateA);
            } else if (dateA is int) {
              dA = DateTime.fromMillisecondsSinceEpoch(dateA);
            }

            // Robust Parse B
            if (dateB is DateTime) {
              dB = dateB;
            } else if (dateB != null &&
                dateB.runtimeType.toString().contains('Timestamp')) {
              dB = (dateB as dynamic).toDate();
            } else if (dateB is String) {
              dB = DateTime.tryParse(dateB);
            } else if (dateB is int) {
              dB = DateTime.fromMillisecondsSinceEpoch(dateB);
            }

            if (dA == null || dB == null) return 0;
            return dA.compareTo(dB);
          });

          final preparing =
              docs.where((d) => d['status'] == 'Preparing').toList();

          final ready = docs.where((d) => d['status'] == 'Ready').toList();

          return LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final content = [
              // Preparing Column
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      color: AppColors.warning,
                      width: double.infinity,
                      child: Text(AppLocalizations.t(context, 'PREPARING'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.surfaceLight,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 3 : 2,
                            childAspectRatio: isMobile ? 1.5 : 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10),
                        itemCount: preparing.length,
                        itemBuilder: (context, index) {
                          final doc = preparing[index];
                          return _buildTicket(
                              doc['orderId']?.toString() ?? '????', false);
                        },
                      ),
                    )
                  ],
                ),
              ),
              if (!isMobile)
                const VerticalDivider(color: AppColors.surfaceLight, width: 2),
              if (isMobile)
                const Divider(color: AppColors.surfaceLight, height: 2),
              // Ready Column
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      color: AppColors.success,
                      width: double.infinity,
                      child: Text(
                          AppLocalizations.t(context, 'READY FOR PICKUP'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.surfaceLight,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 3 : 2,
                            childAspectRatio: isMobile ? 1.5 : 2.5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10),
                        itemCount: ready.length,
                        itemBuilder: (context, index) {
                          final doc = ready[index];
                          return _buildTicket(
                              doc['orderId']?.toString() ?? '????', true);
                        },
                      ),
                    )
                  ],
                ),
              ),
            ];

            return isMobile
                ? Column(children: content)
                : Row(children: content);
          });
        },
      ),
    );
  }

  Widget _buildTicket(String id, bool isReady) {
    // Truncate ID if too long (e.g. UUID)
    final displayId = id.length > 5 ? id.substring(id.length - 4) : id;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: isReady ? AppColors.success : AppColors.warning,
          borderRadius: BorderRadius.zero,
          border: Border.all(
              color: isReady ? AppColors.success : AppColors.warning,
              width: 2)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text("#$displayId",
            style: TextStyle(
                fontSize: isReady ? 32 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight)),
      ),
    );
  }
}
