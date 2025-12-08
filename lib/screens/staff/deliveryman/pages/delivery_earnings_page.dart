// ignore_for_file: unnecessary_to_list_in_spreads, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeliveryEarningsPage extends StatelessWidget {
  final String shopId;
  final String deliveryManId;

  // ✅ CHANGE THIS IF YOU WANT DIFFERENT COMMISSION
  static const double earningPerOrder = 100;

  const DeliveryEarningsPage({
    super.key,
    required this.shopId,
    required this.deliveryManId,
  });

  bool _isToday(Timestamp? ts) {
    if (ts == null) return false;
    final d = ts.toDate();
    final now = DateTime.now();
    return d.day == now.day && d.month == now.month && d.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('orderType', isEqualTo: 'delivery')
          .where('deliveryManId', isEqualTo: deliveryManId)
          .where('status', isEqualTo: 'delivered')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        double totalEarnings = docs.length * earningPerOrder;

        final todayOrders = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _isToday(data['deliveredAt']);
        }).toList();

        double todayEarnings = todayOrders.length * earningPerOrder;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ SUMMARY CARDS
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Today's Earnings",
                      value: "Rs ${todayEarnings.toStringAsFixed(0)}",
                      color: Colors.green,
                      icon: Icons.today,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      title: "Total Earnings",
                      value: "Rs ${totalEarnings.toStringAsFixed(0)}",
                      color: Colors.blue,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ✅ DELIVERED ORDERS LIST
              Expanded(
                child: todayOrders.isEmpty
                    ? const Center(
                        child: Text(
                          "No earnings today",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: todayOrders.length,
                        itemBuilder: (context, index) {
                          final doc = todayOrders[index];
                          final data =
                              doc.data() as Map<String, dynamic>;

                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.local_shipping,
                                color: Colors.green,
                              ),
                              title: Text(
                                data['orderNumber'] ?? 'Order',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                data['customerName'] ?? '',
                              ),
                              trailing: Text(
                                "Rs ${earningPerOrder.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ SMALL HELPER CARD
  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
