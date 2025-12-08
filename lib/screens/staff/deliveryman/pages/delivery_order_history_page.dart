// ignore_for_file: unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeliveryAvailableOrdersPage extends StatelessWidget {
  final String shopId;
  final String deliveryManId;

  const DeliveryAvailableOrdersPage({
    super.key,
    required this.shopId,
    required this.deliveryManId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ✅ SAFE STREAM (no compound index needed)
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

        final docs = snapshot.data!.docs;

        // ✅ SAFE FILTERING IN DART
        final availableOrders = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final orderType =
              (data['orderType'] ?? '').toString().toLowerCase();
          final status =
              (data['status'] ?? '').toString().toLowerCase();

          if (orderType != 'delivery') return false;
          if (status != 'placed') return false;

          final candidates =
              List<String>.from(data['deliveryCandidates'] ?? []);

          return candidates.contains(deliveryManId);
        }).toList();

        if (availableOrders.isEmpty) {
          return const Center(
            child: Text(
              "No available delivery orders",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final doc = availableOrders[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
                              child: Text(item['name'] ?? 'Item'),
                            ),
                            Text("x${item['qty']}"),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 10),

                    // ---------- ACCEPT BUTTON ----------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text("Accept Order"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(doc.id)
                              .update({
                            'deliveryManId': deliveryManId,
                            'status': 'preparing',
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Order Accepted ✅"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
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
