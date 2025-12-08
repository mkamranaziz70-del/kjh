// ignore_for_file: deprecated_member_use, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import '../../../login_screen.dart';

import 'package:files/screens/staff/deliveryman/pages/delivery_available_orders_page.dart';
import 'package:files/screens/staff/deliveryman/pages/delivery_accepted_orders_page.dart';
import 'package:files/screens/staff/deliveryman/pages/delivery_order_history_page.dart';
import 'package:files/screens/staff/deliveryman/pages/delivery_earnings_page.dart';

class DeliveryManDashboard extends StatefulWidget {
  final String shopId;
  final String deliveryManId;

  const DeliveryManDashboard({
    super.key,
    required this.shopId,
    required this.deliveryManId,
  });

  @override
  State<DeliveryManDashboard> createState() => _DeliveryManDashboardState();
}

class _DeliveryManDashboardState extends State<DeliveryManDashboard> {
  int selectedIndex = 0;

  // ✅ SIDEBAR ITEMS (NOW 3 PAGES)
  final List<String> menuItems = [
    "Available Orders",
    "Accepted Orders",
    "Order History",
      "Earnings",

  ];

  final List<IconData> menuIcons = [
    Icons.assignment,
    Icons.check_circle,
    Icons.history,
      Icons.payments,

  ];

  List<Widget> pages = [];

  // ✅ THEME COLORS
  final Color darkGreen = const Color(0xFF13452E);
  final Color lightGray = const Color(0xFFCDD3D0);
  final Color pitchBlack = const Color(0xFF010703);
  final Color softWhite = const Color(0xFFF7F7F7);
  final Color activeHighlight = const Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();

    // ✅ CONNECT DELIVERY MAN PAGES
    pages = [
      DeliveryAvailableOrdersPage(
        shopId: widget.shopId,
        deliveryManId: widget.deliveryManId,
      ),
      DeliveryAcceptedOrdersPage(
        shopId: widget.shopId,
        deliveryManId: widget.deliveryManId,
      ),
      DeliveryOrderHistoryPage(
        shopId: widget.shopId,
        deliveryManId: widget.deliveryManId,
      ),
       DeliveryEarningsPage(
    shopId: widget.shopId,
    deliveryManId: widget.deliveryManId,
  ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Row(
        children: [
          // ---------------- SIDEBAR ----------------
          Container(
            width: width < 800 ? 200 : 260,
            color: darkGreen,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "DELIVERY DASHBOARD",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                ...List.generate(menuItems.length, (index) {
                  bool isActive = selectedIndex == index;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 18,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? activeHighlight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            menuIcons[index],
                            color: isActive ? softWhite : lightGray,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              menuItems[index],
                              style: TextStyle(
                                fontSize: 17,
                                color: isActive ? softWhite : lightGray,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // ---------------- LOGOUT ----------------
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- MAIN CONTENT ----------------
          Expanded(
            child: Column(
              children: [
                // ✅ TOP BAR
                Container(
                  height: 60,
                  color: softWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        menuItems[selectedIndex],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: pitchBlack,
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: darkGreen,
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ ACTIVE PAGE
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
