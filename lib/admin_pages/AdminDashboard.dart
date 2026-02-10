import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gas_on_go/theme/app_theme.dart';
import 'package:gas_on_go/admin_pages/Admin_orders_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:gas_on_go/admin_pages/Admin_settings.dart';
import 'package:gas_on_go/admin_pages/admin_sellers_approval.dart';
import 'package:gas_on_go/admin_pages/admin_user_managment.dart';

Future<QuerySnapshot> getTodayRange() {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfTomorrow = startOfToday.add(Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('orders')
      .where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
      .where('timestamp', isLessThan: Timestamp.fromDate(startOfTomorrow))
      .get();
}

/* Today Orders Count */

Future<int> countTodayOrders() async {
  final snapshotCount = await getTodayRange();
  return snapshotCount.docs.length;
  //return the length not the documents.
}

/*  Today Orders Document  */
Future<Map<String, int>> getTodayOrderStatusCounts() async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay =
      startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .get();

    int processing = 0;
    int done = 0;
    int cancelled = 0;

    for (var doc in snapshot.docs) {
      final status = doc['status']?.toString().toLowerCase();

      if (status == 'processing') {
        processing++;
      } else if (status == 'done') {
        done++;
      } else if (status == 'cancelled') {
        cancelled++;
      }
    }

    return {
      'Processing': processing,
      'Done': done,
      'Cancelled': cancelled,
    };
  } catch (e) {
    print('Error fetching today\'s order statuses: $e');

    return {
      'Processing': 0,
      'Done': 0,
      'Cancelled': 0,
    };
  }
}

Future<Map<String, int>> getThisWeekOrderStatusCounts() async {
  final now = DateTime.now();

  final int daysSinceSunday = now.weekday % 7;
  final startOfWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysSinceSunday));
  final endOfWeek = startOfWeek.add(Duration(days: 7));

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfWeek))
        .get();

    int processing = 0;
    int done = 0;
    int cancelled = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status']?.toString().toLowerCase();
      final hasCancelledAt = data.containsKey('cancelledAt');

      print(
          'Order ID: ${doc.id}, status: $status, cancelledAt: ${hasCancelledAt ? data['cancelledAt'] : 'none'}');

      if (status == 'processing' || status == 'In Progress') {
        processing++;
      } else if (status == 'completed' ||
          status == 'delivered' ||
          status == 'done') {
        done++;
      }

      if (status == 'cancelled' || hasCancelledAt) {
        cancelled++;
      }
    }

    return {
      'Processing': processing,
      'Done': done,
      'Cancelled': cancelled,
    };
  } catch (e) {
    print('Error fetching weekly order statuses: $e');
    return {
      'Processing': 0,
      'Done': 0,
      'Cancelled': 0,
    };
  }
}

/*  This Week Count Docs  */

Future<List<int>> fetchOrdersPerDay() async {
  final now = DateTime.now();

  // Start of the week (Sunday)
  final startOfWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday % 7));

  // End of the week (exclusive)
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  final snapshot = await FirebaseFirestore.instance
      .collection('orders')
      .where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
      .where('timestamp', isLessThan: Timestamp.fromDate(endOfWeek))
      .get();

  // Sunday (0) to Saturday (6)
  List<int> ordersPerDay = List.filled(7, 0);

  for (var doc in snapshot.docs) {
    final ts = doc['timestamp'];
    if (ts is Timestamp) {
      DateTime date = ts.toDate();
      int index = date.weekday % 7;
      ordersPerDay[index]++;
    }
  }

  return ordersPerDay;
}

Future<List<Map<String, dynamic>>> fetchTopSellersWhoSoldThisWeek(
    {int limit = 10}) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday % 7));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  final sellersSnapshot = await firestore
      .collection('users')
      .where('role', isEqualTo: 'seller')
      .get();

  List<Map<String, dynamic>> results = [];

  for (var sellerDoc in sellersSnapshot.docs) {
    final sellerId = sellerDoc.id;
    final sellerData = sellerDoc.data();
    final sellerName = sellerData['name'] ?? 'Unknown';

    final allOrdersSnapshot = await firestore
        .collection('orders')
        .where('driverId', isEqualTo: sellerId)
        .get();

    final ordersThisWeek = allOrdersSnapshot.docs.where((doc) {
      final ts = doc['timestamp'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return dt.isAfter(startOfWeek) && dt.isBefore(endOfWeek);
      }
      return false;
    }).toList();

    if (ordersThisWeek.isEmpty) {
      continue;
    }

    num totalQuantity = 0;
    for (var doc in allOrdersSnapshot.docs) {
      final quantity = doc['quantity'];
      if (quantity is num) {
        totalQuantity += quantity;
      }
    }

    results.add({
      'name': sellerName,
      'orders': allOrdersSnapshot.docs.length,
      'earnings': (totalQuantity * 7).round(),
    });
  }

  results
      .sort((a, b) => (b['earnings'] as int).compareTo(a['earnings'] as int));

  return results.take(limit).toList();
}

