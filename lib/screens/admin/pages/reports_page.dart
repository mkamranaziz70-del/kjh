// ✅ COMPLETE PROFESSIONAL DAILY REPORTS PAGE
// Shows Sales, Orders, Inventory Usage, Expenses & Profit (Date Wise)

// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  final String shopId;
  const ReportsPage({super.key, required this.shopId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime selectedDate = DateTime.now();

  DateTime get startOfDay => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    0,
    0,
    0,
  );
  DateTime get endOfDay => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    23,
    59,
    59,
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  // ✅ ORDERS QUERY
  Stream<QuerySnapshot> get ordersStream => FirebaseFirestore.instance
      .collection('orders')
      .where('shopId', isEqualTo: widget.shopId)
      .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      )
      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .snapshots();

  // ✅ INVENTORY USAGE QUERY
  Stream<QuerySnapshot> get usageStream => FirebaseFirestore.instance
      .collection('inventory_usage')
      .where('shopId', isEqualTo: widget.shopId)
      .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      )
      .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .snapshots();

  // ✅ EXPENSES QUERY
  Stream<QuerySnapshot> get expensesStream => FirebaseFirestore.instance
      .collection('expenses')
      .where('shopId', isEqualTo: widget.shopId)
      .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      )
      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .snapshots();

  double _safeAmount(dynamic v) =>
      double.tryParse(v.toString())?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(selectedDate);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('📊 Daily Reports'),
        backgroundColor: const Color(0xFF13452E),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(
              formattedDate,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = orderSnapshot.data!.docs;

          double totalSales = 0;
          int totalOrders = orders.length;
          int completed = 0;
          int cancelled = 0;
          double cash = 0, card = 0, online = 0;

          for (var doc in orders) {
            final data = doc.data() as Map<String, dynamic>;
            final total = _safeAmount(data['grandTotal']);
            final status = data['status'] ?? 'placed';
            final method = data['paymentMethod'] ?? 'cash';

            totalSales += total;

            if (status == 'completed') completed++;
            if (status == 'cancelled') cancelled++;

            if (method == 'cash') cash += total;
            if (method == 'card') card += total;
            if (method == 'online') online += total;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: usageStream,
            builder: (context, usageSnapshot) {
              final usageDocs = usageSnapshot.data?.docs ?? [];
              final usageCount = usageDocs.length;

              return StreamBuilder<QuerySnapshot>(
                stream: expensesStream,
                builder: (context, expenseSnapshot) {
                  final expensesDocs = expenseSnapshot.data?.docs ?? [];
                  double totalExpenses = 0;

                  for (var doc in expensesDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    totalExpenses += _safeAmount(data['amount']);
                  }

                  final profit = totalSales - totalExpenses;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Sales Summary'),
                        _rowCards([
                          _card(
                            'Total Sales',
                            'PKR ${totalSales.toStringAsFixed(0)}',
                          ),
                          _card('Total Orders', '$totalOrders'),
                          _card('Completed', '$completed'),
                          _card('Cancelled', '$cancelled'),
                        ]),

                        _sectionTitle('Payment Breakdown'),
                        _rowCards([
                          _card('Cash', 'PKR ${cash.toStringAsFixed(0)}'),
                          _card('Card', 'PKR ${card.toStringAsFixed(0)}'),
                          _card('Online', 'PKR ${online.toStringAsFixed(0)}'),
                        ]),

                        _sectionTitle('Inventory Usage'),
                        _rowCards([_card('Items Used', '$usageCount')]),

                        _sectionTitle('Expenses'),
                        _rowCards([
                          _card(
                            'Total Expenses',
                            'PKR ${totalExpenses.toStringAsFixed(0)}',
                          ),
                        ]),

                        _sectionTitle('Profit'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: profit >= 0 ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'PKR ${profit.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        _sectionTitle('Order History'),
                        _orderTable(orders),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  Widget _rowCards(List<Widget> cards) =>
      Wrap(spacing: 16, runSpacing: 16, children: cards);

  Widget _card(String title, String value) => Container(
    width: 180,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
      ],
    ),
    child: Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _orderTable(List<QueryDocumentSnapshot> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text('No orders for this day'));
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Order #')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Payment')),
        DataColumn(label: Text('Status')),
      ],
      rows: orders.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DataRow(
          cells: [
            DataCell(Text(data['orderNumber']?.toString() ?? '')),
            DataCell(Text('PKR ${data['grandTotal']}')),
            DataCell(Text(data['paymentMethod'] ?? 'cash')),
            DataCell(Text(data['status'] ?? 'placed')),
          ],
        );
      }).toList(),
    );
  }
}
