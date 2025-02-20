import 'dart:async';
import 'dart:io';
//import 'package:flutter_application_1/History.dart';
import 'package:flutter_application_1/Screens/swapHistoryScreen.dart';
import 'package:flutter_application_1/incomingdonationrequests.dart';
import 'package:flutter_application_1/outgoingdonationrequests.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/login.dart';
import 'package:flutter_application_1/Screens/mapprofile.dart';
import 'package:flutter_application_1/Screens/myItemScreen.dart'; // Import MapScreen for updating profile
import 'package:flutter_application_1/Screens/showswaprequestSent.dart';
import 'package:flutter_application_1/main.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController(); // For the address
  final _ageController = TextEditingController();
  TextEditingController _currentPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  File? _newProfileImage;
  String? _profileImageUrl;
  bool _isEditing = false;
  bool _isLoading = false;
  List<Item> _userItems = [];
  double? _latitude; // User's latitude
  double? _longitude; // User's longitude
  StreamSubscription? _userDataSubscription;
  StreamSubscription? _userItemsSubscription;
  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserItems();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _userItemsSubscription?.cancel();
    _nameController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  void _fetchUserData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Cancel any existing subscription before creating a new one
    _userDataSubscription?.cancel();

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userData = userData;
          _latitude = userData?['latitude']?.toDouble();
          _longitude = userData?['longitude']?.toDouble();

          // Update all text controllers with the fetched data
          _nameController.text = userData?['name'] ?? '';
          _locationController.text = _latitude != null && _longitude != null
              ? 'Lat: $_latitude, Long: $_longitude'
              : '';
          _addressController.text = userData?['address'] ?? '';
          _ageController.text = userData?['age']?.toString() ?? '';
          _profileImageUrl = userData?['photoUrl'];

          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Error fetching user data: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _fetchUserItems() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Cancel any existing subscription before creating a new one
      _userItemsSubscription?.cancel();

      _userItemsSubscription = FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: currentUser.uid)
          .where('isAvailable', isEqualTo: true)
          .snapshots()
          .listen((querySnapshot) {
        if (!mounted) return;
        setState(() {
          _userItems = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return Item(
              address: data['address'] ?? 'unknown',
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              description: data['description'] ?? 'No description available',
              category: data['category'] ?? 'Miscellaneous',
              imageUrl: data['imageUrl'] ?? '',
              location: data['location'] ?? 'Unknown location',
              ownerId: data['ownerId'] ?? 'Unknown owner',
            );
          }).toList();
        });
      }, onError: (error) {
        print('Error fetching user items: $error');
      });
    }
  }

  void _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      String? photoUrl;
      if (_newProfileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child('${currentUser.uid}.jpg');
        await storageRef.putFile(_newProfileImage!);
        photoUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'name': _nameController.text,
        'latitude': _latitude, // Save latitude directly
        'longitude': _longitude, // Save longitude directly
        'address': _addressController.text, // Update address field
        'age': int.parse(_ageController.text),
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changePassword() async {
    // Validate input fields
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields')),
      );
      return;
    }

    // Check if new password matches confirmation
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    // Check password strength
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters long')),
      );
      return;
    }

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      // Re-authenticate user
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _currentPasswordController.text);

      // Reauthenticate first
      await user.reauthenticateWithCredential(cred);

      // Change password
      await user.updatePassword(_newPasswordController.text);

      // Clear controllers
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Close dialog and show success message
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again to change password';
          break;
        default:
          errorMessage = e.message ?? 'Authentication error';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Handle any other unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Clear controllers when canceling
                _currentPasswordController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Cancel any ongoing streams or listeners
                  await _cancelActiveListeners();

                  // Sign out of Firebase
                  await FirebaseAuth.instance.signOut();

                  // Clear any GetX controllers or states
                  Get.deleteAll(force: true);

                  // Use pushAndRemoveUntil to clear all previous routes
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false, // Remove all existing routes
                    );
                  }
                } catch (e) {
                  print('Error during sign out: $e');

                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to sign out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  /// Method to cancel any active streams or listeners
  Future<void> _cancelActiveListeners() async {
    try {
      // Cancel Firestore stream subscriptions
      _userDataSubscription?.cancel();
      _userItemsSubscription?.cancel();

      // Logout from Firebase Authentication
      await FirebaseAuth.instance.signOut();

      // Clear GetX controllers
      Get.deleteAll(force: true);

      // Optional: Close Firebase connections if needed
      // Note: Be cautious with this as it might affect other parts of your app
      // await FirebaseFirestore.instance.terminate();
      // await FirebaseFirestore.instance.clearPersistence();

      print('All listeners and connections closed successfully');
    } catch (e) {
      print('Error canceling listeners: $e');
    }
  }

  void _openMapScreen() async {
    final selectedLocation = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreenUpdateProfile(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        _latitude = selectedLocation['latitude'];
        _longitude = selectedLocation['longitude'];
        _addressController.text = selectedLocation['address'] ?? '';
        _locationController.text = 'Lat: $_latitude, Long: $_longitude';
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'latitude': _latitude,
          'longitude': _longitude,
          'address': _addressController.text,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfileChanges,
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    setState(() {
                      _isEditing = true;
                    });
                    break;
                  /*case 'swapSent':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SwapRequestSent(),
                      ),
                    );
                    break;*/

                  case 'signout':
                    _showSignOutDialog();
                    break;

                  case 'incoming donation requests':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const IncomingDonationRequestsScreen(),
                      ),
                    );
                    break;
                  case 'outgoing donation requests':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const OutgoingDonationRequestsScreen(),
                      ),
                    );
                    break;
                  /*case 'Swap History':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SwapHistoryScreen(),
                      ),
                    );
                    break;*/
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                /*const PopupMenuItem(
                  value: 'Swap History',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Swap History'),
                    ],
                  ),
                ),*/
                /*const PopupMenuItem(
                  value: 'swapSent',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Swap Request Sent'),
                    ],
                  ),
                ),*/
                const PopupMenuItem(
                  value: 'incoming donation requests',
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('incoming donation requests'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'outgoing donation requests',
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('outgoing donation requests'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _isEditing ? _pickProfileImage : null,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _newProfileImage != null
                                  ? FileImage(_newProfileImage!)
                                  : (_profileImageUrl != null
                                      ? NetworkImage(_profileImageUrl!)
                                      : null) as ImageProvider?,
                              child: _newProfileImage == null &&
                                      _profileImageUrl == null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 25, 73, 72),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      enabled: _isEditing,
                    ),

                    const SizedBox(height: 16),

                    // Location Field
                    GestureDetector(
                      onTap: _isEditing ? _openMapScreen : null,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _locationController,
                          label: 'Location',
                          enabled: _isEditing,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Address Field
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      enabled: _isEditing,
                    ),

                    const SizedBox(height: 16),

                    // Age Field
                    _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                    ),
// Add this after the form fields but before My Items section
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Change Password'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 16.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // My Items List
                    _buildItemsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      enabled: enabled,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        if (label == 'Age') {
          final age = int.tryParse(value);
          if (age == null || age <= 0) {
            return 'Please enter a valid age';
          }
        }
        return null;
      },
    );
  }

  Widget _buildItemsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyItemsScreen(
                    items: _userItems,
                    onItemsChanged: () {
                      _fetchUserItems();
                    },
                  ),
                ),
              );
              _fetchUserItems();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_userItems.isNotEmpty &&
                    _userItems[0].imageUrl != null &&
                    _userItems[0].imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _userItems[0].imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.inventory);
                      },
                    ),
                  )
                else
                  const Icon(Icons.inventory),
                const SizedBox(width: 8),
                Text('My Items (${_userItems.length})'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SwapHistoryScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.history, color: Colors.white),
                ),
                SizedBox(width: 8),
                Text('Swap History'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
