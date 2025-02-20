import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/ChatScreen.dart';
import 'package:intl/intl.dart';

class SwapHistoryScreen extends StatefulWidget {
  const SwapHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SwapHistoryScreen> createState() => _SwapHistoryScreenState();
}

class _SwapHistoryScreenState extends State<SwapHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _fetchSentRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('swapRequests')
        .where('requesterId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _fetchReceivedRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('swapRequests')
        .where('ownerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _formatDate(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> requestData, bool isSent) {
    final String requestedItemName =
        requestData['requestedItemName']?.toString() ?? 'N/A';
    final String requestedItemCategory =
        requestData['requestedItemCategory']?.toString() ?? 'N/A';
    final String offeredItemName =
        requestData['offeredItemName']?.toString() ?? 'N/A';
    final String offeredItemCategory =
        requestData['offeredItemCategory']?.toString() ?? 'N/A';
    final String? requestedItemImage =
        requestData['requestedItemImage']?.toString();
    final String? offeredItemImage =
        requestData['offeredItemImage']?.toString();
    final String status = requestData['status']?.toString() ?? 'N/A';
    final String message = requestData['message']?.toString() ?? '';
    final Timestamp? createdAt =
        requestData['createdAt'] is Timestamp ? requestData['createdAt'] : null;
    final Timestamp? swappedAt =
        requestData['swappedAt'] is Timestamp ? requestData['swappedAt'] : null;

    String otherUserId = isSent 
        ? requestData['ownerId'] 
        : requestData['requesterId'];

    String otherUserName = isSent 
        ? (requestData['ownerName'] ?? 'Swap Partner')
        : (requestData['requesterName'] ?? 'Swap Partner');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: isSent
              ? (requestedItemImage != null && requestedItemImage.isNotEmpty
                  ? Image.network(
                      requestedItemImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ))
              : (offeredItemImage != null && offeredItemImage.isNotEmpty
                  ? Image.network(
                      offeredItemImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    )),
        ),
        title: Text(
          isSent
              ? 'Requested: $requestedItemName'
              : 'Offered: $offeredItemName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSent
                  ? 'Category: $requestedItemCategory'
                  : 'Category: $offeredItemCategory',
            ),
            const SizedBox(height: 4),
            Text('Status: $status'),
            const SizedBox(height: 4),
            if (message.isNotEmpty) Text('Message: $message'),
            const SizedBox(height: 4),
            if (createdAt != null)
              Text(
                'Date: ${_formatDate(createdAt)}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            if (swappedAt != null && status == 'approved')
              Text(
                'Swapped At: ${_formatDate(swappedAt)}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.message, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  otherUserId: otherUserId,
                  otherUserName: otherUserName,
                ),
              ),
            );
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildSwapRequestList(
      Stream<QuerySnapshot> stream, bool isSentSection) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading swap history: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              isSentSection
                  ? 'You have not sent any swap requests yet.'
                  : 'You have not received any swap requests yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final swapRequests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: swapRequests.length,
          itemBuilder: (context, index) {
            final request = swapRequests[index];
            final requestData = request.data() as Map<String, dynamic>;

            return _buildSwapRequestCard(requestData, isSentSection);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Swaps You Sent'),
            Tab(text: 'Swaps You Received'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSwapRequestList(_fetchSentRequests(), true),
          _buildSwapRequestList(_fetchReceivedRequests(), false),
        ],
      ),
    );
  }
}