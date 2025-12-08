// ignore_for_file: prefer_const_constructors_in_immutables, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardHomePage extends StatelessWidget {
  DashboardHomePage({super.key});

  Stream<int> getShopsCountStream() {
    return FirebaseFirestore.instance
        .collection('shops')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getActiveShopsCountStream() {
    return FirebaseFirestore.instance
        .collection('active_shops')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getPendingPaymentsCountStream() {
    return FirebaseFirestore.instance
        .collection('pending_payments')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF010703),
            ),
          ),
          const SizedBox(height: 20),

          // 🔥 Horizontal full-width gradient cards
          Column(
            children: [
              dashboardCard(
                "Total Shops",
                Icons.storefront,
                getShopsCountStream(),
                gradientColors: [Color(0xFF13452E), Color(0xFF1FAB89)],
              ),
              dashboardCard(
                "Active Shops",
                Icons.check_circle,
                getActiveShopsCountStream(),
                gradientColors: [Color(0xFF13452E), Color(0xFF010703)],
              ),
              dashboardCard(
                "Pending Payments",
                Icons.pending_actions,
                getPendingPaymentsCountStream(),
                gradientColors: [Color(0xFF010703), Color(0xFF13452E)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget dashboardCard(
    String title,
    IconData icon,
    Stream<int> stream, {
    required List<Color> gradientColors,
  }) {
    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final count = snapshot.data ?? 0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Right side icon with subtle shadow
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  size: 50,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
