import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gas_on_go/theme/app_theme.dart';

class SellerApprovalPage extends StatefulWidget {
  const SellerApprovalPage({super.key});

  @override
  _SellerApprovalPageState createState() => _SellerApprovalPageState();
}

class _SellerApprovalPageState extends State<SellerApprovalPage> {
  List<Map<String, dynamic>> pendingSellers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingSellers();
  }

  Future<void> fetchPendingSellers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sellers_data')
        .where('status', isEqualTo: 'pending')
        .get();

    final sellersList = snapshot.docs.map((doc) {
      var data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();

    setState(() {
      pendingSellers = sellersList;
      isLoading = false;
    });
  }

  Future<void> approveSeller(String docId) async {
    await FirebaseFirestore.instance
        .collection('sellers_data')
        .doc(docId)
        .update({'status': 'approved'});

    setState(() {
      pendingSellers.removeWhere((seller) => seller['docId'] == docId);
    });
  }

  Future<void> rejectSeller(String docId) async {
    await FirebaseFirestore.instance
        .collection('sellers_data')
        .doc(docId)
        .update({'status': 'rejected'});

    setState(() {
      pendingSellers.removeWhere((seller) => seller['docId'] == docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Seller Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 2,
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : pendingSellers.isEmpty
                ? const Center(
                    child: Text(
                      'No pending sellers',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Approvals (${pendingSellers.length})',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          itemCount: pendingSellers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final seller = pendingSellers[index];
                            return SellerCard(
                              name: seller['name'] ?? '',
                              email: seller['email'] ?? '',
                              onApprove: () => approveSeller(seller['docId']),
                              onReject: () => rejectSeller(seller['docId']),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class SellerCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const SellerCard({
    Key? key,
    required this.name,
    required this.email,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 18),
              const SizedBox(width: 6),
              Text(email, style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel_outlined,
                      color: AppTheme.primaryColor),
                  label: const Text(
                    'Reject',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
