import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/homeScreen.dart';
import 'package:get/get.dart';
// import 'package:awesome_notifications/awesome_notifications.dart';

class SignUpController extends GetxController {
  final nameController = TextEditingController().obs;
  final emailController = TextEditingController().obs;
  final passwordController = TextEditingController().obs;
  final locationController =
      TextEditingController().obs; // To hold latitude & longitude
  final locationplaceController =
      TextEditingController().obs; // For human-readable address
  final ageController = TextEditingController().obs;
  final isPasswordVisible = false.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // _initializeAwesomeNotifications();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Handle sign-up logic
  Future<void> signUp() async {
    isLoading.value = true;
    try {
      // Perform Firebase registration
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.value.text,
              password: passwordController.value.text);

      // Parse latitude and longitude from the locationController text
      final latLngParts = locationController.value.text.split(',');
      final latitude = double.parse(latLngParts[0].split(':')[1].trim());
      final longitude = double.parse(latLngParts[1].split(':')[1].trim());

      // Add user to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'name': nameController.value.text,
        'email': emailController.value.text,
        'latitude': latitude, // Store latitude separately
        'longitude': longitude, // Store longitude separately
        'address': locationplaceController.value.text, // Human-readable address
        'age': int.parse(ageController.value.text),
      });

      // Navigate to the home screen
      Get.offAll(HomeScreen());
    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      Get.snackbar(
          'Error', e.message ?? 'An error occurred during registration');
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
    }
  }

  // Select location from MapScreen
  // Select location from MapScreen
  void selectLocation(Map<String, double> location) {
    final lat = location['latitude'];
    final long = location['longitude'];
    if (lat != null && long != null) {
      locationController.value.text =
          'Lat: $lat, Long: $long'; // Format as string
    }
  }
}
