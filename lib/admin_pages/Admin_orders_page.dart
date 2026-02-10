import 'package:flutter/material.dart';
import 'package:gas_on_go/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Admin_OrdersPage extends StatefulWidget {
  const Admin_OrdersPage({super.key});

  @override
  _AdminOrdersPageState createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<Admin_OrdersPage> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    final fetchedOrders = await getOrderDetails();
    setState(() {
      orders = fetchedOrders;
      isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> getOrderDetails() async {
    final ordersSnapshot =
        await FirebaseFirestore.instance.collection('orders').get();

    List<Map<String, dynamic>> ordersList = [];

    for (var orderDoc in ordersSnapshot.docs) {
      final orderData = orderDoc.data();
      final orderId = orderDoc.id;
      final customerId = orderData['userId'];
      final timestamp = orderData['timestamp'];
      final driverId = orderData['driverId'];

      String customerName = 'Unknown';
      String driverName = 'Unknown';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('name')) {
        customerName = userDoc['name'];
      }

      if (driverId != null && driverId is String) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();
        if (driverDoc.exists && driverDoc.data()!.containsKey('name')) {
          driverName = driverDoc['name'];
        }
      }

      String formattedDateTime = 'Unknown';
      if (timestamp != null && timestamp is Timestamp) {
        final dtUtc = timestamp.toDate().toUtc();
        final dtJordan = dtUtc.add(Duration(hours: 3));
        formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(dtJordan);
      }

      final status = orderData['status'] ?? 'Unknown';
      final hasCancelledAt = orderData.containsKey('cancelledAt');

      String normalizedStatus;
      if (status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'delivered') {
        normalizedStatus = 'Done';
      } else if (status.toLowerCase() == 'pending') {
        normalizedStatus = 'Processing';
      } else if (status.toLowerCase() == 'cancelled' || hasCancelledAt) {
        normalizedStatus = 'Cancelled';
      } else {
        normalizedStatus = 'Unknown';
      }

      ordersList.add({
        'orderId': orderId,
        'customerName': customerName,
        'driverName': driverName,
        'dateTime': formattedDateTime,
        'status': status,
        'normalizedStatus': normalizedStatus,
      });
    }

    return ordersList;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Done':
        return Colors.green;
      case 'Processing':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusIndicator(String status) {
    Color color = _getStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: const Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 10),
            Text('Orders', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
                ? const Center(
                    child: Text(
                      'No orders for today',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            var order = orders[index];
                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.receipt_long,
                                          color: Colors.deepPurple, size: 30),
                                      title: Text(
                                        'Order #${order['orderId']}',
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 5),
                                          Text(
                                            'Customer: ${order['customerName']}',
                                            style: const TextStyle(
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'Driver: ${order['driverName']}',
                                            style: const TextStyle(
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Date & Time: ${order['dateTime']}',
                                            style: const TextStyle(
                                                color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.black),
                                        onPressed: () {
                                          _showEditDialog(context, index);
                                        },
                                      ),
                                    ),
                                    _buildStatusIndicator(
                                        order['normalizedStatus']),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index) {
    TextEditingController statusController =
        TextEditingController(text: orders[index]['status']);

    String? selectedStatus = ['In Progress', 'Delivered', 'Cancelled']
            .contains(statusController.text)
        ? statusController.text
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order #${orders[index]['orderId']}'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                onChanged: (newStatus) {
                  selectedStatus = newStatus!;
                },
                items: ['In Progress', 'Delivered', 'Cancelled']
                    .map<DropdownMenuItem<String>>((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                decoration: const InputDecoration(labelText: 'Update Status'),
                hint: const Text('Select status'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStatus != null) {
                  String orderId = orders[index]['orderId'];

                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'status': selectedStatus});

                  String normalizedStatus;
                  if (selectedStatus!.toLowerCase() == 'completed' ||
                      selectedStatus!.toLowerCase() == 'delivered') {
                    normalizedStatus = 'Done';
                  } else if (selectedStatus!.toLowerCase() == 'pending' ||
                      selectedStatus!.toLowerCase() == 'in progress') {
                    normalizedStatus = 'Processing';
                  } else {
                    normalizedStatus = 'Cancelled';
                  }

                  setState(() {
                    orders[index] = {
                      ...orders[index],
                      'status': selectedStatus,
                      'normalizedStatus': normalizedStatus,
                    };
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Order #$orderId status updated to "$selectedStatus"!'),
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }
}
