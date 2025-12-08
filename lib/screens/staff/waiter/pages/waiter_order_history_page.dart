// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'waiter_pos_page.dart';

class WaiterOrderHistoryPage extends StatefulWidget {
  final String shopId;
  final String waiterId;

  const WaiterOrderHistoryPage({
    super.key,
    required this.shopId,
    required this.waiterId,
  });

  @override
  State<WaiterOrderHistoryPage> createState() => _WaiterOrderHistoryPageState();
}

class _WaiterOrderHistoryPageState extends State<WaiterOrderHistoryPage> {
  final CollectionReference ordersCollection = FirebaseFirestore.instance
      .collection('orders');

  String _formatDate(Timestamp? ts) {
    if (ts == null) return "-";
    final date = ts.toDate();
    return DateFormat('dd MMM yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101417),
      appBar: AppBar(
        title: const Text("Completed Orders"),
        backgroundColor: const Color(0xFF13452E),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersCollection
            .where('shopId', isEqualTo: widget.shopId)
            .where('waiterId', isEqualTo: widget.waiterId)
            .where('status', isEqualTo: 'completed') // ✅ ONLY COMPLETED
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                "No completed orders yet",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final items = data['items'] as List<dynamic>? ?? [];

              final total = (data['grandTotal'] ?? data['totalPrice'] ?? 0)
                  .toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ExpansionTile(
                    collapsedIconColor: Colors.white,
                    iconColor: Colors.white,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.done_all, color: Colors.white),
                    ),
                    title: Text(
                      data['orderNumber'] ?? 'Order',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total: Rs ${total.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(data['completedAt']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            ...items.map((item) {
                              final qty = item['qty'] ?? 0;
                              final price = item['price'] ?? 0;

                              return ListTile(
                                title: Text(item['name'] ?? ''),
                                subtitle: Text("Qty: $qty"),
                                trailing: Text(
                                  "Rs ${(qty * price).toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            const Divider(),

                            /// ✅ OPEN ORDER IN POS (READ MODE)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: const BorderSide(color: Colors.black),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text(
                                    "OPEN ORDER",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => POSItemsPage(
                                          shopId: widget.shopId,
                                          orderType:
                                              data['orderType'] ?? "Dine In",
                                          waiterId: widget.waiterId, // ✅ FIXED
                                          existingOrderId: order.id,
                                          existingOrderData: data,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
