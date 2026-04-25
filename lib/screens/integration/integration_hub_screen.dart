import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class IntegrationHubScreen extends StatefulWidget {
  const IntegrationHubScreen({super.key});

  @override
  State<IntegrationHubScreen> createState() => _IntegrationHubScreenState();
}

class _IntegrationHubScreenState extends State<IntegrationHubScreen> {
  // Mock State for now - in production this would persist to backend/hive
  final Map<String, bool> _connections = {
    'swiggy': false,
    'zomato': false,
    'ubereats': false,
    'talabat': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Integration Hub"),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.history), tooltip: "Sync Logs"),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manage Third-Party Connections",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connect your POS to external platforms for seamless order synchronization.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: Responsive.isMobile(context) ? 1 : 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildIntegrationCard(
                    id: 'swiggy',
                    name: 'Swiggy',
                    icon: Icons.delivery_dining,
                    color: Colors.orange,
                    description: "Receive orders directly from Swiggy.",
                  ),
                  _buildIntegrationCard(
                    id: 'zomato',
                    name: 'Zomato',
                    icon: Icons.restaurant,
                    color: Colors.red,
                    description: "Sync menu and orders with Zomato.",
                  ),
                  _buildIntegrationCard(
                    id: 'ubereats',
                    name: 'Uber Eats',
                    icon: Icons.directions_bike,
                    color: Colors.green,
                    description: "Global delivery platform integration.",
                  ),
                   _buildIntegrationCard(
                    id: 'talabat',
                    name: 'Talabat',
                    icon: Icons.fastfood,
                    color: Colors.orangeAccent,
                    description: "Middle-east delivery aggregator.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationCard({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    final isConnected = _connections[id] ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isConnected ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Switch(
                  value: isConnected,
                  activeColor: color,
                  onChanged: (val) {
                    setState(() {
                      _connections[id] = val;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? "Connected to $name" : "Disconnected from $name"),
                        backgroundColor: val ? Colors.green : Colors.grey,
                        behavior: SnackBarBehavior.floating,
                        width: 400,
                      ),
                    );
                  },
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (isConnected)
               Row(
                 children: [
                   const Icon(Icons.check_circle, size: 14, color: Colors.green),
                   const SizedBox(width: 4),
                   const Text("Online", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   TextButton(
                     onPressed: () {}, 
                     style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                     child: const Text("Settings")
                   )
                 ],
               )
            else
               const Row(
                 children: [
                   Icon(Icons.circle, size: 14, color: Colors.grey),
                   SizedBox(width: 4),
                   Text("Offline", style: TextStyle(color: Colors.grey, fontSize: 12)),
                 ],
               )
          ],
        ),
      ),
    );
  }
}
