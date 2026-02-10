/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_ratings_page.dart';

class HomeSellerPage extends StatefulWidget {
  const HomeSellerPage({super.key});

  @override
  State<HomeSellerPage> createState() => _HomeSellerPageState();
}

class _HomeSellerPageState extends State<HomeSellerPage> {
  LatLng? driverLocation;
  LatLng? destination;
  List<LatLng> _route = [];
  final mapController = MapController();
  String? orderId;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _getDriverLocation();
    _listenToAcceptedOrder();
  }

  Future<void> _getDriverLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      driverLocation = LatLng(pos.latitude, pos.longitude);
    });

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) {
      setState(() {
        driverLocation = LatLng(position.latitude, position.longitude);
      });

      if (orderId != null) {
        FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'driverLocation': {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
        if (destination != null) _fetchRoute();
      }
    });
  }

  void _listenToAcceptedOrder() {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return;

    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          orderId = doc.id;
          destination =
              LatLng(data['destination']['lat'], data['destination']['lng']);
        });

        _fetchRoute();
        _listenToOrderCancellation();
      } else {
        setState(() {
          orderId = null;
          destination = null;
          _route = [];
        });
      }
    });
  }

  void _goToMyLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();

    setState(() {
      driverLocation = LatLng(pos.latitude, pos.longitude);
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  void _listenToOrderCancellation() {
    if (orderId == null) return;
    FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data()?['status'] == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ The user has cancelled the order.")),
        );
        setState(() {
          orderId = null;
          destination = null;
          _route = [];
        });
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (driverLocation == null || destination == null) return;

    print(
        "Fetching route from: ${driverLocation!.latitude},${driverLocation!.longitude} to ${destination!.latitude},${destination!.longitude}");

    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/'
        '${driverLocation!.longitude},${driverLocation!.latitude};'
        '${destination!.longitude},${destination!.latitude}?overview=full&geometries=polyline');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      print("Geometry: $geometry");

      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decoded = polylinePoints.decodePolyline(geometry);

      print("Decoded points: ${decoded.length}");

      setState(() {
        _route = decoded.map((e) => LatLng(e.latitude, e.longitude)).toList();
      });
    } else {
      print("Failed to fetch route: ${response.statusCode}");
    }
  }

  Future<void> sendCancellationNotificationToUser(
      String userId, String orderId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('user_notifications')
        .add({
      'title': 'Order Cancelled ❌',
      'body': 'The driver cancelled your order #$orderId.',
      'orderId': orderId,
      'timestamp': Timestamp.now(),
      'read': false,
    });
  }

  Future<void> _cancelOrderByDriver() async {
    if (orderId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Order"),
        content: const Text("Are you sure you want to cancel this order?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    final orderDoc =
        FirebaseFirestore.instance.collection('orders').doc(orderId);
    final orderSnapshot = await orderDoc.get();

    if (orderSnapshot.exists) {
      final data = orderSnapshot.data()!;
      final userId = data['userId'];

      await orderDoc.update({
        'status': 'cancelled_by_driver',
        'cancelledAt': Timestamp.now(),
      });

      await sendCancellationNotificationToUser(userId, orderId!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order has been cancelled.")),
      );

      setState(() {
        orderId = null;
        destination = null;
        _route = [];
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom += 1;
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom -= 1;
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Seller Map",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 15, 15, 41),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.star,
              color: Colors.yellow,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SellerRatingsPage(),
                ),
              );
            },
          ),
          if (orderId != null)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: _cancelOrderByDriver,
            ),
        ],
      ),
      body: driverLocation == null
          ? const Center(child: Text("🚚 Waiting for Seller location..."))
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: driverLocation!,
                    initialZoom: _currentZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    if (_route.isNotEmpty &&
                        driverLocation != null &&
                        destination != null)
                      PolylineLayer(
                        polylines: [
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
                              color: Color.fromARGB(255, 15, 15, 41), size: 40),
                        ),
                        if (destination != null)
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
                Positioned(
                  right: 10,
                  bottom: 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomIn",
                        backgroundColor: Colors.white,
                        onPressed: _zoomIn,
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomOut",
                        backgroundColor: Colors.white,
                        onPressed: _zoomOut,
                        child: const Icon(
                          Icons.zoom_out,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
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
}*/
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_ratings_page.dart';

class HomeSellerPage extends StatefulWidget {
  const HomeSellerPage({super.key});

  @override
  State<HomeSellerPage> createState() => _HomeSellerPageState();
}

class _HomeSellerPageState extends State<HomeSellerPage> {
  LatLng? driverLocation;
  LatLng? destination;
  List<LatLng> _route = [];
  final mapController = MapController();
  String? orderId;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _getDriverLocation();
    _listenToAcceptedOrder();
  }

  Future<void> _getDriverLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      driverLocation = LatLng(pos.latitude, pos.longitude);
    });

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      setState(() {
        driverLocation = LatLng(position.latitude, position.longitude);
      });

      if (orderId != null) {
        FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'driverLocation': {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
        if (destination != null) _fetchRoute();
      }
    });
  }

  void _listenToAcceptedOrder() {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return;

    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          orderId = doc.id;
          destination =
              LatLng(data['destination']['lat'], data['destination']['lng']);
        });

        _fetchRoute();
        _listenToOrderCancellation();
      } else {
        setState(() {
          orderId = null;
          destination = null;
          _route = [];
        });
      }
    });
  }

  void _listenToOrderCancellation() {
    if (orderId == null) return;
    FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data()?['status'] == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ The user has cancelled the order.")),
        );
        setState(() {
          orderId = null;
          destination = null;
          _route = [];
        });
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (driverLocation == null || destination == null) return;

    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/'
        '${driverLocation!.longitude},${driverLocation!.latitude};'
        '${destination!.longitude},${destination!.latitude}?overview=full&geometries=geojson');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;

        setState(() {
          _route = coordinates
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();
        });
      } else {
        print("No routes found.");
      }
    } else {
      print("Failed to fetch route: ${response.statusCode}");
    }
  }

  Future<void> _cancelOrderByDriver() async {
    if (orderId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Order"),
        content: const Text("Are you sure you want to cancel this order?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    final orderDoc =
        FirebaseFirestore.instance.collection('orders').doc(orderId);
    final orderSnapshot = await orderDoc.get();

    if (orderSnapshot.exists) {
      final data = orderSnapshot.data()!;
      final userId = data['userId'];

      await orderDoc.update({
        'status': 'cancelled_by_driver',
        'cancelledAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .add({
        'title': 'Order Cancelled ❌',
        'body': 'The driver cancelled your order #$orderId.',
        'orderId': orderId,
        'timestamp': Timestamp.now(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order has been cancelled.")),
      );

      setState(() {
        orderId = null;
        destination = null;
        _route = [];
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom += 1;
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom -= 1;
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  void _goToMyLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      driverLocation = LatLng(pos.latitude, pos.longitude);
      mapController.move(driverLocation!, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Seller Map",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 15, 15, 41),
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.yellow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SellerRatingsPage(),
                ),
              );
            },
          ),
          if (orderId != null)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: _cancelOrderByDriver,
            ),
        ],
      ),
      body: driverLocation == null
          ? const Center(child: Text("🚚 Waiting for Seller location..."))
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: driverLocation!,
                    initialZoom: _currentZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    if (_route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 4.0,
                            color: Colors.red,
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
                              color: Color.fromARGB(255, 15, 15, 41), size: 40),
                        ),
                        if (destination != null)
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
                Positioned(
                  right: 10,
                  bottom: 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomIn",
                        backgroundColor: Colors.white,
                        onPressed: _zoomIn,
                        child: const Icon(Icons.zoom_in, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: "zoomOut",
                        backgroundColor: Colors.white,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.zoom_out, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
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
