// ignore_for_file: deprecated_member_use, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';

// Import Pages
import 'pages/dashboard_home_page.dart';
import 'pages/shops_page.dart';
import 'pages/settings_page.dart';
import 'pages/payments_page.dart';
import '../../login_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int selectedIndex = 0;

  final List<String> menuItems = ["Dashboard", "Shops", "Payments", "Settings"];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.storefront,
    Icons.payment,
    Icons.settings,
  ];

  final List<Widget> pages = [
    DashboardHomePage(),
    ShopsPage(),
    PaymentsPage(),
    SettingsPage(),
  ];

  // Custom colors
  final Color darkGreen = const Color(0xFF13452E);
  final Color lightGray = const Color(0xFFCDD3D0);
  final Color pitchBlack = const Color(0xFF010703);
  final Color softWhite = const Color(0xFFF7F7F7);
  final Color activeHighlight = const Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: softWhite,

      // ✅ MOBILE DRAWER
      drawer: isMobile ? _buildSidebar(isMobile) : null,

      // ✅ MOBILE APP BAR
      appBar: isMobile
          ? AppBar(
              backgroundColor: darkGreen,
              title: Text(menuItems[selectedIndex]),
            )
          : null,

      body: Row(
        children: [
          // ✅ DESKTOP SIDEBAR
          if (!isMobile) _buildSidebar(isMobile),

          Expanded(
            child: Column(
              children: [
                // ✅ DESKTOP TOP BAR
                if (!isMobile)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: softWhite,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
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
                        Row(
                          children: [
                            Icon(Icons.notifications_none,
                                size: 26, color: pitchBlack),
                            const SizedBox(width: 20),
                            PopupMenuButton(
                              icon: CircleAvatar(
                                radius: 20,
                                backgroundColor: lightGray,
                                child:
                                    Icon(Icons.person, color: pitchBlack),
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem<int>(
                                  value: 0,
                                  child: Text("Logout"),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 0) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LoginScreen(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // ✅ PAGE CONTENT
                Expanded(
                  child: Container(
                    color: softWhite.withOpacity(0.95),
                    child: pages[selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ SHARED SIDEBAR (WEB + MOBILE)
  Widget _buildSidebar(bool isMobile) {
    return Container(
      width: 260,
      color: darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              "SUPER ADMIN",
              style: TextStyle(
                color: softWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),

          ...List.generate(menuItems.length, (index) {
            bool active = selectedIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });

                // ✅ Close drawer on mobile
                if (isMobile) Navigator.pop(context);
              },
              child: Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: active ? activeHighlight : darkGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      menuIcons[index],
                      color: active ? softWhite : lightGray,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        menuItems[index],
                        style: TextStyle(
                          color: active ? softWhite : lightGray,
                          fontSize: 18,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
