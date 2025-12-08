// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:files/screens/admin/pages/pos_items_page.dart';

class WaiterOrderPage extends StatefulWidget {
  final String shopId;
  final String waiterId;

  const WaiterOrderPage({
    super.key,
    required this.shopId,
    required this.waiterId,
  });

  @override
  State<WaiterOrderPage> createState() => _WaiterOrderPageState();
}

class _WaiterOrderPageState extends State<WaiterOrderPage> {
  late Timer _timer;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ✅ ✅ ✅ PERFECT TIMER (INT + STRING + NEGATIVE SUPPORT)
  String _getRemainingTime(
    Timestamp startedAt,
    List items,
    String kitchenStatus,
  ) {
    int maxPrepMinutes = 0;

    for (var item in items) {
      final t = item['preparationTime'];

      int minutes = 0;

      if (t is int) {
        minutes = t;
      } else if (t is String) {
        minutes = int.tryParse(t) ?? 0;
      }

      if (minutes > maxPrepMinutes) {
        maxPrepMinutes = minutes;
      }
    }

    // ✅ SAFE FALLBACK
    if (maxPrepMinutes <= 0) maxPrepMinutes = 10;

    final endTime =
        startedAt.toDate().add(Duration(minutes: maxPrepMinutes));

    final diff = endTime.difference(DateTime.now());

    if (kitchenStatus.toLowerCase() == "ready") return "READY ✅";

    if (diff.isNegative) {
      final over = diff.abs();
      return "-${over.inMinutes.remainder(60).toString().padLeft(2, '0')}:${over.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }

    final minutes =
        diff.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds =
        diff.inSeconds.remainder(60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  // ✅ ✅ ✅ FINAL STATUS HANDLER + HISTORY MOVE
  Future<void> _updateOrderStatus(
    String orderId,
    String status,
    Map<String, dynamic> orderData,
  ) async {
    if (_processing) return;
    _processing = true;

    try {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);

      // ✅ MOVE TO HISTORY
      if (status == "completed") {
        await FirebaseFirestore.instance
            .collection('waiter_order_history')
            .doc(orderId)
            .set({
          ...orderData,
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        await orderRef.delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Order completed & moved to history"),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // ✅ NORMAL STATUS UPDATE
      await orderRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == 'picked') 'pickedAt': FieldValue.serverTimestamp(),
        if (status == 'served') 'servedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processing = false;
    }
  }

  // ✅ INFO CHIP
  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ✅ PRIMARY BUTTON
  Widget _primaryButton(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: widget.shopId)
          .where('waiterId', isEqualTo: widget.waiterId)
          .where('status', whereIn: ['placed', 'picked', 'served'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snap.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text("No active orders",
                style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            final data = order.data() as Map<String, dynamic>;
            final items = (data['items'] ?? []) as List;

            final kitchenStatus = (data['kitchenStatus'] ?? 'pending')
                .toString()
                .toLowerCase();
            final status = (data['status'] ?? 'placed')
                .toString()
                .toLowerCase();

            final timerText = data['prepStartedAt'] != null
                ? _getRemainingTime(
                    data['prepStartedAt'], items, kitchenStatus)
                : "--:--";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['orderNumber'] ?? "Order",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 10),

                  Text(timerText,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoChip("ITEMS", items.length.toString()),
                      _infoChip("STATUS", status.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (kitchenStatus == 'ready' && status == 'placed')
                    _primaryButton("PICKUP", Icons.shopping_bag,
                        () => _updateOrderStatus(order.id, "picked", data))
                  else if (status == 'picked')
                    _primaryButton("SERVED", Icons.checklist,
                        () => _updateOrderStatus(order.id, "served", data))
                  else if (status == 'served')
                    _primaryButton("COMPLETE ORDER", Icons.done_all,
                        () => _updateOrderStatus(order.id, "completed", data)),

                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => POSItemsPage(
                            orderType: data['orderType'] ?? "dine in",
                            shopId: widget.shopId,
                            existingOrderId: order.id,
                            existingOrderData: data,
                          ),
                        ),
                      );
                    },
                    child: const Text("OPEN ORDER"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
