import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/ItemDetailScreen.dart';
import 'package:flutter_application_1/Screens/editItem.dart';
import 'package:flutter_application_1/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyItemsScreen extends StatefulWidget {
  final List<Item> items;
  final Function() onItemsChanged;

  const MyItemsScreen({
    Key? key,
    required this.items,
    required this.onItemsChanged,
  }) : super(key: key);

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  List<Item> _userItems = [];

  @override
  void initState() {
    super.initState();
    _userItems = widget.items;
    _fetchItems();
    // Set up refresh listener
    FirebaseFirestore.instance
        .collection('items')
        .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      _fetchItems();
    });
  }

  Future<void> _fetchItems() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: currentUser.uid)
          .where('isAvailable', isEqualTo: true) // Only fetch available items
          .get();

      if (mounted) {
        // Ensure the widget is still active
        setState(() {
          _userItems = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return Item(
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              description: data['description'] ?? '',
              category: data['category'] ?? '',
              imageUrl: data['imageUrl'],
              location: data['location'] ?? '',
              address: data['address'] ?? '',
              ownerId: data['ownerId'],
              isAvailable: data['isAvailable'] ?? true,
              isDonation: data['isDonation'] ?? false,
            );
          }).toList();
        });
        widget.onItemsChanged();
      }
    } catch (e) {
      print('Error fetching items: $e');
    }
  }

  Future<bool?> _confirmDeleteItem(Item item) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(String itemId) async {
    try {
      await FirebaseFirestore.instance.collection('items').doc(itemId).delete();

      // Use setState to update the list and trigger a rebuild
      setState(() {
        _userItems.removeWhere((item) => item.id == itemId);
      });

      widget.onItemsChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
      }
    } catch (e) {
      print('Error deleting item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove item')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
      ),
      body: _userItems.isEmpty
          ? const Center(
              child: Text(
                'You have no items.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: _userItems.length,
              itemBuilder: (context, index) {
                final item = _userItems[index];
                return Dismissible(
                  key: Key(item.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await _confirmDeleteItem(item) ?? false;
                  },
                  onDismissed: (direction) {
                    _removeItem(item.id);
                  },
                  child: Card(
                    child: Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: item.imageUrl != null &&
                                      item.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      item.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                              Icons.image_not_supported),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child:
                                          const Icon(Icons.image_not_supported),
                                    ),
                            ),
                            title: Text(item.name),
                            subtitle: Text(item.category),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ItemDetailsScreen(item: item),
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Color.fromARGB(255, 25, 73, 72)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditItemScreen(item: item),
                              ),
                            ).then((updatedItem) {
                              if (updatedItem != null) {
                                setState(() {
                                  _userItems[index] = updatedItem;
                                });
                                widget.onItemsChanged();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
