// ignore_for_file: deprecated_member_use, avoid_types_as_parameter_names, prefer_const_constructors_in_immutables, undefined_hidden_name

import 'package:flutter/material.dart';
import 'pages/admin_dashboard_home_page.dart';
import 'pages/menu_items_page.dart';
import 'pages/item_categories_page.dart';
import 'pages/table_page.dart';
import 'pages/pos_page.dart';
import 'pages/order_page.dart';
import 'pages/payment_page.dart';
import 'pages/staff_roles.dart';
import 'pages/customer_page.dart';
import 'pages/expense_page.dart';
import 'pages/reports_page.dart';
import 'pages/inventory_page.dart';
import 'pages/display_screens_page.dart';
import 'pages/settings_page.dart';
import '../../login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String shopId;
  AdminDashboard({super.key, required this.shopId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;
  int? selectedSubMenuIndex;

  final List<String> menuItems = [
    "Dashboard",
    "Menu",
    "Table",
    "POS",
    "Order",
    "Payment",
    "Staff",
    "Customer",
    "Expense",
    "Reports",
    "Inventory",
    "Display Screens",
    "Settings",
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.restaurant_menu,
    Icons.table_chart,
    Icons.point_of_sale,
    Icons.receipt_long,
    Icons.payment,
    Icons.people,
    Icons.person,
    Icons.money_off,
    Icons.bar_chart,
    Icons.inventory,
    Icons.tv,
    Icons.settings,
  ];

  Map<String, List<Map<String, dynamic>>> get subMenus => {
        "Menu": [
          {
            "title": "Menu Items",
            "icon": Icons.fastfood,
            "builder": () => MenuItemsPage(shopId: widget.shopId),
          },
          {
            "title": "Item Categories",
            "icon": Icons.category,
            "builder": () => ItemCategoriesPage(shopId: widget.shopId),
          },
        ],
      };

  List<Widget?> pages = [];
  Widget? currentPage;

  final Color darkGreen = const Color(0xFF13452E);
  final Color lightGray = const Color(0xFFCDD3D0);
  final Color pitchBlack = const Color(0xFF010703);
  final Color softWhite = const Color(0xFFF7F7F7);
  final Color activeHighlight = const Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();

    pages = [
      AdminDashboardHomePage(shopId: widget.shopId),
      null,
      TablePage(shopId: widget.shopId),
      POSPage(shopId: widget.shopId),
      OrderPage(),
      PaymentPage(shopId: widget.shopId),
      StaffPage(shopId: widget.shopId),
      CustomerPage(),
      ExpensePage(shopId: widget.shopId),
      ReportsPage(shopId: widget.shopId),
      InventoryPage(shopId: widget.shopId),
      DisplayScreensPage(shopId: widget.shopId),
      SettingsPage(),
    ];

    currentPage = pages[0];
  }

  void _updatePageForMenu(int index) {
    switch (index) {
      case 0:
        pages[index] = AdminDashboardHomePage(shopId: widget.shopId);
        break;
      case 2:
        pages[index] = TablePage(shopId: widget.shopId);
        break;
      case 3:
        pages[index] = POSPage(shopId: widget.shopId);
        break;
      case 4:
        pages[index] = OrderPage();
        break;
      case 5:
        pages[index] = PaymentPage(shopId: widget.shopId);
        break;
      case 6:
        pages[index] = StaffPage(shopId: widget.shopId);
        break;
      case 7:
        pages[index] = CustomerPage();
        break;
      case 8:
        pages[index] = ExpensePage(shopId: widget.shopId);
        break;
      case 9:
        pages[index] = ReportsPage(shopId: widget.shopId);
        break;
      case 10:
        pages[index] = InventoryPage(shopId: widget.shopId);
        break;
      case 11:
        pages[index] = DisplayScreensPage(shopId: widget.shopId);
        break;
      case 12:
        pages[index] = SettingsPage();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: softWhite,

      // ✅ MOBILE DRAWER
      drawer: isMobile ? _buildSidebar(isMobile) : null,

      // ✅ MOBILE APPBAR
      appBar: isMobile
          ? AppBar(
              backgroundColor: darkGreen,
              title: Text(
                selectedSubMenuIndex != null
                    ? subMenus["Menu"]![selectedSubMenuIndex!]["title"]
                    : menuItems[selectedIndex],
              ),
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
                    color: softWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedSubMenuIndex != null
                              ? subMenus["Menu"]![selectedSubMenuIndex!]["title"]
                              : menuItems[selectedIndex],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: pitchBlack,
                          ),
                        ),
                        PopupMenuButton(
                          icon: CircleAvatar(
                            child: Icon(Icons.person, color: pitchBlack),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 0, child: Text("Logout")),
                          ],
                          onSelected: (value) {
                            if (value == 0) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: currentPage ??
                      const Center(
                        child: Text(
                          "Select a submenu",
                          style: TextStyle(fontSize: 22),
                        ),
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
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "ADMIN DASHBOARD",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            ...List.generate(menuItems.length, (index) {
              bool hasSub = subMenus.containsKey(menuItems[index]);
              bool isActive =
                  selectedIndex == index && selectedSubMenuIndex == null;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                        selectedSubMenuIndex = null;
                      });

                      if (!hasSub) {
                        _updatePageForMenu(index);
                        setState(() => currentPage = pages[index]);
                      }

                      if (isMobile) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 18),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            isActive ? activeHighlight : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(menuIcons[index],
                              color:
                                  isActive ? softWhite : lightGray),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              menuItems[index],
                              style: TextStyle(
                                fontSize: 17,
                                color:
                                    isActive ? softWhite : lightGray,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasSub)
                            Icon(
                              selectedIndex == index
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_right,
                              color: softWhite,
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (hasSub && selectedIndex == index)
                    Column(
                      children: subMenus[menuItems[index]]!
                          .asMap()
                          .entries
                          .map((e) {
                        int subIndex = e.key;
                        var sub = e.value;

                        bool activeSub =
                            selectedSubMenuIndex == subIndex;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedSubMenuIndex = subIndex;
                              currentPage = sub["builder"]();
                            });

                            if (isMobile) Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                            margin: const EdgeInsets.only(
                                left: 40, top: 5, bottom: 5),
                            decoration: BoxDecoration(
                              color: activeSub
                                  ? activeHighlight
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(sub["icon"],
                                    color: activeSub
                                        ? softWhite
                                        : lightGray),
                                const SizedBox(width: 12),
                                Text(
                                  sub["title"],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: activeSub
                                        ? softWhite
                                        : lightGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
