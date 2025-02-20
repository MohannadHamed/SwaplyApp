import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/addItem.dart';
import 'package:flutter_application_1/main.dart'; // Import the Item model

class SwapRequestScreen extends StatefulWidget {
  final Item requestedItem;

  const SwapRequestScreen({
    Key? key,
    required this.requestedItem,
  }) : super(key: key);

  @override
  State<SwapRequestScreen> createState() => _SwapRequestScreenState();
}

class _SwapRequestScreenState extends State<SwapRequestScreen> {
  Item? selectedItem;
  final TextEditingController _messageController = TextEditingController();
  List<Item> myItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMyItems();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Handles rejected request scenarios
  void _handleRejectedRequest(Map<String, dynamic> requestData) {
    if (requestData['rejectionReason'] == 'Item is no longer available') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Swap Request Rejected'),
            content: const Text(
              'Sorry, this item is no longer available for swapping. It has already been swapped with another user.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  /// Fetches the current user's available items from Firestore.
  Future<void> _fetchMyItems() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // If the user is not logged in, show a message and navigate back.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request a swap.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Query Firestore for items owned by the current user that are available
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: currentUser.uid)
          .where('isAvailable', isEqualTo: true)
          .get();

      setState(() {
        // Only include items that are still available
        myItems = querySnapshot.docs
            .map((doc) => Item.fromDocument(doc))
            .where((item) => item.isAvailable)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching my items: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load your items. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Checks item availability before sending a swap request
  Future<bool> _checkItemAvailability(String itemId) async {
    try {
      final itemDoc = await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .get();

      return itemDoc.exists && (itemDoc.data()?['isAvailable'] ?? false);
    } catch (e) {
      print('Error checking item availability: $e');
      return false;
    }
  }

  Future<void> _sendSwapRequest() async {
    if (selectedItem == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null ||
        currentUser.uid == widget.requestedItem.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot request swap with your own item')),
      );
      return;
    }

    try {
      // Check availability of both items
      final requestedItemAvailable =
          await _checkItemAvailability(widget.requestedItem.id);
      final offeredItemAvailable =
          await _checkItemAvailability(selectedItem!.id);

      if (!requestedItemAvailable || !offeredItemAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('One or more items are no longer available for swapping'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check for existing pending swap requests
      final existingRequestsSnapshot = await FirebaseFirestore.instance
          .collection('swapRequests')
          .where('requestedItemId', isEqualTo: widget.requestedItem.id)
          .where('requesterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequestsSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already sent a swap request for this item'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Prepare the swap request
      final swapRequestRef = FirebaseFirestore.instance
          .collection('swapRequests')
          .doc(); // Auto-generate ID

      final request = {
        'requesterId': currentUser.uid,
        'ownerId': widget.requestedItem.ownerId,
        'requestedItemId': widget.requestedItem.id,
        'requestedItemName': widget.requestedItem.name,
        'requestedItemCategory': widget.requestedItem.category,
        'requestedItemImage': widget.requestedItem.imageUrl,
        'offeredItemId': selectedItem!.id,
        'offeredItemName': selectedItem!.name,
        'offeredItemCategory': selectedItem!.category,
        'offeredItemImage': selectedItem!.imageUrl,
        'status': 'pending',
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        // Add flag to indicate swap is in negotiation
        'inNegotiation': true
      };

      // Add swap request
      await swapRequestRef.set(request);

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Swap Request Sent'),
            content: const Text(
              'Your swap request has been sent. The owner will review your request.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error sending swap request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error occurred while sending swap request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigates to AddItemScreen and refreshes the items list upon returning.
  Future<void> _navigateToAddItem() async {
    final result = await Navigator.push<Item>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddItemScreen(),
      ),
    );

    // Always refresh the items list when returning from AddItemScreen
    await _fetchMyItems();

    if (mounted) {
      setState(() {
        // If the newly added item exists, select it automatically
        if (result != null) {
          selectedItem = myItems.firstWhere(
            (item) => item.id == result.id,
            orElse: () => selectedItem ?? myItems.first,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Swap Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Requested Item Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requested Item:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: widget.requestedItem.imageUrl != null &&
                                widget.requestedItem.imageUrl!.isNotEmpty
                            ? Image.network(
                                widget.requestedItem.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child:
                                        const Icon(Icons.image_not_supported),
                                  );
                                },
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              ),
                      ),
                      title: Text(widget.requestedItem.name),
                      subtitle: Text(widget.requestedItem.category),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Select Item to Offer
            const Text(
              'Select an item to offer:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (myItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'You don\'t have any items to offer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _navigateToAddItem,
                        child: const Text('Add an Item'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myItems.length,
                itemBuilder: (context, index) {
                  final item = myItems[index];
                  return Card(
                    child: RadioListTile<Item>(
                      value: item,
                      groupValue: selectedItem,
                      onChanged: (Item? value) {
                        setState(() {
                          selectedItem = value;
                        });
                      },
                      title: Text(item.name),
                      subtitle: Text(item.category),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: item.imageUrl != null &&
                                item.imageUrl!.isNotEmpty
                            ? Image.network(
                                item.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child:
                                        const Icon(Icons.image_not_supported),
                                  );
                                },
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Message Field
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Add a message (optional)',
                border: OutlineInputBorder(),
                hintText: 'Would you like to swap?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Send Request Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (myItems.isEmpty || selectedItem == null || isLoading)
                        ? null
                        : _sendSwapRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: const Text('Send Swap Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
