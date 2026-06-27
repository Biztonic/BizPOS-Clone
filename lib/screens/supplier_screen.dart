import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/molecules/app_empty_state.dart';

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'suppliers')),
        actions: [
          AppButton.primary(
            onPressed: () {},
            icon: Icons.add,
            label: AppLocalizations.t(context, 'add'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      mainContent: AppEmptyState(
        type: AppEmptyStateType.employee,
        action: AppButton.secondary(
          onPressed: () {},
          label: 'Learn More about Suppliers',
        ),
      ),
    );
  }
}


