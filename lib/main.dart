import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_1/Screens/addItem.dart';
import 'package:flutter_application_1/Screens/login.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'package:image_picker/image_picker.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // First initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Then set Firestore settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// lib/models/item.dart

// In main.dart, update the Item class:

class Item {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? imageUrl;
  final String location;
  final String address;
  final String ownerId;
  final bool isAvailable;
  final bool isDonation;
  final DateTime? swappedAt;
  final String? swappedWith;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.imageUrl,
    required this.location,
    required this.address,
    required this.ownerId,
    this.isAvailable = true,
    this.isDonation = false,
    this.swappedAt,
    this.swappedWith,
  });

  factory Item.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      imageUrl: data['imageUrl'],
      location: data['location'] ?? '',
      address: data['address'] ?? '',
      ownerId: data['ownerId'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      isDonation: data['isDonation'] ?? false,
      swappedAt: data['swappedAt'] != null
          ? (data['swappedAt'] as Timestamp).toDate()
          : null,
      swappedWith: data['swappedWith'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'location': location,
      'address': address,
      'ownerId': ownerId,
      'isAvailable': isAvailable,
      'isDonation': isDonation,
      'swappedAt': swappedAt != null ? Timestamp.fromDate(swappedAt!) : null,
      'swappedWith': swappedWith,
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Swaply',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 25, 73, 72),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 25, 73, 72),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Removed Node.js code for Firebase Cloud Functions

Future<void> storeFcmToken() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'fcmToken': fcmToken,
    });
  }
}