/*    End Of FireStore Code    */

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            setState(() {
              _isMenuOpen = !_isMenuOpen;
            });
          },
        ),
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 10),
            Text('Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                )),
          ],
        ),
      ),
      body: Row(
        children: [
          if (_isMenuOpen)
            Container(
              width: 200,
              color: Colors.black12,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  ListTile(
                    leading: Icon(Icons.dashboard, color: Colors.white),
                    title: Text('Dashboard',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminDashboard()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.people, color: Colors.white),
                    title: Text('User Management',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => UserManagementPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.approval, color: Colors.white),
                    title: Text('Seller Approval',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SellerApprovalPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_cart, color: Colors.white),
                    title:
                        Text('Orders', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Admin_OrdersPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings, color: Colors.white),
                    title:
                        Text('Settings', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 370,
                            child: PageView(
                              children: [
                                // Page 1: Pie Chart

                                FutureBuilder<Map<String, int>>(
                                  future: getThisWeekOrderStatusCounts(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }

                                    if (snapshot.hasError) {
                                      return Center(
                                          child:
                                              Text('Error: ${snapshot.error}'));
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Center(
                                          child: Text('No data available'));
                                    }

                                    final counts = snapshot.data!;
                                    print('Counts for this week: $counts');

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "This Week's Orders",
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 20),
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: SizedBox(
                                              height: 200,
                                              width: 200,
                                              child: PieChart(
                                                PieChartData(
                                                  sectionsSpace: 3,
                                                  centerSpaceRadius: 40,
                                                  sections: [
                                                    PieChartSectionData(
                                                      color: Colors.green,
                                                      value: counts[
                                                                  'Processing']
                                                              ?.toDouble() ??
                                                          0,
                                                      title: '',
                                                    ),
                                                    PieChartSectionData(
                                                      color: Colors.orange,
                                                      value: counts['Done']
                                                              ?.toDouble() ??
                                                          0,
                                                      title: '',
                                                    ),
                                                    PieChartSectionData(
                                                      color: Colors.red,
                                                      value: counts['Cancelled']
                                                              ?.toDouble() ??
                                                          0,
                                                      title: '',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: const [
                                              LegendItem(
                                                  color: Colors.green,
                                                  label: 'Processing'),
                                              SizedBox(height: 8),
                                              LegendItem(
                                                  color: Colors.orange,
                                                  label: 'Done'),
                                              SizedBox(height: 8),
                                              LegendItem(
                                                  color: Colors.red,
                                                  label: 'Cancelled'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // Page 2: Bar Chart
                                FutureBuilder<List<int>>(
                                  future: fetchOrdersPerDay(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }

                                    final data = snapshot.data!;

                                    final maxYValue =
                                        (data.reduce((a, b) => a > b ? a : b) +
                                                3)
                                            .toDouble();
                                    final maxY =
                                        maxYValue < 15 ? 15.0 : maxYValue;

                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Orders (This week)',
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14),
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            height: 300,
                                            child: BarChart(
                                              BarChartData(
                                                maxY: (data.reduce((a, b) =>
                                                            a > b ? a : b) +
                                                        1)
                                                    .toDouble(),
                                                minY: 0,
                                                barTouchData: BarTouchData(
                                                    enabled: false),
                                                gridData:
                                                    FlGridData(show: false),
                                                titlesData: FlTitlesData(
                                                  leftTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      interval: 3,
                                                      reservedSize: 30,
                                                      getTitlesWidget:
                                                          (value, _) => Text(
                                                        value
                                                            .toInt()
                                                            .toString(),
                                                        style: const TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                  ),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      interval: 1,
                                                      getTitlesWidget:
                                                          (value, _) => Text(
                                                        'D${value.toInt() + 1}',
                                                        style: const TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                    ),
                                                  ),
                                                  topTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                          showTitles: false)),
                                                  rightTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                          showTitles: false)),
                                                ),
                                                barGroups: List.generate(
                                                  7,
                                                  (i) => BarChartGroupData(
                                                    x: i,
                                                    barRods: [
                                                      BarChartRodData(
                                                        toY: data[i].toDouble(),
                                                        color: Colors.blue,
                                                        width: 25, //*****
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: 8),
                                  Text('Today Orders',
                                      style: TextStyle(fontSize: 18)),
                                  SizedBox(height: 6),
                                  FutureBuilder<int>(
                                    /*    FireStore Code    */
                                    future: countTodayOrders(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return CircularProgressIndicator();
                                      } else if (snapshot.hasError) {
                                        print(
                                            'Error occurred: ${snapshot.error}');
                                        return Text(
                                          'Error: ${snapshot.error}',
                                          style: TextStyle(
                                              fontSize: 14, color: Colors.red),
                                        );
                                      } else {
                                        return Text(
                                          '${snapshot.data}',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: 8),
                                  Text('Today Total Revenue',
                                      style: TextStyle(fontSize: 18)),
                                  SizedBox(height: 6),
                                  FutureBuilder<int>(
                                    future: countTodayOrders(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Text(
                                          'No Orders',
                                          style: TextStyle(fontSize: 17),
                                        );
                                      } else {
                                        final count = snapshot.data ?? 0;
                                        final result = count * 7;
                                        return Text(
                                          '$result',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                        );
                                      }
                                    },
                                  )
                                ],
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Top Sellers (this week)',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: fetchTopSellersWhoSoldThisWeek(limit: 10),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return const Text('Failed to load sellers.',
                                  style: TextStyle(color: Colors.white));
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return const Text('No sellers found.',
                                  style: TextStyle(color: Colors.white));
                            }

                            final sellers = snapshot.data!;

                            return Column(
                              children: sellers.map((seller) {
                                final name = seller['name'];
                                final orders = seller['orders'];
                                final earnings = seller['earnings'];

                                return ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.person)),
                                  title: Text(name,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  subtitle: Text(
                                    'Orders: $orders   |   Earnings: \$${earnings.toString()}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.black)),
      ],
    );
  }
}
