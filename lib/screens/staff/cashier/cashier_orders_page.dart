// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps, unused_local_variable, unnecessary_to_list_in_spreads

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:files/screens/admin/pages/pos_items_page.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  String selectedStatus = 'all';
  String selectedDateFilter = 'today';
  final TextEditingController searchController = TextEditingController();

  final Map<String, String> _tableCache = {};
  final Map<String, String> _waiterCache = {};
  final Map<String, String> _deliveryCache = {};

  final String shopId = 'your_shop_id';

  static const Color primaryGreen = Color(0xFF13452E);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ------------------- MAIN BUILD -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: primaryGreen,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  final search = searchController.text.toLowerCase().trim();

                  final orderNumber =
                      (data['orderNumber'] ?? '').toString().toLowerCase();
                  final waiterId =
                      (data['waiterId'] ?? '').toString().toLowerCase();
                  final tableId =
                      (data['tableId'] ?? '').toString().toLowerCase();
                  final customerName =
                      (data['customerName'] ?? '').toString().toLowerCase();
                  final customerPhone =
                      (data['customerPhone'] ?? '').toString().toLowerCase();

                  final matchesSearch = search.isEmpty ||
                      orderNumber.contains(search) ||
                      waiterId.contains(search) ||
                      tableId.contains(search) ||
                      customerName.contains(search) ||
                      customerPhone.contains(search);

                  final matchesStatus = selectedStatus == 'all' ||
                      data['status'] == selectedStatus;

                  final matchesDate = _matchesDateFilter(createdAt);

                  return matchesSearch && matchesStatus && matchesDate;
                }).toList();

                if (orders.isEmpty) {
                  return const Center(child: Text("No orders found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return GestureDetector(
                      onTap: () {
                        if ((data['status'] ?? 'placed') != 'delivered') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => POSItemsPage(
                                orderType: data['orderType'] ?? 'dine in',
                                shopId: shopId,
                                existingOrderId: doc.id,
                                existingOrderData: data,
                              ),
                            ),
                          );
                        }
                      },
                      child: _buildOrderCard(data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- FILTER UI -------------------
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchController,
        decoration: const InputDecoration(
          hintText: 'Search by order, name, phone...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ------------------- ORDER CARD -------------------
 Widget _buildOrderCard(Map<String, dynamic> data) {
  final status = (data['status'] ?? 'placed').toString().toLowerCase();
  final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
  final orderType = (data['orderType'] ?? '').toString().toLowerCase();

  Color statusColor;
  String statusText;

  if (status == 'delivered') {
    statusColor = Colors.green;
    statusText = 'DELIVERED';
  } else if (status == 'preparing') {
    statusColor = Colors.orange;
    statusText = 'PREPARING';
  } else {
    statusColor = Colors.grey;
    statusText = 'PLACED';
  }

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- HEADER ----------------
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

          // ✅✅✅ STATUS BADGE (THIS WAS MISSING) ✅✅✅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ---------------- SUB TITLE ----------------
          _buildOrderSubTitle(data),

          const Divider(),

          // ---------------- ITEMS ----------------
          ...items.map((item) {
            return Row(
              children: [
                Expanded(child: Text(item['name'] ?? 'Item')),
                Text("x${item['qty']}"),
              ],
            );
          }).toList(),

          const SizedBox(height: 8),

          // ---------------- DELIVERY MAN ----------------
          if (orderType == 'delivery')
            FutureBuilder<String>(
              future: _getDeliveryManName(data['deliveryManId']),
              builder: (context, snap) {
                return Text(
                  "🛵 Delivery By: ${snap.data ?? 'Not Assigned'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
        ],
      ),
    ),
  );
}


  // ------------------- ORDER SUB TITLE -------------------
  Widget _buildOrderSubTitle(Map<String, dynamic> data) {
    final type = (data['orderType'] ?? '').toString().toLowerCase();

    if (type == 'delivery') {
      return Text(
        '👤 ${data['customerName']} · 📞 ${data['customerPhone']}\n📍 ${data['customerAddress']}',
      );
    }

    if (type == 'pickup') {
      return Text(
        '👜 Pickup · 👤 ${data['customerName']} · 📞 ${data['customerPhone']}',
      );
    }

    return FutureBuilder<Map<String, String>>(
      future: _fetchDisplayMeta(data),
      builder: (context, snap) {
        final t = snap.data?['table'] ?? 'N/A';
        final w = snap.data?['waiter'] ?? 'N/A';
        return Text('Table: $t · Waiter: $w');
      },
    );
  }

  // ------------------- HELPERS -------------------
  Future<Map<String, String>> _fetchDisplayMeta(
      Map<String, dynamic> data) async {
    final tableId = data['tableId']?.toString();
    final waiterId = data['waiterId']?.toString();

    return {
      'table': await _getTableDisplay(tableId),
      'waiter': await _getWaiterDisplay(waiterId),
    };
  }

  Future<String> _getTableDisplay(String? tableId) async {
    if (tableId == null) return 'N/A';
    if (_tableCache.containsKey(tableId)) return _tableCache[tableId]!;

    final doc =
        await FirebaseFirestore.instance.collection('tables').doc(tableId).get();
    final name =
        '${doc.data()?['area']} - T${doc.data()?['tableNumber']}';

    _tableCache[tableId] = name;
    return name;
  }

  Future<String> _getWaiterDisplay(String? waiterId) async {
    if (waiterId == null) return 'N/A';
    if (_waiterCache.containsKey(waiterId)) return _waiterCache[waiterId]!;

    final doc =
        await FirebaseFirestore.instance.collection('staff').doc(waiterId).get();
    final name = doc.data()?['name'] ?? 'N/A';

    _waiterCache[waiterId] = name;
    return name;
  }

  Future<String> _getDeliveryManName(String? deliveryManId) async {
    if (deliveryManId == null || deliveryManId.isEmpty) {
      return 'Not Assigned';
    }

    if (_deliveryCache.containsKey(deliveryManId)) {
      return _deliveryCache[deliveryManId]!;
    }

    final doc = await FirebaseFirestore.instance
        .collection('staff')
        .doc(deliveryManId)
        .get();

    final name = doc.data()?['name'] ?? 'Unknown';
    _deliveryCache[deliveryManId] = name;

    return name;
  }

  bool _matchesDateFilter(DateTime orderDate) {
    final now = DateTime.now();
    if (selectedDateFilter == 'today') {
      return orderDate.day == now.day &&
          orderDate.month == now.month &&
          orderDate.year == now.year;
    }
    return true;
  }
}
