import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gas_on_go/welcome/welcome_page.dart';
import '../methods/common_methods.dart';
import '../widgets/loading_dialog.dart';
import 'package:gas_on_go/admin_pages/AdminDashboard.dart';

class LoginScreen_admin extends StatefulWidget {
  const LoginScreen_admin({super.key});

  @override
  State<LoginScreen_admin> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen_admin> {
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  late bool securetext;
  CommonMethods cMethods = CommonMethods();
  String userName = '';

  checkIfNetworkIsAvailable() {
    cMethods.checkConnectivity(context);
    signinFormValidation();
  }

  signinFormValidation() {
    if (!_emailController.text.contains('@')) {
      cMethods.displaySnackBar('Please write valid email.', context);
    } else if (_passwordController.text.trim().length < 8) {
      cMethods.displaySnackBar(
          'Your password must be at least 8 characters or more.', context);
    } else {
      signInUser();
    }
  }

  signInUser() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: 'Please wait...'),
    );

    final User? userFirebase = (await FirebaseAuth.instance
            .signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    )
            .catchError((errorMsg) {
      Navigator.pop(context);
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }))
        .user;

    if (!context.mounted) return;
    Navigator.pop(context);

    if (userFirebase != null) {
      DatabaseReference usersRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userFirebase.uid);
      usersRef.once().then((snap) {
        if (snap.snapshot.value != null) {
          final userData = snap.snapshot.value as Map;

          if (userData['role'] == 'admin') {
            if (userData['blockStatus'] == 'no') {
              userName = userData['name'];
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AdminDashboard()));
            } else {
              FirebaseAuth.instance.signOut();
              cMethods.displaySnackBar(
                  'You are blocked. Contact the company.', context);
            }
          } else {
            FirebaseAuth.instance.signOut();
            cMethods.displaySnackBar(
                'Access denied. Only admin accounts are allowed.', context);
          }
        } else {
          FirebaseAuth.instance.signOut();
          cMethods.displaySnackBar('Your account does not exist.', context);
        }
      });
    }
  }

  @override
  void initState() {
    securetext = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Color.fromARGB(255, 15, 15, 41),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => WelcomeScreen()));
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Image.asset('assets/gas.png'),
                const Text(
                  'Admin Login',
                  style: TextStyle(
                      color: Color.fromARGB(255, 15, 15, 41),
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color.fromARGB(255, 15, 52, 117),
                          ),
                          labelText: 'Email',
                          labelStyle: const TextStyle(
                            fontSize: 17,
                            color: Color.fromARGB(255, 15, 52, 117),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 15, 52, 117),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 15, 52, 117),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 15, 52, 117),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: securetext,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.password,
                            color: Color.fromARGB(255, 15, 52, 117),
                          ),
                          suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  securetext = !securetext;
                                });
                              },
                              icon: securetext
                                  ? const Icon(
                                      Icons.visibility_off,
                                      color: Color.fromARGB(255, 15, 52, 117),
                                    )
                                  : const Icon(
                                      Icons.visibility,
                                      color: Color.fromARGB(255, 15, 52, 117),
                                    )),
                          labelText: 'Password',
                          labelStyle: const TextStyle(
                            fontSize: 17,
                            color: Color.fromARGB(255, 15, 52, 117),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 15, 52, 117),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 15, 52, 117),
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 15, 52, 117),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                          onPressed: () {
                            checkIfNetworkIsAvailable();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 15, 52, 117),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.only(
                                left: 40, right: 40, top: 13, bottom: 13),
                            elevation: 5,
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                                color: Color.fromARGB(255, 188, 186, 186),
                                fontSize: 17),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
