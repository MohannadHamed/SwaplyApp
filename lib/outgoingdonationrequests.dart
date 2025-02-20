import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OutgoingDonationRequestsScreen extends StatefulWidget {
  const OutgoingDonationRequestsScreen({super.key});

  @override
  State<OutgoingDonationRequestsScreen> createState() =>
      _OutgoingDonationRequestsScreenState();
}

class _OutgoingDonationRequestsScreenState
    extends State<OutgoingDonationRequestsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Donation Requests"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donationRequests')
            .where('requesterId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("You haven't requested any donations."),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: request['requestedItemImage'] != null
                      ? Image.network(
                          request['requestedItemImage'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image_not_supported),
                  title: Text(request['requestedItemName'] ?? "Unknown Item"),
                  subtitle: Text("Owner: ${request['ownerId']}"),
                  trailing: Text(
                    request['status'] ?? "Pending",
                    style: TextStyle(
                      color: request['status'] == "approved"
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
