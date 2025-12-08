// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class DisplayScreensPage extends StatefulWidget {
  final String shopId;

  const DisplayScreensPage({super.key, required this.shopId});

  @override
  State<DisplayScreensPage> createState() => _DisplayScreensPageState();
}

class _DisplayScreensPageState extends State<DisplayScreensPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _displayNameController = TextEditingController();

  String? _selectedDisplayId;
  String? _selectedDisplayName;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // ✅ CREATE DISPLAY
  Future<void> _createDisplay() async {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) return;

    final doc = await FirebaseFirestore.instance.collection('displays').add({
      'shopId': widget.shopId,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _selectedDisplayId = doc.id;
      _selectedDisplayName = name;
    });

    _displayNameController.clear();
    Navigator.pop(context);
  }

  void _showAddDisplayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Display'),
        content: TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(hintText: 'Kitchen / Bar / Drinks'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createDisplay,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ✅ ✅ ✅ READY → ALERT WAITER
  Future<void> _markItemReady(String docId, Map<String, dynamic> data) async {
    try {
      // ✅ Update display order status
      await FirebaseFirestore.instance
          .collection('display_orders')
          .doc(docId)
          .update({
            'status': 'ready',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // ✅ Add waiter alert
      await FirebaseFirestore.instance.collection('waiter_alerts').add({
        'shopId': widget.shopId,
        'orderId': data['orderId'],
        'orderNumber': data['orderNumber'],
        'itemName': data['itemName'],
        'displayName': data['displayName'],
        'status': 'unread',
        'message': '✅ ${data['itemName']} is ready from ${data['displayName']}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Food marked ready & waiter notified'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log("Ready error: $e");
    }
  }

  // ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedDisplayName ?? 'DISPLAYS'),
        backgroundColor: const Color(0xFF13452E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showAddDisplayDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDisplayCards(),
          const Divider(height: 1),
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  // ✅ DISPLAY TABS
  Widget _buildDisplayCards() {
    return SizedBox(
      height: 110,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('displays')
            .where('shopId', isEqualTo: widget.shopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final displays = snapshot.data!.docs;

          if (displays.isEmpty) {
            return const Center(child: Text('No Displays Added Yet'));
          }

          if (_selectedDisplayId == null) {
            final first = displays.first;
            _selectedDisplayId = first.id;
            _selectedDisplayName =
                (first.data() as Map<String, dynamic>)['name'];
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: displays.length,
            itemBuilder: (context, index) {
              final doc = displays[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'];
              final isSelected = doc.id == _selectedDisplayId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDisplayId = doc.id;
                    _selectedDisplayName = name;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF13452E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF13452E),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF13452E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ ✅ ✅ DISPLAY ITEMS STREAM
  Widget _buildOrdersList() {
    if (_selectedDisplayId == null) {
      return const Center(child: Text('Select a Display'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('display_orders')
          .where('shopId', isEqualTo: widget.shopId)
          .where('displayId', isEqualTo: _selectedDisplayId)
          .where('status', whereIn: ['pending', 'cooking', 'ready'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        if (items.isEmpty) {
          return const Center(child: Text('No Orders For This Display'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';

            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildDisplayItemCard(doc.id, data, status),
            );
          },
        );
      },
    );
  }

  // ✅ ✅ ✅ PROFESSIONAL STATUS BUTTON FLOW
  Widget _buildDisplayItemCard(
    String docId,
    Map<String, dynamic> data,
    String status,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: Icon(_getStatusIcon(status), color: Colors.white),
        ),
        title: Text('${data['itemName']} x${data['qty']}'),
        subtitle: Text('Order: ${data['orderNumber']}'),
        trailing: status == 'pending'
            ? ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('display_orders')
                      .doc(docId)
                      .update({
                        'status': 'cooking',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('START'),
              )
            : status == 'cooking'
            ? ElevatedButton(
                onPressed: () => _markItemReady(docId, data),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('READY'),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
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
        return Icons.pending_actions;
      case 'cooking':
        return Icons.local_fire_department;
      case 'ready':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
