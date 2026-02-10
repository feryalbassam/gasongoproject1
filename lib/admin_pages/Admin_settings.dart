import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gas_on_go/admin_pages/admin_sellers_approval.dart';
import 'package:gas_on_go/admin_pages/admin_user_managment.dart';
import 'package:gas_on_go/admin_pages/Admin_orders_page.dart';
import 'package:gas_on_go/admin_pages/AdminDashboard.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isMenuOpen = false;

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'gasongo020@gmail.com',
      query: Uri.encodeFull(
          'subject=Support Request&body=Describe your issue here.'),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      print('Could not launch email');
    }
  }

  Widget buildButton(String text, VoidCallback onTap,
      {bool showArrow = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            if (showArrow)
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget buildSideMenu(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.blue[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: 40),
          buildMenuItem(Icons.dashboard, 'Dashboard', onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdminDashboard()));
          }),
          buildMenuItem(Icons.people, 'User Management', onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => UserManagementPage()));
          }),
          buildMenuItem(Icons.approval, 'Seller Approval', onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => SellerApprovalPage()));
          }),
          buildMenuItem(Icons.shopping_cart, 'Orders', onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const Admin_OrdersPage()));
          }),
          buildMenuItem(Icons.settings, 'Settings', onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => SettingsPage()));
          }),
        ],
      ),
    );
  }

  Widget buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isMenuOpen = !_isMenuOpen;
                });
              },
            ),
            SizedBox(width: 10),
            Text("Settings",
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            Spacer(),
          ],
        ),
      ),
      body: Row(
        children: [
          if (_isMenuOpen) buildSideMenu(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Account",
                        style: TextStyle(color: Colors.black, fontSize: 16)),
                    Divider(color: Colors.blue[900]),
                    buildButton("Log out", () => _logout(context)),
                    SizedBox(height: 20),
                    Text("Other",
                        style: TextStyle(color: Colors.black, fontSize: 16)),
                    Divider(color: Colors.blue[900]),
                    buildButton("Contact support", _contactSupport,
                        showArrow: true),
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
