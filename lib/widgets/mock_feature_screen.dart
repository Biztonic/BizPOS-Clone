import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';


import 'package:flutter/material.dart';

// FeatureNode model for hierarchical features
class FeatureNode {
  final String name;
  final List<FeatureNode> children;
  bool enabled;

  FeatureNode(
      {required this.name, this.children = const [], this.enabled = true});
}

// Widget for selecting features in a tree
class FeatureTreeSelector extends StatefulWidget {
  final List<FeatureNode> featureTree;
  final void Function(List<FeatureNode>)? onChanged;

  const FeatureTreeSelector(
      {super.key, required this.featureTree, this.onChanged});

  @override
  State<FeatureTreeSelector> createState() => _FeatureTreeSelectorState();
}

class _FeatureTreeSelectorState extends State<FeatureTreeSelector> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: widget.featureTree
          .map((node) => _buildNode(node, parentEnabled: true))
          .toList(),
    );
  }

  Widget _buildNode(FeatureNode node, {bool parentEnabled = true}) {
    final isLocked = !parentEnabled;
    // If parent is locked, force all children to be disabled in the model as well
    if (isLocked && node.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          node.enabled = false;
          _setChildrenEnabled(node, false);
        });
      });
    }
    if (node.children.isEmpty) {
      return SwitchListTile(
        title: Text(node.name),
        value: parentEnabled ? node.enabled : false,
        onChanged: isLocked
            ? null
            : (val) {
                setState(() => node.enabled = val);
                widget.onChanged?.call(widget.featureTree);
              },
        secondary: isLocked ? Icon(Icons.lock, color: AppColors.textSecondary(context)) : null,
      );
    } else {
      return ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(node.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Switch(
              value: parentEnabled ? node.enabled : false,
              onChanged: isLocked
                  ? null
                  : (val) {
                      setState(() {
                        node.enabled = val;
                        _setChildrenEnabled(node, val);
                      });
                      widget.onChanged?.call(widget.featureTree);
                    },
            ),
            if (isLocked) Icon(Icons.lock, color: AppColors.textSecondary(context), size: 18),
          ],
        ),
        children: node.children
            .map((child) =>
                _buildNode(child, parentEnabled: parentEnabled && node.enabled))
            .toList(),
      );
    }
  }

  void _setChildrenEnabled(FeatureNode node, bool enabled) {
    for (var child in node.children) {
      child.enabled = enabled;
      if (child.children.isNotEmpty) {
        _setChildrenEnabled(child, enabled);
      }
    }
  }
}

// Example feature tree (names as in your app)
final List<FeatureNode> featureTree = [
  FeatureNode(name: 'Customers'),
  FeatureNode(name: 'Reports', children: [
    FeatureNode(name: 'Sales Report'),
    FeatureNode(name: 'Inventory Report'),
    FeatureNode(name: 'Tax Report'),
    FeatureNode(name: 'Profit & Loss'),
    FeatureNode(name: 'Other Reports'),
  ]),
  FeatureNode(name: 'Suppliers'),
  // Removed 'Expenses' from feature configuration UI
  FeatureNode(name: 'Display', children: [
    FeatureNode(name: 'Customer Display'),
    FeatureNode(name: 'KDS Display'),
    FeatureNode(name: 'Ad/Promo Display'),
  ]),
  // Removed 'Tables' from feature configuration UI
  FeatureNode(name: 'Data Center', children: [
    FeatureNode(name: 'Backup'),
    FeatureNode(name: 'Restore'),
    FeatureNode(name: 'Data Import'),
    FeatureNode(name: 'Data Export'),
  ]),
  FeatureNode(name: 'Setting', children: [
    FeatureNode(name: 'Store', children: [
      FeatureNode(name: 'Store Name'),
      FeatureNode(name: 'Store Type'),
      FeatureNode(name: 'Address'),
      FeatureNode(name: 'Phone'),
      FeatureNode(name: 'Counters & Kitchen', children: [
        FeatureNode(name: 'Manage Counters'),
        FeatureNode(name: 'Kitchen Printers'),
        FeatureNode(name: 'Bar Printers'),
      ]),
    ]),
    FeatureNode(name: 'User', children: [
      FeatureNode(name: 'Add User'),
      FeatureNode(name: 'Edit User'),
      FeatureNode(name: 'Roles & Permissions'),
    ]),
    FeatureNode(name: 'Products', children: [
      FeatureNode(name: 'Add Product'),
      FeatureNode(name: 'Edit Product'),
      FeatureNode(name: 'Categories'),
      FeatureNode(name: 'Modifiers'),
    ]),
    FeatureNode(name: 'Tax', children: [
      FeatureNode(name: 'GST'),
      FeatureNode(name: 'Other Taxes'),
    ]),
    FeatureNode(name: 'Payment', children: [
      FeatureNode(name: 'Payment Methods'),
      FeatureNode(name: 'Add Payment'),
    ]),
    FeatureNode(name: 'Appearance', children: [
      FeatureNode(name: 'Themes'),
      FeatureNode(name: 'Logo'),
    ]),
    FeatureNode(name: 'Devices', children: [
      FeatureNode(name: 'Printer'),
      FeatureNode(name: 'Barcode Scanner'),
      FeatureNode(name: 'Cash Drawer'),
    ]),
    FeatureNode(name: 'Plan'),
  ]),
  FeatureNode(name: 'Languages', children: [
    FeatureNode(name: 'English'),
    FeatureNode(name: 'Hindi'),
    FeatureNode(name: 'Other Languages'),
  ]),
];

class MockFeatureScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String layoutType; // 'dashboard', 'kds', 'tables', 'display'

  const MockFeatureScreen({
    super.key,
    required this.title,
    required this.icon,
    this.layoutType = 'dashboard',
  });

  // Helper to get feature enabled state by name, recursively for submenus
  bool _isFeatureEnabledRecursive(String name, [List<FeatureNode>? nodes]) {
    nodes ??= featureTree;
    for (final node in nodes) {
      if (node.name.toLowerCase() == name.toLowerCase()) {
        return node.enabled;
      }
      if (node.children.isNotEmpty) {
        final found = _isFeatureEnabledRecursive(name, node.children);
        return found;
      }
    }
    return true; // Default to enabled if not found
  }

  @override
  Widget build(BuildContext context) {
    // Lock any menu or submenu if its feature is disabled in the tree
    final isCurrentFeatureEnabled = _isFeatureEnabledRecursive(title);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (!isCurrentFeatureEnabled)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: AppColors.textSecondary(context)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '$title is locked by plan',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _buildBody(context)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('Feature Configuration',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 350,
            child: FeatureTreeSelector(featureTree: featureTree),
          ),
        ],
      ),
      floatingActionButton: (layoutType == 'dashboard' ||
                  layoutType == 'tables') &&
              isCurrentFeatureEnabled
          ? FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add))
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (layoutType) {
      case 'kds':
        return _buildKDSLayout();
      case 'tables':
        return _buildTablesLayout();
      case 'display':
        return _buildDisplayLayout();
      case 'dashboard':
      default:
        return _buildDashboardLayout(context);
    }
  }

  // 1. Dashboard Layout (Expenses, Reports)
  Widget _buildDashboardLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatCard(context, "Total", "124", AppColors.primaryLight),
              const SizedBox(width: AppSpacing.md),
              _buildStatCard(context, "Active", "89", AppColors.success),
              const SizedBox(width: AppSpacing.md),
              _buildStatCard(context, "Pending", "35", AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Gradient Chart
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.1)),
            ),
            child: CustomPaint(painter: _MockChartPainter()),
          ),
          const SizedBox(height: AppSpacing.lg),
          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.textSecondary(context),
                  child: Icon(icon, color: AppColors.textSecondary(context)),
                ),
                title: Container(
                  height: 16,
                  width: 150,
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary(context),
                      borderRadius: BorderRadius.zero),
                ),
                subtitle: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary(context),
                      borderRadius: BorderRadius.zero),
                ),
                trailing: Container(
                  height: 24,
                  width: 60,
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary(context),
                      borderRadius: BorderRadius.zero),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 2. KDS Layout (Tickets Grid)
  Widget _buildKDSLayout() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.textSecondary(context)),
            boxShadow: const [BoxShadow(color: AppColors.borderLight, blurRadius: 4)],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                color: index % 2 == 0
                    ? AppColors.success
                    : AppColors.warning,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order #${100 + index}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.timer, size: 16),
                  ],
                ),
              ),
              // Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Container(
                            width: 20,
                            height: 20,
                            color: AppColors.textSecondary(context),
                            child: const Center(
                                child: Text("1x",
                                    style: TextStyle(fontSize: 10)))),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                            height: 10,
                            width: 100,
                            color: AppColors.textSecondary(context)),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight),
                      child: const Text("Done",
                          style: TextStyle(color: AppColors.surfaceLight))),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // 3. Tables Layout (Floor Plan)
  Widget _buildTablesLayout() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.0,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final isOccupied = index % 3 == 0;
        return Container(
          decoration: BoxDecoration(
            color: isOccupied ? AppColors.error : AppColors.success,
            shape: BoxShape.rectangle,
            border: Border.all(
                color: isOccupied ? AppColors.error : AppColors.success,
                width: 2),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.borderLight, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant,
                  size: 32, color: isOccupied ? AppColors.error : AppColors.success),
              const SizedBox(height: AppSpacing.sm),
              Text("T-${index + 1}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOccupied ? AppColors.error : AppColors.success)),
              if (isOccupied)
                Text("24:00",
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
            ],
          ),
        );
      },
    );
  }

  // 4. Customer Display Layout
  Widget _buildDisplayLayout() {
    return Row(
      children: [
        // Preparing
        Expanded(
          child: Container(
            color: AppColors.warning,
            child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    width: double.infinity,
                    color: AppColors.warning,
                    child: const Text("PREPARING",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.surfaceLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 24))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: 5,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text("${100 + i}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryLight)),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        // Ready
        Expanded(
          child: Container(
            color: AppColors.success,
            child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    width: double.infinity,
                    color: AppColors.success,
                    child: const Text("READY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.surfaceLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 24))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: 3,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text("${200 + i}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success)),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.textSecondary(context)),
          boxShadow: [
            BoxShadow(color: AppColors.textSecondary(context).withValues(alpha: 0.1), blurRadius: 5)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            const SizedBox(height: AppSpacing.xs),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.5,
        size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.8, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
              colors: [AppColors.primaryLight.withValues(alpha: 0.3), AppColors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



