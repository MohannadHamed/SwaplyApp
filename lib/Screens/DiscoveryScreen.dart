import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/ItemDetailScreen.dart';
import 'package:flutter_application_1/main.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> 
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  List<Item> _availableItems = [];
  StreamSubscription<QuerySnapshot>? _itemsSubscription;
  StreamSubscription<QuerySnapshot>? _interestedItemsSubscription;
  bool _disposed = false;

  @override
  bool get wantKeepAlive => true;

  final List<String> _categories = [
    'All', 'Electronics', 'Sports', 'Music', 'Outdoor', 'Gaming',
    'Photography', 'Books', 'Fashion', 'Home', 'Art'
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChange);
    _setupItemsListener();
  }

  void _handleFocusChange() {
    if (!_disposed && mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _itemsSubscription?.cancel();
    _interestedItemsSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _setupItemsListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _itemsSubscription?.cancel();
    _itemsSubscription = FirebaseFirestore.instance
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          if (_disposed || !mounted) return;
          setState(() {
            _availableItems = snapshot.docs
                .map((doc) {
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
                    isAvailable: data['isAvailable'] ?? false,
                    isDonation: data['isDonation'] ?? false,
                  );
                })
                .where((item) =>
                    item.ownerId != currentUser.uid && item.isAvailable == true)
                .toList();
          });
        }, onError: (error) {
          print('Error in items stream: $error');
        });
  }

  List<Item> get _filteredItems {
    return _availableItems.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          item.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _toggleInterested(String itemId) async {
    if (_disposed) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      final userDoc = await userRef.get();
      final interestedItems =
          List<String>.from(userDoc.data()?['interestedItems'] ?? []);

      if (!_disposed) {
        if (interestedItems.contains(itemId)) {
          await userRef
              .update({'interestedItems': FieldValue.arrayRemove([itemId])});
        } else {
          await userRef
              .update({'interestedItems': FieldValue.arrayUnion([itemId])});
        }
      }
    } catch (e) {
      print('Error toggling interested status: $e');
      if (!_disposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update interested status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) {
                  if (!_disposed && mounted) {
                    setState(() {
                      _searchQuery = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        onSelected: (selected) {
                          if (!_disposed && mounted) {
                            setState(() {
                              _selectedCategory = selected ? category : 'All';
                            });
                          }
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: const Color.fromARGB(255, 25, 73, 72)
                            .withOpacity(0.2),
                        checkmarkColor: const Color.fromARGB(255, 25, 73, 72),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No items found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ItemDetailsScreen(item: item),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: item.imageUrl != null &&
                                      item.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                StreamBuilder<DocumentSnapshot>(
                                                  stream: FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(FirebaseAuth.instance
                                                          .currentUser?.uid)
                                                      .snapshots(),
                                                  builder:
                                                      (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return const SizedBox();
                                                    }
                                                    final userData = snapshot
                                                            .data!
                                                            .data()
                                                        as Map<String,
                                                            dynamic>?;
                                                    final interestedItems =
                                                        List<String>.from(
                                                            userData?[
                                                                    'interestedItems'] ??
                                                                []);
                                                    final isInterested =
                                                        interestedItems
                                                            .contains(
                                                                item.id);

                                                    return IconButton(
                                                      icon: Icon(
                                                        isInterested
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        color: isInterested
                                                            ? Colors.red
                                                            : null,
                                                      ),
                                                      onPressed: () =>
                                                          _toggleInterested(
                                                              item.id),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons.person_outline,
                                                    size: 16,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                FutureBuilder<
                                                    DocumentSnapshot>(
                                                  future: FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(item.ownerId)
                                                      .get(),
                                                  builder:
                                                      (context, snapshot) {
                                                    String ownerName =
                                                        'Unknown';
                                                    if (snapshot.hasData &&
                                                        snapshot.data !=
                                                            null) {
                                                      ownerName = snapshot
                                                              .data!['name'] ??
                                                          'Unknown';
                                                    }
                                                    return Text(
                                                      ownerName,
                                                      style:
                                                          const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.category,
                                          size: 16,
                                          color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(item.category,
                                          style: TextStyle(
                                              color: Colors.grey[600])),
                                      const SizedBox(width: 16),
                                      Icon(Icons.location_on,
                                          size: 16,
                                          color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(item.address,
                                          style: TextStyle(
                                              color: Colors.grey[600])),
                                      if (item.isDonation == true) ...[
                                        const SizedBox(width: 16),
                                        const Text(
                                          'Donated Item',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}