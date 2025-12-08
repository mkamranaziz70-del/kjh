// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';

class CartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final double cartTotal;
  final VoidCallback onCheckout;
  final Function(int) increaseQty;
  final Function(int) decreaseQty;

  const CartWidget({
    super.key,
    required this.cartItems,
    required this.cartTotal,
    required this.onCheckout,
    required this.increaseQty,
    required this.decreaseQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ...cartItems.map((c) {
                  final index = cartItems.indexOf(c);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(c['name'] ?? 'Unnamed'),
                      subtitle: Text(
                        "Rs ${c['price']} x ${c['qty']} = Rs ${(c['price'] ?? 0) * (c['qty'] ?? 0)}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => decreaseQty(index),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${c['qty']}'),
                          IconButton(
                            onPressed: () => increaseQty(index),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Total + Checkout
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  "Total: Rs $cartTotal",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13452E),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Checkout", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
