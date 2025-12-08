// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class DisplayScreensPage extends StatefulWidget {
  final String shopId;

  const DisplayScreensPage({super.key, required this.shopId});

  @override
  State<DisplayScreensPage> createState() => DisplayScreensPageState();
}

class DisplayScreensPageState extends State<DisplayScreensPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ INVENTORY CHECK BEFORE COOKING
  // ============================================================
  Future<bool> _hasSufficientInventory(Map<String, dynamic> orderData) async {
    try {
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

      for (var item in items) {
        final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
        final baseInvList = item['inventoryRequirements'];

        if (baseInvList is! List) continue;

        for (var baseInvRaw in baseInvList) {
          if (baseInvRaw is! Map<String, dynamic>) continue;

          final String? invId = baseInvRaw['inventoryId']?.toString();
          if (invId == null || invId.isEmpty) continue;

          final invDoc = await FirebaseFirestore.instance
              .collection('inventory')
              .doc(invId)
              .get();

          final currentQty =
              (invDoc.data()?['quantity'] as num?)?.toDouble() ?? 0;

          final perUnit =
              double.tryParse(baseInvRaw['inventoryQty']?.toString() ?? '0') ??
              0;
          final requiredQty = perUnit * qty;

          if (requiredQty > 0 && currentQty < requiredQty) return false;
        }
      }

      return true;
    } catch (e) {
      developer.log("Inventory check error: $e");
      return true; // fail open so kitchen can still continue
    }
  }

  // ============================================================
  // ✅ SAFE ATOMIC INVENTORY DEDUCTION
  //    - ignores bad entries
  //    - works even if inventory doc doesn't exist
  // ============================================================
  Future<void> _deductInventory(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

    for (var item in items) {
      final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
      final invListRaw = item['inventoryRequirements'];

      if (invListRaw is! List) continue;

      for (var invRaw in invListRaw) {
        if (invRaw is! Map<String, dynamic>) continue;

        final String? invId = invRaw['inventoryId']?.toString();
        if (invId == null || invId.isEmpty) continue;

        final perUnit =
            double.tryParse(invRaw['inventoryQty']?.toString() ?? "0") ?? 0;
        final totalUsed = perUnit * qty;

        if (totalUsed <= 0) continue;

        final ref = FirebaseFirestore.instance
            .collection('inventory')
            .doc(invId);

        // ✅ Use set + merge to avoid "document does not exist" errors
        batch.set(ref, {
          'quantity': FieldValue.increment(-totalUsed),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    try {
      await batch.commit();
    } catch (e) {
      developer.log("Inventory deduction error: $e");
      // rethrow so _updateOrderStatus can handle if needed
      rethrow;
    }
  }

  // ============================================================
  // ✅ KITCHEN STATUS UPDATE
  // ============================================================
  Future<void> _updateOrderStatus(
    String orderId,
    String status,
    Map<String, dynamic> data,
  ) async {
    try {
      if (status == 'cooking') {
        final ok = await _hasSufficientInventory(data);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Inventory not sufficient")),
          );
          return;
        }
      }

      if (status == 'ready') {
        await _deductInventory(orderId, data);
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'kitchenStatus': status,
            'kitchenUpdatedAt': FieldValue.serverTimestamp(),
            if (status == 'ready') 'readyAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      developer.log("Order update error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Failed to update order: $e")));
    }
  }

  // ============================================================
  // ✅ UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("KITCHEN DISPLAY"),
        backgroundColor: const Color(0xFF13452E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('shopId', isEqualTo: widget.shopId)
            .where('kitchenStatus', whereIn: ['pending', 'cooking', 'ready'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snap.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No kitchen orders"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['kitchenStatus'] ?? "pending").toString();

              return FadeTransition(
                opacity: _fadeAnimation,
                child: _buildOrderCard(doc.id, data, status),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // ✅ SINGLE ORDER CARD
  // ============================================================
  Widget _buildOrderCard(
    String orderId,
    Map<String, dynamic> data,
    String status,
  ) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: Icon(_getStatusIcon(status), color: Colors.white),
        ),
        title: Text(data['orderNumber'] ?? "Order"),
        subtitle: Text("${items.length} items"),
        children: [
          ...items.map(
            (item) => ListTile(
              title: Text(item['name'] ?? ''),
              subtitle: Text("Qty: ${item['qty'] ?? 1}"),
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: status == 'pending'
                      ? () => _updateOrderStatus(orderId, 'cooking', data)
                      : null,
                  child: const Text("START COOKING"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: status == 'cooking'
                      ? () => _updateOrderStatus(orderId, 'ready', data)
                      : null,
                  child: const Text("MARK READY"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'cooking':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'cooking':
        return Icons.local_fire_department;
      case 'ready':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
