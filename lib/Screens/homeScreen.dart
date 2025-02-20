import 'dart:async';
import 'package:badges/badges.dart' as custom_badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/ItemDetailScreen.dart';
import 'package:flutter_application_1/Screens/addItem.dart';
import 'package:flutter_application_1/Screens/profile.dart';
import 'package:flutter_application_1/Screens/showRequestsReceived.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/Screens/ChatListScreen.dart';
import 'package:flutter_application_1/Screens/InterestedItemsScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _pendingRequestCount = 0;
  int _unreadChatCount = 0;
  bool _isAddingItem = false;
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  List<Item> _availableItems = [];
  
  StreamSubscription<QuerySnapshot>? _itemsSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _pendingRequestSubscription;

  final List<String> _categories = [
    'All', 'Electronics', 'Sports', 'Music', 'Outdoor', 'Gaming', 
    'Photography', 'Books', 'Fashion', 'Home', 'Art'
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isSearchFocused = _searchFocusNode.hasFocus;
        });
      }
    });
    _setupItemsListener();
    _fetchPendingRequestCount();
    _calculateUnreadChats();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _chatSubscription?.cancel();
    _pendingRequestSubscription?.cancel();
    _searchController.dispose();
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
      if (!mounted) return;
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
              item.ownerId != currentUser.uid && 
              item.isAvailable == true
            )
            .toList();
      });
    }, onError: (error) {
      print('Error in items stream: $error');
    });
  }

  void _calculateUnreadChats() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    _chatSubscription?.cancel();
    _chatSubscription = FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final chatData = doc.data();
        final unreadMap = chatData['unreadCount'] as Map<String, dynamic>?;
        if (unreadMap != null && unreadMap[currentUserId] != null) {
          unreadCount += (unreadMap[currentUserId] as int);
        }
      }
      setState(() {
        _unreadChatCount = unreadCount;
      });
    }, onError: (error) {
      print('Error in chat stream: $error');
    });
  }

  void _fetchPendingRequestCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _pendingRequestSubscription?.cancel();
    _pendingRequestSubscription = FirebaseFirestore.instance
        .collection('swapRequests')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((querySnapshot) {
      if (!mounted) return;
      setState(() {
        _pendingRequestCount = querySnapshot.docs.length;
      });
    }, onError: (error) {
      print('Error in pending requests stream: $error');
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Item> get _filteredItems {
    return _availableItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'All' ||
          item.category.toLowerCase() == _selectedCategory!.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _toggleInterested(String itemId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final userDoc = await userRef.get();
      final interestedItems = List<String>.from(userDoc.data()?['interestedItems'] ?? []);

      if (interestedItems.contains(itemId)) {
        await userRef.update({
          'interestedItems': FieldValue.arrayRemove([itemId])
        });
      } else {
        await userRef.update({
          'interestedItems': FieldValue.arrayUnion([itemId])
        });
      }
    } catch (e) {
      print('Error toggling interested status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        appBar: _selectedIndex != 4
            ? AppBar(
                title: Text(_selectedIndex == 0
                    ? 'Discovery'
                    : _selectedIndex == 1
                        ? 'Chat'
                        : _selectedIndex == 2
                            ? 'Interested In'
                            : _selectedIndex == 3
                                ? 'Requests'
                                : ''),
              )
            : null,
        floatingActionButton: (_selectedIndex == 0 && !_isSearchFocused)
            ? FloatingActionButton(
                onPressed: _isAddingItem
                    ? null
                    : () async {
                        setState(() {
                          _isAddingItem = true;
                        });
                        try {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddItemScreen(),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isAddingItem = false;
                            });
                          }
                        }
                      },
                backgroundColor: const Color.fromARGB(255, 25, 73, 72),
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Discovery',
            ),
            BottomNavigationBarItem(
              icon: custom_badges.Badge(
                badgeContent: Text(
                  '$_unreadChatCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                showBadge: _unreadChatCount > 0,
                child: const Icon(Icons.chat),
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Interested',
            ),
            BottomNavigationBarItem(
              icon: custom_badges.Badge(
                badgeContent: Text(
                  '$_pendingRequestCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                showBadge: _pendingRequestCount > 0,
                position: custom_badges.BadgePosition.topEnd(top: -10, end: -12),
                child: const Icon(Icons.notifications),
              ),
              label: 'Requests',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color.fromARGB(255, 25, 73, 72),
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDiscoveryScreen();
      case 1:
        return const ChatListScreen();
      case 2:
        return const InterestedItemsScreen();
      case 3:
        return const SwapRequestReceived();
      case 4:
        return const ProfileScreen();
      default:
        return _buildDiscoveryScreen();
    }
  }

  Widget _buildDiscoveryScreen() {
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
                  setState(() {
                    _searchQuery = value;
                  });
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
                          setState(() {
                            _selectedCategory = selected ? category : null;
                          });
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
                              builder: (context) => ItemDetailsScreen(item: item),
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
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                StreamBuilder<DocumentSnapshot>(
                                                  stream: FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(FirebaseAuth.instance
                                                          .currentUser?.uid)
                                                      .snapshots(),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return const SizedBox();
                                                    }
                                                    final userData = snapshot.data!.data()
                                                        as Map<String, dynamic>?;
                                                    final interestedItems =
                                                        List<String>.from(
                                                            userData?[
                                                                    'interestedItems'] ??
                                                                []);
                                                    final isInterested =
                                                        interestedItems
                                                            .contains(item.id);

                                                    return IconButton(
                                                      icon: Icon(
                                                        isInterested
                                                            ? Icons.favorite
                                                            : Icons.favorite_border,
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
                                                const Icon(Icons.person_outline,
                                                    size: 16, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                FutureBuilder<DocumentSnapshot>(
                                                  future: FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(item.ownerId)
                                                      .get(),
                                                  builder: (context, snapshot) {
                                                    String ownerName = 'Unknown';
                                                    if (snapshot.hasData &&
                                                        snapshot.data != null) {
                                                      ownerName = snapshot
                                                              .data!['name'] ??
                                                          'Unknown';
                                                    }
                                                    return Text(
                                                      ownerName,
                                                      style: const TextStyle(
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
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(item.category,
                                          style:
                                              TextStyle(color: Colors.grey[600])),
                                      const SizedBox(width: 16),
                                      Icon(Icons.location_on,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(item.address,
                                          style:
                                              TextStyle(color: Colors.grey[600])),
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