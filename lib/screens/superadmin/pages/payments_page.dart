import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentsPage extends StatelessWidget {
  PaymentsPage({super.key});

  final CollectionReference paymentsRef = FirebaseFirestore.instance.collection(
    "payments",
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------- PAGE TITLE -------------------
          const Text(
            "Payments Overview",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF010703),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------- TABLE CARD -------------------
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: StreamBuilder<QuerySnapshot>(
                  stream: paymentsRef
                      .orderBy("date", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No Payments Found",
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }

                    final payments = snapshot.data!.docs;

                    // ------------------- SCROLLABLE TABLE -------------------
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateColor.resolveWith(
                          (states) => const Color(0xFF13452E),
                        ),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        columnSpacing: 60,
                        columns: const [
                          DataColumn(label: Text("Shop ID")),
                          DataColumn(label: Text("Shop Name")),
                          DataColumn(label: Text("Owner Name")),
                          DataColumn(label: Text("Payment")),
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Time")),
                        ],
                        rows: payments.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final date = data["date"] != null
                              ? data["date"].toDate()
                              : DateTime.now();

                          return DataRow(
                            cells: [
                              DataCell(Text(data["shopId"] ?? "-")),
                              DataCell(Text(data["shopName"] ?? "-")),
                              DataCell(Text(data["ownerName"] ?? "-")),
                              DataCell(Text("PKR ${data["payment"]}")),
                              DataCell(
                                Text("${date.year}-${date.month}-${date.day}"),
                              ),
                              DataCell(
                                Text(
                                  "${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
