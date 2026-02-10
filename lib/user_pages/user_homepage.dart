import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../methods/common_methods.dart';
import 'order_placement.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _currentLatLng;
  double _zoomLevel = 15;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final CommonMethods cMethods = CommonMethods();

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });
    await saveLocation(position.latitude, position.longitude);
  }

  Future<void> saveLocation(double lat, double lng) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      String addressText =
          "${placemarks.first.street}, ${placemarks.first.locality}";
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location': {'lat': lat, 'lng': lng},
        'address': addressText,
      });
    }
  }

  Future<void> _searchLocation() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    List<Location> locations = await locationFromAddress(query);
    if (locations.isNotEmpty) {
      final latLng =
          LatLng(locations.first.latitude, locations.first.longitude);
      setState(() {
        _currentLatLng = latLng;
        _mapController.move(latLng, _zoomLevel);
      });
      await saveLocation(latLng.latitude, latLng.longitude);
    }
  }

  void _goToMyLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    LatLng latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLatLng = latLng;
      _mapController.move(latLng, _zoomLevel);
    });
    await saveLocation(latLng.latitude, latLng.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLatLng!,
                    initialZoom: _zoomLevel,
                    onTap: (tapPosition, point) async {
                      setState(() {
                        _currentLatLng = point;
                      });
                      await saveLocation(point.latitude, point.longitude);
                    },
                    onMapEvent: (event) {
                      setState(() {
                        _zoomLevel = _mapController.camera.zoom;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLatLng!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.person_pin_circle,
                              color: Color.fromARGB(255, 15, 15, 41), size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 70,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (value) => _searchLocation(),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: "searchBtn",
                    backgroundColor: Colors.white,
                    onPressed: _searchLocation,
                    child: const Icon(Icons.search, color: Colors.black),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 15, 15, 41),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderPlacementPage()),
                      );
                    },
                    child: const Text(
                      "Place New Order",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomIn",
                        backgroundColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _zoomLevel += 1;
                            _mapController.move(
                                _mapController.camera.center, _zoomLevel);
                          });
                        },
                        child: const Icon(Icons.zoom_in, color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomOut",
                        backgroundColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _zoomLevel -= 1;
                            _mapController.move(
                                _mapController.camera.center, _zoomLevel);
                          });
                        },
                        child: const Icon(Icons.zoom_out, color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        mini: true,
                        heroTag: "myLocation",
                        backgroundColor: Colors.white,
                        onPressed: _goToMyLocation,
                        child:
                            const Icon(Icons.my_location, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
