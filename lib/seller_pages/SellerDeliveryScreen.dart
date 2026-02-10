/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class OpenstreetmapScreen extends StatefulWidget {
  const OpenstreetmapScreen({super.key});

  @override
  State<OpenstreetmapScreen> createState() => _OpenstreetmapScreenState();
}

class _OpenstreetmapScreenState extends State<OpenstreetmapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final TextEditingController _locationController = TextEditingController();

  bool isLoading = true;
  double _zoomLevel = 13.0;
  LatLng? _destination;
  LatLng? _currentLocation;
  List<LatLng> _route = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _mapController.mapEventStream.listen((event) {
      setState(() {
        _zoomLevel = _mapController.camera.zoom;
      });
    });
  }

  Future<void> _initializeLocation() async {
    if (!await _checktheRequestPermission()) return;

    _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
          isLoading = false;
        });
      }
    });
  }

  Future<void> fetchCoordinatesPoints(String location) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1');
    final response = await http.get(
      url,
      headers: {'User-Agent': 'flutter-map-app/1.0'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        setState(() {
          _destination = LatLng(lat, lon);
        });
        await fetchRoute();
      } else {
        errorMessage('Location not found. Please try another search.');
      }
    } else {
      errorMessage('Failed to fetch location. Try again later.');
    }
  }

  Future<void> fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;

    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/'
      '${_currentLocation!.longitude},${_currentLocation!.latitude};'
      '${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=polyline',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'flutter-map-app/1.0'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final geometry = data['routes'][0]['geometry'];
        _decodePolyline(geometry);
      } else {
        errorMessage('No route found.');
      }
    } else {
      errorMessage('Failed to fetch route. Try again later.');
    }
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    setState(() {
      _route = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    });
  }

  Future<bool> _checktheRequestPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }
    return true;
  }

  Future<void> _userCurentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _zoomLevel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
    }
  }

  void errorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        /* appBar: AppBar(
          foregroundColor: Colors.white,
          title: const Center(child: Text('Open Street Map')),
          backgroundColor: const Color(0xFF002B49),
        ),*/
        body: Stack(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation ?? const LatLng(0, 0),
                      initialZoom: _zoomLevel,
                      minZoom: 2,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      CurrentLocationLayer(
                        style: const LocationMarkerStyle(
                          marker: DefaultLocationMarker(
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.white,
                            ),
                          ),
                          markerSize: Size(35, 35),
                          markerDirection: MarkerDirection.heading,
                        ),
                      ),
                      if (_destination != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _destination!,
                              width: 50,
                              height: 50,
                              child: const Icon(
                                Icons.location_pin,
                                size: 40,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      if (_currentLocation != null &&
                          _destination != null &&
                          _route.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _route,
                              strokeWidth: 5,
                              color: Colors.red,
                            ),
                          ],
                        ),
                    ],
                  ),
            Positioned(
              top: 15,
              right: 0,
              left: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Enter a location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final location = _locationController.text.trim();
                        if (location.isNotEmpty) {
                          fetchCoordinatesPoints(location);
                        }
                      },
                      icon: const Icon(Icons.search),
                    ),
                  ],
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
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          elevation: 0,
          onPressed: _userCurentLocation,
          backgroundColor: const Color(0xFF002B49),
          child: const Icon(
            Icons.my_location,
            size: 30,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}*/

import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class SellerDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const SellerDeliveryScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  @override
  State<SellerDeliveryScreen> createState() => _SellerDeliveryScreenState();
}

class _SellerDeliveryScreenState extends State<SellerDeliveryScreen> {
  LatLng? driverLocation;
  LatLng? destination;
  List<LatLng> _route = [];
  final MapController _mapController = MapController();
  final Distance _distance = Distance();
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    fetchDestinationAndStartTracking();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> fetchDestinationAndStartTracking() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      if (data['destination'] != null) {
        setState(() {
          destination = LatLng(
            data['destination']['lat'],
            data['destination']['lng'],
          );
        });
      }
    }

    startTrackingDriverLocation();
  }

  void startTrackingDriverLocation() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 10),
    ).listen((Position position) async {
      driverLocation = LatLng(position.latitude, position.longitude);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'driverLocation': {
          'lat': driverLocation!.latitude,
          'lng': driverLocation!.longitude,
        }
      });

      if (destination != null) {
        final double meters = _distance(driverLocation!, destination!);
        if (meters < 50) {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .get();

          final orderData = docSnapshot.data();
          final userId = orderData?['userId'];

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .update({'status': 'completed'});

          if (userId != null && userId.toString().isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('notifications')
                .doc(userId)
                .collection('user_notifications')
                .add({
              'title': 'Order Delivered ✅',
              'body': 'Your gas cylinder has been successfully delivered.',
              'orderId': widget.orderId,
              'timestamp': Timestamp.now(),
              'read': false,
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delivery Completed!')),
            );
          }

          positionStream?.cancel();
        }
        await fetchRoute();
      }

      setState(() {});
    });
  }

  Future<void> fetchRoute() async {
    if (driverLocation == null || destination == null) return;

    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/'
        '${driverLocation!.longitude},${driverLocation!.latitude};'
        '${destination!.longitude},${destination!.latitude}?overview=full&geometries=polyline');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(geometry);
      setState(() {
        _route =
            decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Order not found")),
          );
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>;
        final status = orderData['status'];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Delivering Order',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color.fromARGB(255, 15, 15, 41),
            centerTitle: true,
          ),
          body: Column(
            children: [
              if (driverLocation != null && destination != null)
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: driverLocation!,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_route.isNotEmpty)
                            Polyline(
                              points: _route,
                              strokeWidth: 4.0,
                              color: Color.fromARGB(255, 15, 15, 41),
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: driverLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.local_shipping,
                                color: Color.fromARGB(255, 15, 15, 41),
                                size: 40),
                          ),
                          Marker(
                            point: destination!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (status == 'completed')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Order Completed ✅",
                      style: TextStyle(fontSize: 16, color: Colors.green)),
                )
            ],
          ),
        );
      },
    );
  }
}
