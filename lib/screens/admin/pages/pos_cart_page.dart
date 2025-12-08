// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class POSCartPage extends StatefulWidget {
  final String shopId;
  final String orderType;
  final List<Map<String, dynamic>> cartItems;
  final Function(List<Map<String, dynamic>>) onUpdate;

  const POSCartPage({
    super.key,
    required this.shopId,
    required this.orderType,
    required this.cartItems,
    required this.onUpdate,
  });

  @override
  State<POSCartPage> createState() => _POSCartPageState();
}

class _POSCartPageState extends State<POSCartPage> {
  String? selectedArea;
  String? selectedTableId;
  String? selectedWaiterId;

  List<String> areas = [];
  List<Map<String, String>> tables = [];

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  // ============== FETCH AREAS =================
  Future<void> _fetchAreas() async {
    final snap = await FirebaseFirestore.instance
        .collection('tables')
        .where('shopId', isEqualTo: widget.shopId)
        .get();

    final setArea = <String>{};
    for (var d in snap.docs) {
      final area = d['area'];
      if (area != null) setArea.add(area);
    }

    setState(() => areas = setArea.toList());
  }

  // ============== FETCH TABLES =================
  Future<void> _fetchTables(String area) async {
    final snap = await FirebaseFirestore.instance
        .collection('tables')
        .where('shopId', isEqualTo: widget.shopId)
        .where('area', isEqualTo: area)
        .get();

    final list = snap.docs.map((d) {
      return {'id': d.id, 'tableNumber': d['tableNumber'].toString()};
    }).toList();

    setState(() => tables = list);
  }

  // ============== CART UPDATE =================
  double get total {
    double t = 0;
    for (var c in widget.cartItems) {
      t += (c['price'] * c['qty']);
    }
    return t;
  }

  void increase(int i) {
    setState(() {
      widget.cartItems[i]['qty']++;
    });
    widget.onUpdate(widget.cartItems);
  }

  void decrease(int i) {
    setState(() {
      if (widget.cartItems[i]['qty'] > 1) {
        widget.cartItems[i]['qty']--;
      } else {
        widget.cartItems.removeAt(i);
      }
    });
    widget.onUpdate(widget.cartItems);
  }

  // ============== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cart"),
        backgroundColor: const Color(0xFF13452E),
      ),
      body: Column(
        children: [
          // ======= CART ITEMS =========
          Expanded(
            child: ListView.builder(
              itemCount: widget.cartItems.length,
              itemBuilder: (context, i) {
                final item = widget.cartItems[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(item['name']),
                    subtitle: Text(
                      "Rs ${item['price']} x ${item['qty']} = Rs ${item['price'] * item['qty']}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => decrease(i),
                          icon: const Icon(Icons.remove),
                        ),
                        Text(item['qty'].toString()),
                        IconButton(
                          onPressed: () => increase(i),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ======= TOTAL & CHECKOUT =======
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                Text(
                  "Total: Rs $total",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13452E),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    // Yahan aap apna previous checkout code paste kar sakte ho
                  },
                  child: const Text("Checkout"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
