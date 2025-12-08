import 'package:flutter/material.dart';
import '../../../login_screen.dart';
import 'cashier_orders_page.dart';
import 'cashier_payments_page.dart';

class CashierDashboard extends StatefulWidget {
  final String shopId;
  final String cashierId; // ✅ MUST EXIST

  const CashierDashboard({
    super.key,
    required this.shopId,
    required this.cashierId, // ✅ MUST EXIST
  });

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  int selectedIndex = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      OrderPage(),
      PaymentPage(shopId: widget.shopId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isMobile),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
      drawer: isMobile ? Drawer(child: _buildSidebar()) : null,
    );
  }

  Widget _buildTopBar(bool isMobile) => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFF13452E),
        child: Row(
          children: [
            if (isMobile)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            const SizedBox(width: 8),
            const Text(
              "CASHIER DASHBOARD",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );

  Widget _buildSidebar() => Container(
        width: 240,
        color: const Color(0xFF13452E),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              "CASHIER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            _sidebarItem(Icons.receipt_long, "Orders", 0),
            _sidebarItem(Icons.payment, "Payments", 1),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _sidebarItem(IconData icon, String title, int index) => ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        selected: selectedIndex == index,
        selectedTileColor: Colors.green.shade700,
        onTap: () => setState(() => selectedIndex = index),
      );

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
