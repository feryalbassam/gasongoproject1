import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gas_on_go/firebase_options.dart';
import 'package:gas_on_go/pages/Ratings_Reviews_Page.dart';
import 'package:gas_on_go/user_authentication/login_screen.dart';
import 'package:gas_on_go/user_pages/Payment%20Page.dart';
import 'package:gas_on_go/user_pages/edit_profile_page.dart';
import 'package:gas_on_go/user_pages/notification_page.dart';
import 'package:gas_on_go/user_pages/user_profile.dart';
import 'package:gas_on_go/welcome/splash_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gas_on_go/user_pages/order_placement.dart';
import 'package:gas_on_go/user_pages/order_tracking_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await Permission.locationWhenInUse.isDenied.then((valueofPermission) {
    if (valueofPermission) {
      Permission.locationWhenInUse.request();
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/profile': (context) => const ProfilePage(),
          '/order_placement': (context) => const OrderPlacementPage(),
          '/order_tracking': (context) => OrderTrackingScreen(orderId: ''),
          '/payment': (context) => const PaymentPage(
                orderId: '',
              ),
          '/edit_profile': (context) => const EditProfilePage(),
          '/notification': (context) => const NotificationsPage(),
        },
        home: AnimatedSplashScreenWidget());
  }
}
