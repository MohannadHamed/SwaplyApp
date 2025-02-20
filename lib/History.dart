import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyData;

  @override
  void initState() {
    super.initState();
    _historyData = _fetchHistoryData();
  }

  // Fetch completed swaps from Firestore
  Future<List<Map<String, dynamic>>> _fetchHistoryData() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return [];
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection(
            'swaps') // Assuming "swaps" collection tracks completed swaps
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'completed') // Fetch only completed swaps
        .orderBy('completionDate', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('An error occurred'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No history available'));
          } else {
            final historyItems = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: historyItems.length,
              itemBuilder: (context, index) {
                final item = historyItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: ListTile(
                    leading: item['imageUrl'] != null
                        ? Image.network(
                            item['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image, size: 50),
                    title: Text(
                      item['itemName'] ?? 'Unknown Item',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Swapped with: ${item['partnerName'] ?? 'Unknown'}\n'
                      'Date: ${item['completionDate'] != null ? (item['completionDate'] as Timestamp).toDate().toString().split(' ')[0] : 'Unknown'}',
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
