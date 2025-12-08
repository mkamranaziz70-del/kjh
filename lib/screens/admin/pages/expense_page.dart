// lib/pages/expense_page.dart
// ✅ FULL PROFESSIONAL EXPENSE PAGE

// ignore_for_file: deprecated_member_use, unused_local_variable, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpensePage extends StatefulWidget {
  final String shopId;
  const ExpensePage({super.key, required this.shopId});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  String _filter = 'All';

  final List<String> _filters = ['Today', 'This Month', 'All'];

  final List<String> _categories = [
    'Rent',
    'Salary',
    'Electricity',
    'Gas',
    'Internet',
    'Repair',
    'Purchase',
    'Misc',
  ];

  final List<String> _methods = ['Cash', 'Bank', 'JazzCash', 'EasyPaisa'];

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF13452E);
    const softWhite = Color(0xFFF7F7F7);
    const pitchBlack = Color(0xFF010703);

    Query query = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('expenses')
        .orderBy('createdAt', descending: true);

    final now = DateTime.now();

    if (_filter == 'Today') {
      final start = DateTime(now.year, now.month, now.day);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    } else if (_filter == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }

    return Container(
      color: softWhite,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ---------------- HEADER ----------------
          Row(
            children: [
              const Text(
                "Expenses",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _filter,
                items: _filters
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _filter = val);
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text("Add Expense"),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------------- TABLE ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No expenses found"));
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Date")),
                        DataColumn(label: Text("Category")),
                        DataColumn(label: Text("Description")),
                        DataColumn(label: Text("Method")),
                        DataColumn(label: Text("Amount")),
                        DataColumn(label: Text("Action")),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final amount =
                            (data['amount'] as num?)?.toDouble() ?? 0;
                        final category = data['category'] ?? '';
                        final desc = data['description'] ?? '';
                        final method = data['paymentMethod'] ?? '';
                        final ts = data['createdAt'] as Timestamp?;
                        final date = ts?.toDate() ?? DateTime.now();

                        return DataRow(
                          cells: [
                            DataCell(
                              Text("${date.day}-${date.month}-${date.year}"),
                            ),
                            DataCell(Text(category)),
                            DataCell(Text(desc)),
                            DataCell(Text(method)),
                            DataCell(Text("Rs ${amount.toStringAsFixed(0)}")),
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  doc.reference.delete();
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- ADD EXPENSE DIALOG ----------------

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = _categories.first;
    String method = _methods.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: category,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => category = val.toString(),
              decoration: const InputDecoration(labelText: "Category"),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: method,
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => method = val.toString(),
              decoration: const InputDecoration(labelText: "Payment Method"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;

              await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('expenses')
                  .add({
                    'shopId': widget.shopId,
                    'amount': amount,
                    'category': category,
                    'description': descCtrl.text.trim(),
                    'paymentMethod': method,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
