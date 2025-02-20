import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
 const MapScreen({Key? key}) : super(key: key);

 @override
 State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
 LatLng _selectedLocation = LatLng(31.0461, 34.8516); // Default to Israel
 final MapController _mapController = MapController();
 bool _isLoading = false;

 Future<void> _getCurrentLocation() async {
   if (!mounted) return;

   setState(() {
     _isLoading = true;
   });

   try {
     // Check and request location permissions
     LocationPermission permission = await Geolocator.checkPermission();
     if (permission == LocationPermission.denied) {
       permission = await Geolocator.requestPermission();
       if (permission == LocationPermission.denied) {
         if (!mounted) return;
         setState(() {
           _isLoading = false;
         });
         return;
       }
     }

     // Get current position
     Position position = await Geolocator.getCurrentPosition(
       desiredAccuracy: LocationAccuracy.high,
     );

     // Update selected location and map view only if widget is still mounted
     if (!mounted) return;
     setState(() {
       _selectedLocation = LatLng(position.latitude, position.longitude);
       _isLoading = false;
     });

     // Move map to new location
     _mapController.move(_selectedLocation, 15.0);
   } catch (e) {
     if (!mounted) return;
     setState(() {
       _isLoading = false;
     });

     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Failed to get location: $e')),
     );
   }
 }

 void _onMapTapped(LatLng location) {
   if (!mounted) return;
   setState(() {
     _selectedLocation = location;
   });
 }

 void _returnLocation() {
   Navigator.pop(context, {
     'latitude': _selectedLocation.latitude,
     'longitude': _selectedLocation.longitude,
   });
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Text('Select Location'),
       actions: [
         IconButton(
           icon: const Icon(Icons.check),
           onPressed: _isLoading 
             ? null 
             : _returnLocation,
         ),
       ],
     ),
     body: Stack(
       children: [
         FlutterMap(
           mapController: _mapController,
           options: MapOptions(
             initialCenter: _selectedLocation,
             initialZoom: 7.5,
             onTap: (_, point) => _onMapTapped(point),
           ),
           children: [
             TileLayer(
               urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
               subdomains: const ['a', 'b', 'c'],
             ),
             MarkerLayer(
               markers: [
                 Marker(
                   point: _selectedLocation,
                   width: 80.0,
                   height: 80.0,
                   child: const Icon(
                     Icons.location_on,
                     color: Colors.red,
                     size: 50.0,
                   ),
                 ),
               ],
             ),
           ],
         ),
         Positioned(
           bottom: 16,
           right: 16,
           child: FloatingActionButton(
             onPressed: _isLoading 
               ? null 
               : () async {
                   await _getCurrentLocation();
                 },
             backgroundColor: const Color.fromARGB(255, 25, 73, 72),
             child: _isLoading 
               ? const CircularProgressIndicator(color: Colors.white)
               : const Icon(Icons.my_location, color: Colors.white),
           ),
         ),
       ],
     ),
   );
 }

 @override
 void dispose() {
   _mapController.dispose();
   super.dispose();
 }
}