import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/swapRequestScreen.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/Screens/UserProfileScreen.dart';
import 'package:flutter_application_1/Screens/ChatScreen.dart';

class ItemDetailsScreen extends StatefulWidget {
  final Item item;

  const ItemDetailsScreen({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  String _ownerName = '';
  String? _ownerPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchOwnerName();
  }

  Future<void> _fetchOwnerName() async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.item.ownerId)
          .get();

      if (ownerDoc.exists && mounted) {
        final ownerData = ownerDoc.data();
        setState(() {
          _ownerName = ownerData?['name'] ?? '';
          _ownerPhotoUrl = ownerData?['photoUrl'];
        });
      }
    } catch (e) {
      print('Error fetching owner name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: widget.item.imageUrl != null &&
                        widget.item.imageUrl!.isNotEmpty
                    ? Image.network(
                        widget.item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),

            // Item Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owner Profile Section
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: widget.item.ownerId,
                            userName: _ownerName,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color.fromARGB(255, 25, 73, 72),
                          backgroundImage: _ownerPhotoUrl != null
                              ? NetworkImage(_ownerPhotoUrl!)
                              : null,
                          child: _ownerPhotoUrl == null
                              ? Text(
                                  _ownerName.isNotEmpty
                                      ? _ownerName[0].toUpperCase()
                                      : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ownerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.item.address,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Item Name
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category Tag
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 25, 73, 72)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.item.category,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 25, 73, 72),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description Section
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description,
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Only show bottom buttons if the viewer is not the owner
      bottomNavigationBar: FirebaseAuth.instance.currentUser?.uid !=
              widget.item.ownerId
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Message Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  otherUserId: widget.item.ownerId,
                                  otherUserName: _ownerName,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: Colors.white,
                          foregroundColor:
                              const Color.fromARGB(255, 25, 73, 72),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 25, 73, 72),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Request / Request Swap Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final currentUser = FirebaseAuth.instance.currentUser;

                          if (currentUser == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please log in to make a request.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

// Fetch current user's name
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser.uid)
                              .get();
                          final requesterName = userDoc.data()?['name'] ?? '';

                          if (widget.item.isDonation) {
                            // Construct the donation request with requesterName
                            final donationRequest = {
                              'requesterId': currentUser.uid,
                              'requesterName':
                                  requesterName, // Add this line only for donation
                              'ownerId': widget.item.ownerId,
                              'requestedItemId': widget.item.id,
                              'requestedItemName': widget.item.name,
                              'requestedItemCategory': widget.item.category,
                              'requestedItemImage': widget.item.imageUrl,
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            };

                            await FirebaseFirestore.instance
                                .collection('swapRequests')
                                .add(donationRequest);

                            // Confirmation Dialog
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Request Sent'),
                                  content: const Text(
                                    'Your donation request has been sent. You will be notified when the owner responds.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            // Navigate to SwapRequestScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SwapRequestScreen(
                                  requestedItem: widget.item,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(widget.item.isDonation
                            ? 'Request'
                            : 'Request Swap'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null, // Don't show bottom navigation bar for own items
    );
  }
}
