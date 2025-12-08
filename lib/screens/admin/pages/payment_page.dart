// lib/pages/payment_page.dart
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentPage extends StatefulWidget {
  final String shopId;
  const PaymentPage({super.key, required this.shopId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _statusFilter = 'Pending'; // Pending / Completed / All

  final List<String> _statusOptions = const ['Pending', 'Completed', 'All'];

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF13452E);
    const Color softWhite = Color(0xFFF7F7F7);
    const Color pitchBlack = Color(0xFF010703);

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('payments')
        .orderBy('createdAt', descending: true);

    if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter.toLowerCase());
    }

    return Container(
      color: softWhite,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- FILTER BAR ----------------
          Row(
            children: [
              Text(
                "Payments",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: pitchBlack,
                ),
              ),
              const Spacer(),
              const Text("Status:", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: darkGreen.withOpacity(0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    items: _statusOptions
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _statusFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------------- PAYMENT TABLE ----------------
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading payments',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No payments found.",
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: darkGreen.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          "Payment List",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 900),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 42,
                                dataRowHeight: 52,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                columns: const [
                                  DataColumn(label: Text("Order #")),
                                  DataColumn(label: Text("Payment")),
                                  DataColumn(label: Text("Method")),
                                  DataColumn(label: Text("Status")),
                                  DataColumn(label: Text("Date")),
                                  DataColumn(label: Text("Time")),
                                  DataColumn(label: Text("Action")),
                                ],
                                rows: docs.map((doc) {
                                  final data = doc.data();

                                  // ✅ EXACT ORDER NUMBER STRING
                                  final String orderNumber =
                                      data['orderNumber']?.toString() ?? '—';

                                  final num amount =
                                      data['totalAmount'] ??
                                      data['amount'] ??
                                      0;

                                  final String method =
                                      (data['paymentMethod'] ?? '—').toString();

                                  final String status =
                                      (data['status'] ?? 'pending').toString();

                                  final Timestamp ts =
                                      (data['createdAt'] ?? Timestamp.now())
                                          as Timestamp;

                                  final dateTime = ts.toDate();

                                  final dateString =
                                      "${dateTime.day.toString().padLeft(2, '0')}-"
                                      "${dateTime.month.toString().padLeft(2, '0')}-"
                                      "${dateTime.year}";

                                  final timeString =
                                      "${dateTime.hour.toString().padLeft(2, '0')}:"
                                      "${dateTime.minute.toString().padLeft(2, '0')}";

                                  final bool isPending =
                                      status.toLowerCase() == 'pending';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(orderNumber)),
                                      DataCell(Text(amount.toStringAsFixed(2))),
                                      DataCell(Text(method)),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPending
                                                ? Colors.orange[50]
                                                : Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isPending ? "Pending" : "Completed",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isPending
                                                  ? Colors.orange[800]
                                                  : Colors.green[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(dateString)),
                                      DataCell(Text(timeString)),

                                      // ✅ ACTION COLUMN
                                      DataCell(
                                        isPending
                                            ? _PaymentActionWidget(
                                                paymentDoc: doc,
                                              )
                                            : const Text(
                                                "✔ Paid",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ ================= PAYMENT ACTION WIDGET =================
class _PaymentActionWidget extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> paymentDoc;

  const _PaymentActionWidget({required this.paymentDoc});

  @override
  State<_PaymentActionWidget> createState() => _PaymentActionWidgetState();
}

class _PaymentActionWidgetState extends State<_PaymentActionWidget> {
  String? selectedMethod;
  bool showMethods = false;

  final List<String> methods = [
    'Cash',
    'Card',
    'Online',
    'JazzCash',
    'EasyPaisa',
    'Bank Transfer',
  ];

  @override
  Widget build(BuildContext context) {
    if (!showMethods) {
      return ElevatedButton(
        onPressed: () {
          setState(() => showMethods = true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: const Text("Add Payment", style: TextStyle(fontSize: 12)),
      );
    }

    return Row(
      children: [
        DropdownButton<String>(
          hint: const Text("Method", style: TextStyle(fontSize: 12)),
          value: selectedMethod,
          items: methods.map((m) {
            return DropdownMenuItem<String>(
              value: m,
              child: Text(m, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => selectedMethod = val);
          },
        ),

        const SizedBox(width: 6),
        ElevatedButton(
          onPressed: selectedMethod == null
              ? null
              : () async {
                  await widget.paymentDoc.reference.update({
                    'status': 'completed',
                    'paymentMethod': selectedMethod,
                    'completedAt': FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    showMethods = false;
                    selectedMethod = null;
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: const Text("Confirm", style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
