
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
        secondary: isLocked ? const Icon(Icons.lock, color: Colors.grey) : null,
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
            if (isLocked) const Icon(Icons.lock, color: Colors.grey, size: 18),
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
                    const Icon(Icons.lock, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      '$title is locked by plan',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _buildBody(context)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatCard(context, "Total", "124", Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard(context, "Active", "89", Colors.green),
              const SizedBox(width: 16),
              _buildStatCard(context, "Pending", "35", Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          // Gradient Chart
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: CustomPaint(painter: _MockChartPainter()),
          ),
          const SizedBox(height: 24),
          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(icon, color: Colors.grey),
                ),
                title: Container(
                  height: 16,
                  width: 150,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4)),
                ),
                subtitle: Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4)),
                ),
                trailing: Container(
                  height: 24,
                  width: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.all(16),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(8),
                color: index % 2 == 0
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
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
                  padding: const EdgeInsets.all(8),
                  itemCount: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                            width: 20,
                            height: 20,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: Text("1x",
                                    style: TextStyle(fontSize: 10)))),
                        const SizedBox(width: 8),
                        Container(
                            height: 10,
                            width: 100,
                            color: Colors.grey.shade300),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      child: const Text("Done",
                          style: TextStyle(color: Colors.white))),
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
      padding: const EdgeInsets.all(24),
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
            color: isOccupied ? Colors.red.shade50 : Colors.green.shade50,
            shape: BoxShape.circle,
            border: Border.all(
                color: isOccupied ? Colors.red.shade200 : Colors.green.shade200,
                width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant,
                  size: 32, color: isOccupied ? Colors.red : Colors.green),
              const SizedBox(height: 8),
              Text("T-${index + 1}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOccupied ? Colors.red : Colors.green)),
              if (isOccupied)
                const Text("24:00",
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
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
            color: Colors.orange.shade50,
            child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    color: Colors.orange,
                    child: const Text("PREPARING",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 5,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text("${100 + i}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54)),
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
            color: Colors.green.shade50,
            child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    color: Colors.green,
                    child: const Text("READY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 3,
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text("${200 + i}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 5)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
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
      ..color = Colors.blue.shade300
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
              colors: [Colors.blue.withValues(alpha: 0.3), Colors.transparent],
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
