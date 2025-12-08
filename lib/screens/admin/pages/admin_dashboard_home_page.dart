// ignore_for_file: deprecated_member_use, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardHomePage extends StatefulWidget {
  final String shopId;
  const AdminDashboardHomePage({super.key, required this.shopId});

  @override
  State<AdminDashboardHomePage> createState() =>
      _AdminDashboardHomePageState();
}

class _AdminDashboardHomePageState
    extends State<AdminDashboardHomePage> {
  final CollectionReference ordersRef =
      FirebaseFirestore.instance.collection('orders');
  final CollectionReference shopRef =
      FirebaseFirestore.instance.collection('shops');

  DateTime get todayStart => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  Stream<QuerySnapshot> get _todayOrdersStream => ordersRef
      .where('shopId', isEqualTo: widget.shopId)
      .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
      )
      .snapshots();

  // ---------------- DASHBOARD CARD ----------------
  Widget dashboardCard({
    required String title,
    required IconData icon,
    required Color colorStart,
    required Color colorEnd,
    required String value,
    String? subtitle,
  }) {
    return Container(
      height: subtitle == null ? 140 : 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child:
                Icon(icon, size: 50, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  // ---------------- SAFE HELPERS ----------------
  double _safeGetAmount(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return 0.0;

      final candidates = ['grandTotal', 'orderAmount', 'total', 'amount'];
      for (String field in candidates) {
        final value = data[field];
        if (value != null) {
          return double.tryParse(value.toString()) ?? 0.0;
        }
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String _safeGetCustomer(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return '';

      final candidates = ['customerName', 'customerId', 'customer'];
      for (String field in candidates) {
        final value = data[field];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  String _safeGetStatus(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['status']?.toString() ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ SHOP NAME
          StreamBuilder<DocumentSnapshot>(
            stream: shopRef.doc(widget.shopId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text(
                  "Loading Shop...",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                );
              }
              final shopData =
                  snapshot.data!.data() as Map<String, dynamic>? ?? {};
              return Text(
                shopData["name"] ?? "Shop",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ✅ TODAY STATS
          StreamBuilder<QuerySnapshot>(
            stream: _todayOrdersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final todayOrders = snapshot.data?.docs ?? [];
              final todayOrdersCount = todayOrders.length;

              final todayEarnings = todayOrders.fold<double>(
                0,
                (sum, doc) => sum + _safeGetAmount(doc),
              );

              final uniqueCustomers = todayOrders
                  .map((doc) => _safeGetCustomer(doc))
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .length;

              final avgOrder = todayOrdersCount == 0
                  ? 0
                  : todayEarnings / todayOrdersCount;

              final statusCounts = <String, int>{};
              for (var doc in todayOrders) {
                final status = _safeGetStatus(doc);
                statusCounts[status] =
                    (statusCounts[status] ?? 0) + 1;
              }

              final stats = statusCounts.entries.map((entry) {
                final percentage = todayOrdersCount > 0
                    ? (entry.value /
                        todayOrdersCount *
                        100)
                    : 0;

                return OrderStats(
                  status: entry.key,
                  count: entry.value,
                  percentage: percentage.toDouble(),
                );
              }).toList();

              return Column(
                children: [
                  // ✅ RESPONSIVE CARD GRID
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: isMobile
                            ? double.infinity
                            : MediaQuery.of(context).size.width / 2 -
                                32,
                        child: dashboardCard(
                          title: "Today's Orders",
                          icon: Icons.shopping_cart,
                          colorStart: const Color(0xFF13452E),
                          colorEnd: const Color(0xFF1FAB89),
                          value: todayOrdersCount.toString(),
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? double.infinity
                            : MediaQuery.of(context).size.width / 2 -
                                32,
                        child: dashboardCard(
                          title: "Today's Earnings",
                          icon: Icons.attach_money,
                          colorStart: const Color(0xFF010703),
                          colorEnd: const Color(0xFF13452E),
                          value:
                              "PKR ${todayEarnings.toStringAsFixed(0)}",
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? double.infinity
                            : MediaQuery.of(context).size.width / 2 -
                                32,
                        child: dashboardCard(
                          title: "Customers",
                          icon: Icons.people,
                          colorStart: const Color(0xFF13452E),
                          colorEnd: const Color(0xFF4CAF50),
                          value: uniqueCustomers.toString(),
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? double.infinity
                            : MediaQuery.of(context).size.width / 2 -
                                32,
                        child: dashboardCard(
                          title: "Avg Order",
                          icon: Icons.trending_up,
                          colorStart: const Color(0xFF010703),
                          colorEnd: const Color(0xFF1FAB89),
                          value:
                              "PKR ${avgOrder.toStringAsFixed(0)}",
                        ),
                      ),
                    ],
                  ),

                  if (stats.isNotEmpty)
                    _buildStatusBreakdown(stats),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- STATUS BOX ----------------
  Widget _buildStatusBreakdown(List<OrderStats> stats) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics,
                  color: Color(0xFF13452E), size: 28),
              SizedBox(width: 12),
              Text(
                'Order Status Today',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stats.map(
            (stat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: stat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${stat.status}: ${stat.count}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${stat.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: stat.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- MODEL ----------------
class OrderStats {
  final String status;
  final int count;
  final double percentage;
  final Color color;

  OrderStats({
    required this.status,
    required this.count,
    required this.percentage,
  }) : color = _getStatusColor(status);

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'ready':
        return Colors.green;
      case 'preparing':
        return Colors.blue;
      case 'placed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
