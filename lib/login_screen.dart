// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// DASHBOARDS
import 'screens/admin/dashboard_screen.dart';
import 'screens/superadmin/dashboard_screen.dart';
import 'screens/staff/waiter/waiter_dasboard.dart';
import 'screens/staff/chef/chef_dashboard.dart'; // ✅ NEW CHEF DASHBOARD
import 'screens/staff/deliveryman/deliveryman_dashboard.dart';
import 'screens/staff/cashier/cashier_dashboard.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool loading = false;
  String error = "";

  // Colors
  final Color darkGreen = const Color(0xFF13452E);
  final Color softWhite = const Color(0xFFF7F7F7);

  // ============================================================
  // ✅ FINAL LOGIN FUNCTION — SUPERADMIN + ADMIN + WAITER + CHEF
  // ============================================================
  void loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = "";
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      // ============================================================
      // 1️⃣ SUPER ADMIN LOGIN
      // ============================================================
      if (email == "superadmin@example.com") {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuperAdminDashboard()),
        );
        return;
      }

      // ============================================================
      // 2️⃣ ADMIN LOGIN (shops collection)
      // ============================================================
      QuerySnapshot adminSnap = await FirebaseFirestore.instance
          .collection('shops')
          .where('ownerEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        var adminData = adminSnap.docs.first.data() as Map<String, dynamic>;

        if (adminData['password'] == password) {
          String shopId = adminSnap.docs.first.id;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AdminDashboard(shopId: shopId)),
          );
          return;
        }
      }

      // ============================================================
      // 3️⃣ STAFF LOGIN (WAITERS + CHEFS)
      // ============================================================
      QuerySnapshot staffSnap = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (staffSnap.docs.isNotEmpty) {
        var staffData = staffSnap.docs.first.data() as Map<String, dynamic>;

        if (staffData['password'] == password) {
          String role = staffData['role']; // ✅ waiter / chef
          String shopId = staffData['shopId'];
          String staffId = staffSnap.docs.first.id;

          // ✅ ROLE BASED DASHBOARD
          if (role == "waiter") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          WaiterDashboard(shopId: shopId, waiterId: staffId),
    ),
  );
  return;
}

if (role == "chef") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ChefDashboard(shopId: shopId, chefId: staffId),
    ),
  );
  return;
}

if (role == "cashier") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CashierDashboard(shopId: shopId, cashierId: staffId),
    ),
  );
  return;
}

if (role == "delivery man" || role == "delivery") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => DeliveryManDashboard(
        shopId: shopId,
        deliveryManId: staffId,
      ),
    ),
  );
  return;
}


          // Future roles: manager, cashier, etc
        }
      }

      // ============================================================
      // ❌ INVALID LOGIN
      // ============================================================
      setState(() {
        error = "Invalid email or password";
      });
    } catch (e) {
      setState(() {
        error = "Login failed. Try again.";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // ✅ UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: softWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "AMPF SHAHKOT",
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ---------------- EMAIL ----------------
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email, color: darkGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? "Enter email" : null,
                  ),
                  const SizedBox(height: 20),

                  // ---------------- PASSWORD ----------------
                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock, color: darkGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter password"
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ---------------- ERROR ----------------
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 20),

                  // ---------------- LOGIN BUTTON ----------------
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : loginUser,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
