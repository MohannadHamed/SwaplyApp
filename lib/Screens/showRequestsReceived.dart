import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SwapRequestReceived extends StatefulWidget {
  const SwapRequestReceived({Key? key}) : super(key: key);

  @override
  State<SwapRequestReceived> createState() => _SwapRequestReceivedState();
}

class _SwapRequestReceivedState extends State<SwapRequestReceived> {
  late Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  void _fetchRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _requestsStream = FirebaseFirestore.instance
        .collection('swapRequests')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

// In _SwapRequestReceivedState class (_updateRequestStatus method)
  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Get the request document
      final requestDoc = await FirebaseFirestore.instance
          .collection('swapRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final requestedItemId = requestData['requestedItemId'];
      final offeredItemId = requestData['offeredItemId'];

      if (newStatus == 'approved') {
        // Update requested item availability
        final requestedItemRef =
            FirebaseFirestore.instance.collection('items').doc(requestedItemId);
        batch.update(requestedItemRef, {
          'isAvailable': false,
          'swappedWith': offeredItemId,
          'swappedAt': FieldValue.serverTimestamp()
        });

        // Update offered item availability
        final offeredItemRef =
            FirebaseFirestore.instance.collection('items').doc(offeredItemId);
        batch.update(offeredItemRef, {
          'isAvailable': false,
          'swappedWith': requestedItemId,
          'swappedAt': FieldValue.serverTimestamp()
        });

        // Create swap history record
        final historyRef = FirebaseFirestore.instance.collection('swaps').doc();
        batch.set(historyRef, {
          'requestId': requestId,
          'requestedItemId': requestedItemId,
          'requestedItemName': requestData['requestedItemName'],
          'requestedItemImage': requestData['requestedItemImage'],
          'offeredItemId': offeredItemId,
          'offeredItemName': requestData['offeredItemName'],
          'offeredItemImage': requestData['offeredItemImage'],
          'ownerId': requestData['ownerId'],
          'requesterId': requestData['requesterId'],
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Update or reject other pending requests for both items
        final otherRequestsSnapshot = await FirebaseFirestore.instance
            .collection('swapRequests')
            .where('status', isEqualTo: 'pending')
            .where('requestedItemId',
                whereIn: [requestedItemId, offeredItemId]).get();

        for (var doc in otherRequestsSnapshot.docs) {
          if (doc.id != requestId) {
            batch.update(doc.reference, {
              'status': 'rejected',
              'rejectionReason': 'Item is no longer available',
              'updatedAt': FieldValue.serverTimestamp()
            });
          }
        }
      }

      // Update the current request status
      batch.update(requestDoc.reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'approved')
          'completedAt': FieldValue.serverTimestamp(),
      });

      // Commit all changes in one atomic operation
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $newStatus successfully'),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating request status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating request status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests Received'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No pending requests received.'),
            );
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
                    child: requestData['requestedItemImage'] != null &&
                            requestData['requestedItemImage'].isNotEmpty
                        ? Image.network(
                            requestData['requestedItemImage'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image_not_supported);
                            },
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
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
                      if (requestData['message'] != null &&
                          requestData['message'].isNotEmpty)
                        Text('Message: ${requestData['message']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        color: Colors.green,
                        onPressed: () {
                          _updateRequestStatus(request.id, 'approved');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.red,
                        onPressed: () {
                          _updateRequestStatus(request.id, 'rejected');
                        },
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
