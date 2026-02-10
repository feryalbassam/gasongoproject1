import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gas_on_go/user_pages/user_dashboard.dart';
import 'package:gas_on_go/user_pages/order_tracking_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'Payment Page.dart';

class OrderPlacementPage extends StatefulWidget {
  const OrderPlacementPage({Key? key}) : super(key: key);

  @override
  State<OrderPlacementPage> createState() => _OrderPlacementPageState();
}

class _OrderPlacementPageState extends State<OrderPlacementPage> {
  int quantity = 1;
  double pricePerCylinder = 8.50;
  TextEditingController addressController = TextEditingController();
  String selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    loadUserAddress();
  }

  Future<void> loadUserAddress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data()?['address'] != null) {
        setState(() {
          addressController.text = doc['address'];
        });
      }
    }
  }

  Future<void> sendNotificationToUser(
      String userId, String orderId, String bodyMessage) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('user_notifications')
        .add({
      'title': 'Order #$orderId Update',
      'body': bodyMessage,
      'orderId': orderId,
      'timestamp': Timestamp.now(),
      'read': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalPrice = quantity * pricePerCylinder;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 15, 15, 41),
        title: const Text("Order a Cylinder",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Dashboard()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Quantity:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: const Color.fromARGB(255, 15, 15, 41),
                      blurRadius: 5,
                      spreadRadius: 2)
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        if (quantity > 1) quantity--;
                      });
                    },
                  ),
                  Text(quantity.toString(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.green),
                    onPressed: () {
                      setState(() {
                        quantity++;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Delivery Address:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Select from map",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.location_on,
                    color: Color.fromARGB(255, 15, 15, 41)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text("Total Price: ${totalPrice.toStringAsFixed(2)} JD",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (addressController.text.isNotEmpty) {
                  final trackingNumber =
                      "TRK${DateTime.now().millisecondsSinceEpoch}";
                  final user = FirebaseAuth.instance.currentUser;
                  final userId = user?.uid;

                  if (userId == null) return;

                  final userDocRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId);

                  final refreshedUserDoc = await userDocRef.get();

                  final userLocation = refreshedUserDoc['location'];
                  final customerName = refreshedUserDoc['name'] ?? 'Unnamed';

                  final orderData = {
                    'userId': userId,
                    'customerName': customerName,
                    'quantity': quantity,
                    'address': addressController.text,
                    'totalPrice': totalPrice,
                    'status': 'pending',
                    'paymentMethod': '',
                    'trackingNumber': trackingNumber,
                    'timestamp': FieldValue.serverTimestamp(),
                    'destination': {
                      'lat': userLocation['lat'],
                      'lng': userLocation['lng'],
                    },
                    'tracking': [
                      {
                        'status': 'Order Placed',
                        'date': DateTime.now().toString(),
                        'description':
                            'Your order has been confirmed and is being processed.',
                        'isCompleted': true,
                      },
                      {
                        'status': 'Shipping',
                        'date': '',
                        'description':
                            'Your order is being prepared for shipping.',
                        'isCompleted': false,
                      },
                      {
                        'status': 'In Transit',
                        'date': '',
                        'description': 'Your order is on the way.',
                        'isCompleted': false,
                      },
                      {
                        'status': 'Out for Delivery',
                        'date': '',
                        'description': 'Your order will be delivered today.',
                        'isCompleted': false,
                      },
                      {
                        'status': 'Delivered',
                        'date': '',
                        'description': 'Your order has been delivered.',
                        'isCompleted': false,
                      },
                    ],
                  };

                  final docRef = await FirebaseFirestore.instance
                      .collection('orders')
                      .add(orderData);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentPage(orderId: docRef.id),
                    ),
                  );

                  if (result != null &&
                      result is Map &&
                      result['method'] != null) {
                    selectedPaymentMethod = result['method'];
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(docRef.id)
                        .update({'paymentMethod': selectedPaymentMethod});
                  }

                  final driversSnapshot = await FirebaseFirestore.instance
                      .collection('drivers')
                      .get();

                  double minDistance = double.infinity;
                  String? nearestDriverId;

                  for (var doc in driversSnapshot.docs) {
                    final driverData = doc.data();
                    if (driverData['location'] != null) {
                      final driverLat = driverData['location']['lat'];
                      final driverLng = driverData['location']['lng'];

                      final distance = Geolocator.distanceBetween(
                        userLocation['lat'],
                        userLocation['lng'],
                        driverLat,
                        driverLng,
                      );

                      if (distance < minDistance) {
                        minDistance = distance;
                        nearestDriverId = doc.id;
                      }
                    }
                  }

                  if (nearestDriverId != null) {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(docRef.id)
                        .update({
                      'driverId': nearestDriverId,
                      'status': 'assigned',
                    });
                  }

                  await sendNotificationToUser(userId, docRef.id,
                      'Your order is confirmed and being prepared 🚚');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OrderTrackingScreen(orderId: docRef.id),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a delivery address!",
                          style: TextStyle(color: Colors.white)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                backgroundColor: const Color.fromARGB(255, 15, 15, 41),
                elevation: 5,
              ),
              child: const Text("Confirm Order",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
