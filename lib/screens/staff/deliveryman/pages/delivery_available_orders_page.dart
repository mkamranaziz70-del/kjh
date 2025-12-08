// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeliveryOrderHistoryPage extends StatelessWidget {
  final String shopId;
  final String deliveryManId;

  const DeliveryOrderHistoryPage({
    super.key,
    required this.shopId,
    required this.deliveryManId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ✅ SAFE STREAM (no compound index issues)
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text("No data found"));
        }

        final allDocs = snapshot.data!.docs;

        // ✅ SAFE FILTERING IN DART
        final deliveredOrders = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final orderType =
              (data['orderType'] ?? '').toString().toLowerCase();
          final status =
              (data['status'] ?? '').toString().toLowerCase();
          final assignedDeliveryMan = data['deliveryManId'];

          if (orderType != 'delivery') return false;
          if (status != 'delivered') return false;
          if (assignedDeliveryMan != deliveryManId) return false;

          return true;
        }).toList();

        if (deliveredOrders.isEmpty) {
          return const Center(
            child: Text(
              "No delivered orders yet",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: deliveredOrders.length,
          itemBuilder: (context, index) {
            final doc = deliveredOrders[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- HEADER ----------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['orderNumber'] ?? 'Order',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Rs ${(data['grandTotal'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ---------- CUSTOMER ----------
                    if (data['customerName'] != null)
                      Text(
                        '👤 ${data['customerName']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                    if (data['customerPhone'] != null)
                      Text('📞 ${data['customerPhone']}'),

                    if (data['customerAddress'] != null)
                      Text('📍 ${data['customerAddress']}'),

                    const Divider(),

                    // ---------- ITEMS ----------
                    ...(List<Map<String, dynamic>>.from(data['items'] ?? []))
                        .map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child:
                                  Text(item['name'] ?? 'Item'),
                            ),
                            Text("x${item['qty']}"),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 8),

                    // ---------- STATUS ----------
                    const Text(
                      "✅ Delivered",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
