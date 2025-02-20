import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/ItemDetailScreen.dart';
import 'package:flutter_application_1/main.dart';

class InterestedItemsScreen extends StatefulWidget {
  const InterestedItemsScreen({Key? key}) : super(key: key);

  @override
  State<InterestedItemsScreen> createState() => _InterestedItemsScreenState();
}

class _InterestedItemsScreenState extends State<InterestedItemsScreen> {
  List<Item> _interestedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInterestedItems();
  }

  Future<void> _fetchInterestedItems() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get user's interested items list
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      List<String> interestedItemIds = [];
      if (userDoc.exists) {
        final userData = userDoc.data();
        interestedItemIds =
            List<String>.from(userData?['interestedItems'] ?? []);
      }

      // Fetch all items that the user is interested in
      final itemDocs = await Future.wait(interestedItemIds.map((itemId) =>
          FirebaseFirestore.instance.collection('items').doc(itemId).get()));

      if (mounted) {
        setState(() {
          _interestedItems = itemDocs
              .where((doc) =>
                      doc.exists &&
                      (doc.data()?['isAvailable'] ??
                          false) // Only include available items
                  )
              .map((doc) {
            final data = doc.data()!;
            return Item(
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              description: data['description'] ?? 'No description available',
              category: data['category'] ?? 'Miscellaneous',
              imageUrl: data['imageUrl'],
              location: data['location'] ?? 'Unknown location',
              address: data['address'] ?? 'No address provided',
              ownerId: data['ownerId'],
            );
          }).toList();
          _isLoading = false;
        });

        // Remove unavailable items from user's interested items
        final unavailableItemIds = interestedItemIds
            .where(
                (itemId) => !_interestedItems.any((item) => item.id == itemId))
            .toList();

        if (unavailableItemIds.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'interestedItems': FieldValue.arrayRemove(unavailableItemIds)
          });
        }
      }
    } catch (e) {
      print('Error fetching interested items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFromInterested(String itemId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'interestedItems': FieldValue.arrayRemove([itemId])
      });

      setState(() {
        _interestedItems.removeWhere((item) => item.id == itemId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from interested list')),
        );
      }
    } catch (e) {
      print('Error removing item from interested: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to remove item from interested list')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_interestedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No interested items yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _interestedItems.length,
      itemBuilder: (context, index) {
        final item = _interestedItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
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
                          child: const Icon(Icons.image_not_supported),
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
            title: Text(item.name),
            subtitle: Text(item.category),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _removeFromInterested(item.id),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemDetailsScreen(item: item),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
