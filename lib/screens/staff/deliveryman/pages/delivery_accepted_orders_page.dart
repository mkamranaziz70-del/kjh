// ignore_for_file: unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeliveryAcceptedOrdersPage extends StatelessWidget {
  final String shopId;
  final String deliveryManId;

  const DeliveryAcceptedOrdersPage({
    super.key,
    required this.shopId,
    required this.deliveryManId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // ✅ ACCEPTED = preparing + assigned to this delivery man
        final acceptedOrders = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final type =
              (data['orderType'] ?? '').toString().toLowerCase();
          final status =
              (data['status'] ?? '').toString().toLowerCase();
          final assignedMan = data['deliveryManId'];

          if (type != 'delivery') return false;
          if (status != 'preparing') return false;
          if (assignedMan != deliveryManId) return false;

          return true;
        }).toList();

        if (acceptedOrders.isEmpty) {
          return const Center(
            child: Text(
              "No accepted orders",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: acceptedOrders.length,
          itemBuilder: (context, index) {
            final doc = acceptedOrders[index];
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
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
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

                    if (data['customerName'] != null)
                      Text(
                        '👤 ${data['customerName']}',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (data['customerPhone'] != null)
                      Text('📞 ${data['customerPhone']}'),
                    if (data['customerAddress'] != null)
                      Text('📍 ${data['customerAddress']}'),

                    const Divider(),

                    ...(List<Map<String, dynamic>>.from(
                            data['items'] ?? []))
                        .map((item) {
                      return Row(
                        children: [
                          Expanded(
                              child: Text(item['name'] ?? 'Item')),
                          Text("x${item['qty']}"),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 12),

                    // ✅ DELIVER BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Mark as Delivered"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(doc.id)
                              .update({
                            'status': 'delivered',
                            'deliveredAt':
                                FieldValue.serverTimestamp(),
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Order marked as Delivered ✅"),
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
