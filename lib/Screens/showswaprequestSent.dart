import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SwapRequestSent extends StatefulWidget {
  const SwapRequestSent({Key? key}) : super(key: key);

  @override
  State<SwapRequestSent> createState() => _SwapRequestSentState();
}

class _SwapRequestSentState extends State<SwapRequestSent> {
  late Stream<QuerySnapshot> _sentRequestsStream;

  @override
  void initState() {
    super.initState();
    _sentRequestsStream = _fetchSentRequests();
  }

  Stream<QuerySnapshot> _fetchSentRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('swapRequests')
        .where('requesterId', isEqualTo: currentUser.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sent Swap Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _sentRequestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading requests'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No swap requests sent yet.'));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final requestData = request.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      requestData['requestedItemImage'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported);
                      },
                    ),
                  ),
                  title: Text(
                    'Requested: ${requestData['requestedItemName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category: ${requestData['requestedItemCategory']}'),
                      Text('Offered: ${requestData['offeredItemName']}'),
                      Text('Status: ${requestData['status']}'),
                      if (requestData['message'] != null &&
                          requestData['message'].isNotEmpty)
                        Text('Message: ${requestData['message']}'),
                    ],
                  ),
                  trailing: Text(
                    requestData['status'].toUpperCase(),
                    style: TextStyle(
                      color: requestData['status'] == 'approved'
                          ? Colors.green
                          : requestData['status'] == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
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
