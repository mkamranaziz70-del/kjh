// lib/pages/positemspage.dart - UPDATED WITH ALL REQUESTED FEATURES
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, avoid_types_as_parameter_names, use_build_context_synchronously, unused_element, unnecessary_null_in_if_null_operators

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class POSItemsPage extends StatefulWidget {
  final String orderType;
  final String shopId;
  final String? existingOrderId; // ✅ NEW
  final Map<String, dynamic>? existingOrderData; // ✅ NEW
  const POSItemsPage({
    super.key,
    required this.orderType,
    required this.shopId,
    this.existingOrderId,
    this.existingOrderData,
  });

  @override
  State<POSItemsPage> createState() => _POSItemsPageState();
}

class _POSItemsPageState extends State<POSItemsPage> {
  String selectedCategoryId = 'all';
  final TextEditingController searchController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController customerAddressController =
      TextEditingController();

  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> newItems = [];
  List<String> tableList = [];
  List<String> areaList = [];
  List<String> waiterList = [];
  String orderNumber = '';
  String tableInfo = '';
  String area = '';
  String waiterName = '';
  Map<String, String> categoryMap = {};
  String? selectedArea;
  String? selectedTableId;
  String? selectedWaiterId;
  String? selectedDeliveryManId;
  List<String> availableAreas = [];
  List<Map<String, String>> availableTables = [];
  bool isLoadingTables = false;
  int lastOrderNumber = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadExistingOrder();

