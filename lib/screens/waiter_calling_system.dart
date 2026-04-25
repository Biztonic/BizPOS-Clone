import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Waiter Calling System"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: calls.length,
        separatorBuilder: (_,__) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final call = calls[index];
          final isUrgent = call['type'] == 'Bill';
          return Card(
            elevation: 4,
            color: isUrgent ? Colors.orange.shade50 : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isUrgent ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isUrgent ? Colors.orange : Colors.blue,
                    child: Text(
                      call['table']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Request for ${call['type']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(call['time']!, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (){},
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    child: const Text("Attend"),
                  )
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){}, 
        label: const Text("Clear All"),
        icon: const Icon(Icons.clear_all),
      ),
    );
  }
}