    if (widget.orderType.toLowerCase() == 'dine in') {
      _fetchAreas();
    }
    _fetchLastOrderNumber();
  }

  Future<void> _loadExistingOrder() async {
    if (widget.existingOrderData != null) {
      final data = widget.existingOrderData!;

      orderNumber = data['orderNumber'] ?? '';
      cartItems = List<Map<String, dynamic>>.from(data['items'] ?? []);

      // Set dropdown-bound variables
      selectedArea = data['area'] ?? null;
      selectedTableId =
          data['tableId'] ?? null; // If you store table ID in order
      selectedWaiterId = data['waiterId'] ?? null;

      // Fetch tables for the existing area
      if (selectedArea != null)
        await _fetchAvailableTablesForArea(selectedArea!);

      setState(() {});
    }
  }

  Future<void> _sendNewItems() async {
    if (widget.existingOrderId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.existingOrderId);

    // Push only new items
    await docRef.update({
      'items': FieldValue.arrayUnion(newItems),
      'grandTotal': FieldValue.increment(
        newItems.fold(0, (sum, item) => sum + (item['total'] ?? 0)),
      ),
    });

    // Optionally, send new items to display/kitchen collection
    for (var item in newItems) {
      await FirebaseFirestore.instance.collection('display').add({
        'orderId': widget.existingOrderId,
        'orderNumber': orderNumber,
        'item': item,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    newItems.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New items added to order successfully!')),
    );
    setState(() {});
  }

  @override
  void dispose() {
    searchController.dispose();
    customerNameController.dispose();
    customerPhoneController.dispose();
    customerAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('shopId', isEqualTo: widget.shopId)
          .get();
      final map = <String, String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        map[doc.id] = data['name'] ?? 'Unnamed';
      }
      if (mounted) setState(() => categoryMap = map);
    } catch (e) {
      debugPrint('LoadCategories error: $e');
    }
  }

  Future<void> _fetchAreas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tables')
          .where('shopId', isEqualTo: widget.shopId)
          .get();
      final areasSet = <String>{};
      for (var d in snapshot.docs) {
        final area = d.data()['area']?.toString();
        if (area != null && area.isNotEmpty) areasSet.add(area);
      }
      if (mounted) setState(() => availableAreas = areasSet.toList()..sort());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load areas')));
      }
    }
  }

  Future<void> _fetchAvailableTablesForArea(String area) async {
    setState(() {
      isLoadingTables = true;
      selectedTableId = null;
      availableTables = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tables')
          .where('shopId', isEqualTo: widget.shopId)
          .where('area', isEqualTo: area)
          .where('status', isEqualTo: 'free')
          .orderBy('tableNumber')
          .get();
      final tables = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'tableNumber': (data['tableNumber'] ?? 0).toString(),
        };
      }).toList();
      if (mounted) setState(() => availableTables = tables);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tables for $area: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingTables = false);
    }
  }

  Future<void> _fetchLastOrderNumber() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('counters')
          .doc('orders')
          .get();
      if (doc.exists) {
        final data = doc.data();
        final today = DateTime.now().toString().split(' ')[0];

        if (data != null && data['date'] == today && data['lastOrder'] is int) {
          lastOrderNumber = data['lastOrder'] as int;
        } else {
          lastOrderNumber = 0;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('fetchLastOrderNumber error: $e');
    }
  }

  Future<void> _handleItemTap(DocumentSnapshot itemDoc) async {
    final data = itemDoc.data() as Map<String, dynamic>;
    final variations = List<Map<String, dynamic>>.from(
      data['variations'] ?? [],
    );

    final fullMenuData = {
      'id': itemDoc.id,
      'name': data['name'] ?? 'Unnamed',
      'price': (data['price'] is num)
          ? data['price']
          : double.tryParse('${data['price']}') ?? 0,
      'description': data['description'] ?? '',
      'categoryId': data['categoryId'] ?? '',
      'categoryName': data['categoryName'] ?? '',
      'displayId': data['displayId'],
      'displayName': data['displayName'],
      'inventoryRequirements': data['inventoryRequirements'],
      'variations': variations,
      'basePrice': data['price'] ?? 0,
      'variantName': '',
      'variantIndex': -1,
    };

    if (variations.isEmpty) {
      _addItemToCart(fullMenuData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${fullMenuData['name']} added to cart')),
      );
      return;
    }
    _showVariantDialog(itemDoc, variations, fullMenuData);
  }

  void _showVariantDialog(
    DocumentSnapshot itemDoc,
    List<Map<String, dynamic>> variants,
    Map<String, dynamic> baseMenuData,
  ) {
    int selectedVariantIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemDoc['name'] ?? 'Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Select variant',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(variants.length, (index) {
                final variant = variants[index];
                final variantName = variant['name']?.toString() ?? 'Standard';
                final variantPrice =
                    (variant['price'] is num ? variant['price'] : 0).toDouble();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RadioListTile<int>(
                    value: index,
                    groupValue: selectedVariantIndex,
                    onChanged: (value) =>
                        setDialogState(() => selectedVariantIndex = value ?? 0),
                    title: Text(
                      variantName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Rs ${variantPrice.toStringAsFixed(0)}'),
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final selectedVariant = variants[selectedVariantIndex];
                final variantPrice = (selectedVariant['price'] is num
                    ? selectedVariant['price']
                    : double.tryParse('${selectedVariant['price']}') ?? 0);

                final itemData = {
                  ...baseMenuData,
                  'price': variantPrice,
                  'variantName': selectedVariant['name']?.toString() ?? '',
                  'variantIndex': selectedVariantIndex,
                  'displayId': baseMenuData['displayId'],
                  'displayName': baseMenuData['displayName'],
                  'selectedVariation': selectedVariant,
                };

                _addItemToCart(itemData);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${itemData['name']} - ${itemData['variantName']} added',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text(
                'Add • Rs ${(variants[selectedVariantIndex]['price'] is num ? variants[selectedVariantIndex]['price'] : 0).toStringAsFixed(0)}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addItemToCart(Map<String, dynamic> item) {
    setState(() {
      final existingIndex = cartItems.indexWhere(
        (c) =>
            c['id'] == item['id'] && c['variantIndex'] == item['variantIndex'],
      );
      if (existingIndex >= 0) {
        cartItems[existingIndex]['qty'] += 1;
      } else {
        cartItems.add({...item, 'qty': 1});
      }
    });
  }

  void increaseItemQty(int index) =>
      setState(() => cartItems[index]['qty'] += 1);

  void decreaseItemQty(int index) {
    setState(() {
      if (cartItems[index]['qty'] > 1) {
        cartItems[index]['qty'] -= 1;
      } else {
        cartItems.removeAt(index);
      }
    });
  }

  double get cartTotal => cartItems.fold(
    0.0,
    (sum, it) => sum + (it['price'] ?? 0) * (it['qty'] ?? 0),
  );
  double get gstAmount => cartTotal * 0.025;
  double get grandTotal => cartTotal + gstAmount;
  int get itemCount => cartItems.length;

  Future<String> _generateOrderNumber() async {
    final firestore = FirebaseFirestore.instance;
    final counterRef = firestore.collection('counters').doc('orders');

    return await firestore.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      int last = 0;
      String today = DateTime.now().toString().split(' ')[0];

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        if (data['date'] == today && data['lastOrder'] is int) {
          last = data['lastOrder'] as int;
        }
      }

      final next = last + 1;
      tx.set(counterRef, {
        'lastOrder': next,
        'date': today,
      }, SetOptions(merge: true));

      setState(() => lastOrderNumber = next);
      return 'Order#$next';
    });
  }

  bool _validateOrderDetails() {
    final orderTypeLower = widget.orderType.toLowerCase();

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return false;
    }

    if (orderTypeLower == 'dine in') {
      if (selectedArea == null ||
          selectedTableId == null ||
          selectedWaiterId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select area, table, and waiter'),
          ),
        );
        return false;
      }
    } else if (orderTypeLower == 'pickup') {
      if (customerNameController.text.trim().isEmpty ||
          customerPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter customer name and phone')),
        );
        return false;
      }
    } else if (orderTypeLower == 'delivery') {
  if (customerNameController.text.trim().isEmpty ||
      customerPhoneController.text.trim().isEmpty ||
      customerAddressController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please complete customer details'),
      ),
    );
    return false;
  }
}


    return true;
  }

 Future<void> _printOnly() async {
  if (!_validateOrderDetails()) return;

  try {
    final nextOrderNum = lastOrderNumber + 1;
    final orderNumber = 'Order#$nextOrderNum';

    // ✅ ================= CASHIER PRINT =================
    await FirebaseFirestore.instance.collection('printQueue').add({
      'printerType': 'cashier',
      'content': '''
================================
          A M P F
           SHAHKOT
================================
Meezan Bank Chowk, Opp. Zakir Shah
Darbar, Shahkot
Ph: 0306-6070591, 0325-8221440
--------------------------------
ORDER NO : $orderNumber
--------------------------------
ITEM            QTY   AMT
--------------------------------
${cartItems.map((e) {
  final name =
      e['name'].toString().padRight(15).substring(0, 15);
  final qty = e['qty'].toString().padLeft(3);
  final total =
      (e['price'] * e['qty']).toStringAsFixed(0).padLeft(5);
  return "$name $qty $total";
}).join("\n")}
--------------------------------
SUBTOTAL : Rs ${cartTotal.toStringAsFixed(0)}
GST 2.5% : Rs ${gstAmount.toStringAsFixed(0)}
--------------------------------
TOTAL    : Rs ${grandTotal.toStringAsFixed(0)}
--------------------------------
         THANK YOU FOR VISIT
================================
''',
      'printRequested': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ ================= KITCHEN PRINT =================
    await FirebaseFirestore.instance.collection('printQueue').add({
      'printerType': 'kitchen',
      'content': '''
================================
           KITCHEN ORDER
================================
ORDER NO : $orderNumber
--------------------------------
ITEM            QTY
--------------------------------
${cartItems.map((e) {
  final name =
      e['name'].toString().padRight(16).substring(0, 16);
  final qty = e['qty'].toString().padLeft(3);
  return "$name  x$qty";
}).join("\n")}
--------------------------------
           PREPARE FAST
================================
''',
      'printRequested': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Professional receipt printed ✅'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Print failed: $e')),
    );
  }
}


Future<void> _submitOrder({bool printAfter = false}) async {
  if (!_validateOrderDetails()) return;

  try {
    // ✅ ================= UPDATE EXISTING ORDER =================
    if (widget.existingOrderId != null && widget.existingOrderData != null) {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.existingOrderId);

      final snapshot = await orderRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order no longer exists')),
        );
        return;
      }

      final existingData = snapshot.data()!;
      final existingItems =
          List<Map<String, dynamic>>.from(existingData['items'] ?? []);

      final newItemsOnly = cartItems.where((cartItem) {
        return !existingItems.any((existingItem) =>
            existingItem['itemId'] == cartItem['id'] &&
            existingItem['variantIndex'] == cartItem['variantIndex']);
      }).toList();

      if (newItemsOnly.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new items to add')),
        );
        return;
      }

      final itemsForSave = newItemsOnly.map((it) {
        return {
          'itemId': it['id'],
          'name': it['name'],
          'variantName': it['variantName'] ?? '',
          'variantIndex': it['variantIndex'] ?? -1,
          'price': it['price'],
          'qty': it['qty'],
          'total': (it['price'] ?? 0) * (it['qty'] ?? 0),
        };
      }).toList();

      final updatedItems = [...existingItems, ...itemsForSave];

      final updatedTotalPrice = updatedItems.fold<double>(
        0,
        (sum, item) => sum + ((item['price'] ?? 0) * (item['qty'] ?? 0)),
      );

      final updatedGst = updatedTotalPrice * 0.025;
      final updatedGrandTotal = updatedTotalPrice + updatedGst;

      await orderRef.update({
        'items': updatedItems,
        'totalPrice': updatedTotalPrice,
        'gst': updatedGst,
        'grandTotal': updatedGrandTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order updated with ${newItemsOnly.length} new items'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
      return;
    }

    // ✅ ================= NEW ORDER =================
    final orderNumber = await _generateOrderNumber();
    final orderDocRef = FirebaseFirestore.instance.collection('orders').doc();
    final orderTypeLower = widget.orderType.toLowerCase(); // ✅ FIXED

    final itemsForSave = cartItems.map((it) {
      return {
        'itemId': it['id'],
        'name': it['name'],
        'variantName': it['variantName'] ?? '',
        'variantIndex': it['variantIndex'] ?? -1,
        'displayId': it['displayId'],
        'displayName': it['displayName'],
        'price': it['price'],
        'qty': it['qty'],
        'total': (it['price'] ?? 0) * (it['qty'] ?? 0),
      };
    }).toList();

    final batch = FirebaseFirestore.instance.batch();

    final Map<String, dynamic> orderData = {
      'shopId': widget.shopId,
      'orderType': orderTypeLower, // ✅ MUST BE LOWERCASE
      'orderNumber': orderNumber,
      'items': itemsForSave,
      'totalPrice': cartTotal,
      'gst': gstAmount,
      'grandTotal': grandTotal,
      'status': 'placed',
      'kitchenStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ✅ ------------------- DINE IN -------------------
    if (orderTypeLower == 'dine in') {
      orderData['area'] = selectedArea;
      orderData['tableId'] = selectedTableId;
      orderData['waiterId'] = selectedWaiterId;

      batch.update(
        FirebaseFirestore.instance
            .collection('tables')
            .doc(selectedTableId),
        {'status': 'occupied'},
      );
    }

    // ✅ ------------------- PICKUP -------------------
    else if (orderTypeLower == 'pickup') {
      final now = DateTime.now();

      orderData['customerName'] = customerNameController.text.trim();
      orderData['customerPhone'] = customerPhoneController.text.trim();
      orderData['pickupDate'] =
          "${now.day}-${now.month}-${now.year}";
      orderData['pickupTime'] =
          "${now.hour}:${now.minute}";
    }

    // ✅ ------------------- DELIVERY -------------------
    else if (orderTypeLower == 'delivery') {
      orderData['customerName'] = customerNameController.text.trim();
      orderData['customerPhone'] = customerPhoneController.text.trim();
      orderData['customerAddress'] =
          customerAddressController.text.trim();

      // ✅ If delivery man selected manually
      if (selectedDeliveryManId != null) {
        orderData['deliveryManId'] = selectedDeliveryManId;
        orderData['deliveryCandidates'] = [selectedDeliveryManId];
      } 
      // ✅ Otherwise assign all delivery men
      else {
        final deliveryMenSnap = await FirebaseFirestore.instance
            .collection('staff')
            .where('shopId', isEqualTo: widget.shopId)
            .get();

        final candidates = deliveryMenSnap.docs.where((d) {
          final role =
              (d.data())['role']
                  .toString()
                  .toLowerCase();
          return role.contains('delivery');
        }).map((d) => d.id).toList();

        orderData['deliveryCandidates'] = candidates;
      }
    }

    // ✅ SAVE ORDER
    batch.set(orderDocRef, orderData);
    await batch.commit();

    setState(() {
      cartItems.clear();
      selectedArea = null;
      selectedTableId = null;
      selectedWaiterId = null;
      selectedDeliveryManId = null;
      customerNameController.clear();
      customerPhoneController.clear();
      customerAddressController.clear();
    });

    if (orderTypeLower == 'dine in') {
      _fetchAreas();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order $orderNumber placed successfully ✅'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to process order: $e')),
    );
  }
}


  Widget _buildCompactDropdown({
    required String hint,
    required List<DropdownMenuItem<dynamic>> items,
    dynamic value,
    required ValueChanged<dynamic>? onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      height: maxLines == 1 ? 44 : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildAreaDropdown() => _buildCompactDropdown(
    hint: 'Select area',
    items: availableAreas
        .map(
          (a) => DropdownMenuItem(
            value: a,
            child: Text(a, style: const TextStyle(fontSize: 13)),
          ),
        )
        .toList(),
    value: selectedArea,
    onChanged: (v) {
      if (v == null) return;
      setState(() => selectedArea = v);
      _fetchAvailableTablesForArea(v);
    },
  );

  Widget _buildTableDropdown() => _buildCompactDropdown(
    hint: 'Select table',
    items: availableTables
        .map(
          (t) => DropdownMenuItem(
            value: t['id'],
            child: Text(
              'Table ${t['tableNumber']}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        )
        .toList(),
    value: selectedTableId,
    onChanged: isLoadingTables || selectedArea == null
        ? null
        : (v) => setState(() => selectedTableId = v),
  );

  Widget _buildWaiterDropdown() => SizedBox(
    height: 44,
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff')
          .where('shopId', isEqualTo: widget.shopId)
          .where('role', isEqualTo: 'waiter')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        return _buildCompactDropdown(
          hint: 'Select waiter',
          items: docs
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    (d.data() as Map<String, dynamic>)['name'] ?? 'Unnamed',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          value: selectedWaiterId,
          onChanged: (v) => setState(() => selectedWaiterId = v),
        );
      },
    ),
  );
Widget _buildDeliveryManDropdown() => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('staff')
        .where('shopId', isEqualTo: widget.shopId)
        .snapshots(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 50,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }

      if (!snap.hasData || snap.data!.docs.isEmpty) {
        return _buildCompactDropdown(
          hint: 'No staff found',
          items: const [],
          value: null,
          onChanged: null,
        );
      }

      // ✅ FILTER DELIVERY STAFF IN DART
      final deliveryDocs = snap.data!.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final role = (data['role'] ?? '').toString().toLowerCase();
        return role.contains('delivery'); // matches: delivery, delivery man
      }).toList();

      if (deliveryDocs.isEmpty) {
        return _buildCompactDropdown(
          hint: 'No delivery man found',
          items: const [],
          value: null,
          onChanged: null,
        );
      }

      // ✅ SAFETY FIX: reset value if invalid
      if (selectedDeliveryManId != null &&
          !deliveryDocs.any((d) => d.id == selectedDeliveryManId)) {
        selectedDeliveryManId = null;
      }

      return _buildCompactDropdown(
        hint: 'Select delivery man',
        items: deliveryDocs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return DropdownMenuItem(
            value: d.id,
            child: Text(
              data['name'] ?? 'Unnamed',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          );
        }).toList(),
        value: selectedDeliveryManId,
        onChanged: (v) => setState(() => selectedDeliveryManId = v),
      );
    },
  ),
);


  Widget _buildCategoryButton(String name, String id) {
    final selected = selectedCategoryId == id;
    return GestureDetector(
      onTap: () => setState(() => selectedCategoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade500],
                )
              : LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade200],
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.shade900.withOpacity(0.6),
                    offset: const Offset(0, 5),
                    blurRadius: 12,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade400,
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-3, -3),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(DocumentSnapshot doc, Uint8List? imageBytes) {
    final data = doc.data() as Map<String, dynamic>;
    final price = data['price'] ?? 0;
    final variations = List<Map<String, dynamic>>.from(
      data['variations'] ?? [],
    );
    final hasVariants = variations.isNotEmpty;

    return GestureDetector(
      onTap: () => _handleItemTap(doc),
      child: PhysicalModel(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.green.shade300,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.green.shade50],
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Color(0xFFF5F5F5),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.cover)
                      : const Icon(
                          Icons.fastfood_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          data['name'] ?? 'Unnamed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13452E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Rs $price",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (hasVariants) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.menu,
                                size: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartTable() => LayoutBuilder(
    builder: (context, constraints) {
      return cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No items in cart",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Item',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Price',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Qty',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Action',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? 'Unnamed',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if ((item['variantName'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        item['variantName'].toString(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  "Rs ${item['price']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  '${item['qty']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () => decreaseItemQty(index),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    onPressed: () => increaseItemQty(index),
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
    },
  );

  Widget _buildActionButtons() {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.32,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$itemCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Rs ${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GST (2.5%):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Rs ${gstAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF13452E),
                      ),
                    ),
                    Text(
                      'Rs ${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF13452E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitOrder(printAfter: false),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text(
                    'Place Order',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitOrder(printAfter: true),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text(
                    'Print & Order',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                child: ElevatedButton(
                  onPressed: _printOnly,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.print, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: Text("${widget.orderType} - POS"),
          backgroundColor: const Color(0xFF13452E),
          elevation: 10,
          shadowColor: Colors.green.shade900.withOpacity(0.5),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight - 100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------- Left Panel: Items -------------------
              Expanded(
                flex: screenWidth > 1200 ? 3 : 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Search Bar
                      SizedBox(
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey.shade200,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-5, -5),
                                blurRadius: 15,
                              ),
                              BoxShadow(
                                color: Colors.black12,
                                offset: Offset(5, 5),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: "Search items...",
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.green,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Categories
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildCategoryButton("All", "all"),
                            ...categoryMap.entries.map(
                              (e) => _buildCategoryButton(e.value, e.key),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Items Grid
                      SizedBox(
                        height: screenHeight * 0.55,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('items')
                              .where('shopId', isEqualTo: widget.shopId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allDocs = snapshot.data!.docs;
                            final items = allDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final matchesCategory =
                                  selectedCategoryId == 'all' ||
                                  data['categoryId'] == selectedCategoryId;
                              final matchesSearch = (data['name'] ?? '')
                                  .toLowerCase()
                                  .contains(
                                    searchController.text.trim().toLowerCase(),
                                  );
                              return matchesCategory && matchesSearch;
                            }).toList();

                            if (items.isEmpty) {
                              return const Center(
                                child: Text(
                                  "No items found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: screenWidth > 1200
                                        ? 5
                                        : screenWidth > 800
                                        ? 4
                                        : 3,
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final doc = items[index];
                                final data = doc.data() as Map<String, dynamic>;
                                Uint8List? imageBytes;
                                if (data['imageBase64'] != null) {
                                  try {
                                    imageBytes = base64Decode(
                                      data['imageBase64'],
                                    );
                                  } catch (_) {}
                                }
                                return _buildItemCard(doc, imageBytes);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ------------------- Right Panel: Cart & Details -------------------
              Expanded(
                flex: screenWidth > 1200 ? 2 : 1,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade900.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ------------------- Order Info -------------------
                      SizedBox(
                        height: screenHeight * 0.22,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Order Number
                              Text(
                                widget.existingOrderData != null
                                    ? widget.existingOrderData!['orderNumber'] ??
                                          ''
                                    : 'Order#${lastOrderNumber + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Dropdowns
                            if (widget.orderType.toLowerCase() == 'dine in')
  Row(
    children: [
      Expanded(child: _buildAreaDropdown()),
      const SizedBox(width: 8),
      Expanded(child: _buildTableDropdown()),
      const SizedBox(width: 8),
      Expanded(child: _buildWaiterDropdown()),
    ],
  ),

if (widget.orderType.toLowerCase() == 'delivery')
  Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: customerNameController,
              hint: 'Name',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTextField(
              controller: customerPhoneController,
              hint: 'Phone',
              keyboardType: TextInputType.phone,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),

      Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: customerAddressController,
              hint: 'Address',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 1,
            child: _buildDeliveryManDropdown(), // ✅ Optional
          ),
        ],
      ),
    ],
  ),


if (widget.orderType.toLowerCase() == 'pickup')
  Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: customerNameController,
              hint: 'Name',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTextField(
              controller: customerPhoneController,
              hint: 'Phone',
              keyboardType: TextInputType.phone,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      _buildTextField(
        controller: customerAddressController,
        hint: 'Pickup Time / Notes',
      ),
    ],
  ),


                              // Existing Order Items
                             
                            ],
                          ),
                        ),
                      ),

                      // ------------------- Cart Table for New Items -------------------
                      SizedBox(
                        height: screenHeight * 0.28,
                        child: _buildCartTable(),
                      ),

                      // ------------------- Action Buttons -------------------
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------- Dropdown Helper -------------------
  Widget _buildDropdown({
    required String label,
    required String value,
    required void Function(String?) onChanged,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            value: value.isNotEmpty ? value : null,
            hint: Text('Select $label'),
            onChanged: onChanged,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
          ),
        ),
      ],
    );
  }
}
