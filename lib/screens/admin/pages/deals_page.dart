// ignore_for_file: unnecessary_cast, deprecated_member_use, empty_catches, curly_braces_in_flow_control_structures, unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DealsPage extends StatefulWidget {
  final String shopId;
  const DealsPage({super.key, required this.shopId});

  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage>
    with SingleTickerProviderStateMixin {
  // --- Controllers ---
  final TextEditingController searchController = TextEditingController();
  final TextEditingController dealNameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController dealPriceController = TextEditingController();
  final TextEditingController prepTimeController = TextEditingController();

  // --- Firestore ---
  late final CollectionReference dealsCollection;
  late final CollectionReference itemsCollection;
  late final CollectionReference inventoryCollection;
  late final CollectionReference categoriesCollection;

  // --- UI State ---
  bool panelOpen = false;
  double panelWidth = 650;
  AnimationController? panelAnim;
  Animation<Offset>? panelOffset;

  Uint8List? pickedImageBytes;
  String? imageBase64;
  bool isAvailable = true;
  bool isLoadingInventory = false;
  String? selectedDealId;

  final ImagePicker picker = ImagePicker();

  List<Map<String, dynamic>> dealItems = [];
  List<Map<String, dynamic>> availableCategories = [];
  List<Map<String, dynamic>> availableMenuItems = [];

  final formKey = GlobalKey<FormState>();

  static const List<String> units = [
    'kg',
    'grams',
    'units',
    'pieces',
    'litre',
    'ml',
    'packets',
    'boxes',
    'bags',
    'jars',
    'cans',
    'bottles',
    'dozen',
    'bundles',
    'trays',
    'slabs',
    'sachets',
  ];

  final Color colorStart = const Color(0xFF13452E);
  final Color colorEnd = const Color(0xFF4CAF50);
  final Color bgLight = const Color(0xFFF8FBF5);

  @override
  void initState() {
    super.initState();
    dealsCollection = FirebaseFirestore.instance.collection('deals');
    itemsCollection = FirebaseFirestore.instance.collection('items');
    inventoryCollection = FirebaseFirestore.instance.collection('inventory');
    categoriesCollection = FirebaseFirestore.instance.collection('categories');

    panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    panelOffset = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: panelAnim!, curve: Curves.easeOutCubic));

    loadCategories();
  }

  @override
  void dispose() {
    searchController.dispose();
    dealNameController.dispose();
    descController.dispose();
    dealPriceController.dispose();
    prepTimeController.dispose();
    panelAnim?.dispose();
    super.dispose();
  }

  // --- UTILITIES ---
  T? safeCast<T>(dynamic value) => value is T ? value : null;

  String safeSubstring(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
    );
  }

  TextStyle labelStyle = const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );

  Future<void> pickImage() async {
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        pickedImageBytes = bytes;
        imageBase64 = base64Encode(bytes);
      });
    }
  }

  // --- LOAD CATEGORIES ---
  Future<void> loadCategories() async {
    try {
      final snapshot = await categoriesCollection
          .where('shopId', isEqualTo: widget.shopId)
          .get();
      availableCategories = snapshot.docs.map((doc) {
        final data = safeCast<Map<String, dynamic>>(doc.data());
        return {'id': doc.id, 'name': data?['name'] ?? 'Unknown'};
      }).toList();
      setState(() {});
    } catch (e) {
      debugPrint('Categories load error: $e');
    }
  }

  // --- LOAD INVENTORY BY CATEGORY ---
  Future<List<Map<String, dynamic>>> loadCategoryInventory(
    String categoryName,
  ) async {
    setState(() => isLoadingInventory = true);
    List<Map<String, dynamic>> inventoryItems = [];
    try {
      final snapshot = await inventoryCollection
          .where('shopId', isEqualTo: widget.shopId)
          .where('category', isEqualTo: categoryName)
          .get();
      inventoryItems = snapshot.docs
          .map((doc) {
            final data = safeCast<Map<String, dynamic>>(doc.data());
            return {
              'id': doc.id,
              'name': data?['name'] ?? 'Unknown',
              'quantity': (data?['quantity'] as num?)?.toDouble() ?? 0.0,
              'unit': data?['unit'] ?? 'kg',
            };
          })
          .where((inv) => inv['quantity'] > 0)
          .toList();
    } catch (e) {
      debugPrint('Inventory load error: $e');
    } finally {
      setState(() => isLoadingInventory = false);
    }
    return inventoryItems;
  }

  // --- LOAD AVAILABLE MENU ITEMS ---
  Future<void> loadAvailableMenuItems() async {
    try {
      final snapshot = await itemsCollection
          .where('shopId', isEqualTo: widget.shopId)
          .where('isAvailable', isEqualTo: true)
          .get();
      availableMenuItems = snapshot.docs.map((doc) {
        final data = safeCast<Map<String, dynamic>>(doc.data());
        return {
          'id': doc.id,
          'name': data?['name'] ?? 'Unknown',
          'price': data?['price']?.toString() ?? '0',
          'imageBase64': data?['imageBase64'] ?? '',
        };
      }).toList();
      setState(() {});
    } catch (e) {
      debugPrint('Menu items load error: $e');
    }
  }

  // --- PANEL CONTROLS ---
  void openPanel([String? dealId]) async {
    clearForm();
    await loadAvailableMenuItems();
    if (dealId != null) {
      await loadDeal(dealId);
    }
    setState(() => panelOpen = true);
    panelAnim?.forward();
  }

  void closePanel() {
    panelAnim?.reverse().whenComplete(() {
      setState(() {
        panelOpen = false;
        selectedDealId = null;
        clearForm();
      });
    });
  }

  void clearForm() {
    dealNameController.clear();
    descController.clear();
    dealPriceController.clear();
    prepTimeController.clear();
    pickedImageBytes = null;
    imageBase64 = null;
    dealItems.clear();
    isAvailable = true;
  }

  Future<void> loadDeal(String dealId) async {
    try {
      final doc = await dealsCollection.doc(dealId).get();
      if (!doc.exists) return;
      final data = safeCast<Map<String, dynamic>>(doc.data());
      if (data == null) return;

      dealNameController.text = data['name'] ?? '';
      descController.text = data['description'] ?? '';
      dealPriceController.text = data['price']?.toString() ?? '';
      prepTimeController.text = data['prepTime'] ?? '';
      isAvailable = data['isAvailable'] == true;
      selectedDealId = dealId;

      final itemsRaw = data['items'] as List? ?? [];
      for (var item in itemsRaw) {
        final itemMap = safeCast<Map<String, dynamic>>(item);
        if (itemMap == null) continue;

        List<Map<String, dynamic>> selectedInventories = [];
        final inventoriesRaw = itemMap['inventories'] as List? ?? [];
        for (var inv in inventoriesRaw) {
          final invMap = safeCast<Map<String, dynamic>>(inv);
          if (invMap == null) continue;
          selectedInventories.add({
            'inventoryId': invMap['inventoryId'],
            'inventoryName': invMap['inventoryName'],
            'inventoryQty': invMap['inventoryQty']?.toString() ?? '0',
            'inventoryUnit': invMap['inventoryUnit'],
          });
        }

        List<Map<String, dynamic>> availableInventoryItems = [];
        final categoryName = itemMap['selectedCategoryName']?.toString() ?? '';
        if (categoryName.isNotEmpty) {
          availableInventoryItems = await loadCategoryInventory(categoryName);
        }

        dealItems.add({
          'itemId': itemMap['itemId'] ?? '',
          'itemName': itemMap['itemName'] ?? '',
          'quantity': itemMap['quantity']?.toString() ?? '',
          'selectedCategoryId': itemMap['selectedCategoryId'],
          'selectedCategoryName': categoryName,
          'availableInventoryItems': availableInventoryItems,
          'selectedInventories': selectedInventories,
        });
      }

      if (data['imageBase64'] != null) {
        imageBase64 = data['imageBase64'];
        pickedImageBytes = base64Decode(imageBase64!);
      }
      setState(() {});
    } catch (e) {
      debugPrint('Load deal error: $e');
    }
  }

  // --- DEAL ITEM MANAGEMENT ---
  void addDealItem() {
    setState(() {
      dealItems.add({
        'itemId': '',
        'itemName': '',
        'quantity': '',
        'selectedCategoryId': null,
        'selectedCategoryName': null,
        'availableInventoryItems': <Map<String, dynamic>>[],
        'selectedInventories': <Map<String, dynamic>>[],
      });
    });
  }

  void removeDealItem(int idx) {
    setState(() => dealItems.removeAt(idx));
  }

  Future<void> onCategorySelected(int itemIndex, String? categoryId) async {
    if (categoryId == null) return;
    final category = availableCategories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {},
    );
    if (category.isEmpty) return;

    final inventoryList = await loadCategoryInventory(category['name']);
    setState(() {
      dealItems[itemIndex]['selectedCategoryId'] = categoryId;
      dealItems[itemIndex]['selectedCategoryName'] = category['name'];
      dealItems[itemIndex]['availableInventoryItems'] = inventoryList;
      dealItems[itemIndex]['selectedInventories'] = <Map<String, dynamic>>[];
    });
  }

  void addInventoryToItem(int itemIndex) {
    final item = dealItems[itemIndex];
    final availableInventories =
        item['availableInventoryItems'] as List<Map<String, dynamic>>;
    final selectedInventoryIds = (item['selectedInventories'] as List)
        .map((inv) => inv['inventoryId'])
        .toList();
    final invToAdd = availableInventories.firstWhere(
      (inv) => !selectedInventoryIds.contains(inv['id']),
      orElse: () => {},
    );
    if (invToAdd.isEmpty) return;

    setState(() {
      (dealItems[itemIndex]['selectedInventories'] as List).add({
        'inventoryId': invToAdd['id'],
        'inventoryName': invToAdd['name'],
        'inventoryQty': '0',
        'inventoryUnit': invToAdd['unit'] ?? 'kg',
      });
    });
  }

  void removeInventoryFromItem(int itemIndex, int invIndex) {
    setState(
      () => (dealItems[itemIndex]['selectedInventories'] as List).removeAt(
        invIndex,
      ),
    );
  }

  // --- SAVE DEAL ---
  Future<void> saveDeal() async {
    if (!formKey.currentState!.validate()) return;
    if (imageBase64 == null || imageBase64!.isEmpty) {
      showError('Please upload an image for the deal');
      return;
    }
    if (dealItems.isEmpty) {
      showError('Please add at least 1 menu item');
      return;
    }

    final itemsData = dealItems.map((item) {
      final inventoriesData = (item['selectedInventories'] as List).map((inv) {
        return {
          'inventoryId': inv['inventoryId'],
          'inventoryName': inv['inventoryName'],
          'inventoryQty': double.tryParse(inv['inventoryQty'] ?? '0') ?? 0.0,
          'inventoryUnit': inv['inventoryUnit'],
        };
      }).toList();

      return {
        'itemId': item['itemId'],
        'itemName': item['itemName'],
        'quantity': double.tryParse(item['quantity'] ?? '0') ?? 0.0,
        'inventories': inventoriesData,
      };
    }).toList();

    final docData = {
      'shopId': widget.shopId,
      'name': dealNameController.text.trim(),
      'description': descController.text.trim(),
      'price': double.tryParse(dealPriceController.text) ?? 0.0,
      'items': itemsData,
      'prepTime': prepTimeController.text.trim(),
      'isAvailable': isAvailable,
      'imageBase64': imageBase64,
      if (selectedDealId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (selectedDealId != null) {
        await dealsCollection
            .doc(selectedDealId)
            .set(docData, SetOptions(merge: true));
      } else {
        await dealsCollection.add(docData);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedDealId == null ? 'Deal added!' : 'Deal updated!',
          ),
        ),
      );
      closePanel();
    } catch (e) {
      showError('Error saving deal: $e');
    }
  }

  void showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void deleteDeal(String dealId) => dealsCollection.doc(dealId).delete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'Deals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colorStart, colorEnd]),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Color(0xFF13452E)),
                        decoration: InputDecoration(
                          hintText: 'Search deals...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF13452E),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => openPanel(),
                      icon: const Icon(Icons.add, color: Color(0xFF13452E)),
                      label: const Text(
                        'Add Deal',
                        style: TextStyle(color: Color(0xFF13452E)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(child: buildDealsTable()),
              ],
            ),
          ),
          if (panelOpen) buildAddDealPanel(context),
        ],
      ),
    );
  }

  Widget buildDealsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: dealsCollection
          .where('shopId', isEqualTo: widget.shopId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
          );
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No deals yet. Add your first deal!',
                style: TextStyle(fontSize: 18, color: Color(0xFF13452E)),
              ),
            ),
          );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(colorStart),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            columns: const [
              DataColumn(label: Text('Image')),
              DataColumn(label: Text('Deal')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Items')),
              DataColumn(label: Text('Inventory')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: docs.map((doc) {
              final data = safeCast<Map<String, dynamic>>(doc.data());
              if (data == null)
                return const DataRow(cells: [DataCell(Text('Error'))]);
              final itemsRaw = data['items'] as List? ?? [];
              String inventoryText = itemsRaw.isEmpty
                  ? 'None'
                  : itemsRaw
                        .map((item) {
                          final inventories =
                              item['inventories'] as List? ?? [];
                          return inventories
                              .map(
                                (inv) =>
                                    '${inv['inventoryName']} ${inv['inventoryQty']}${inv['inventoryUnit']}',
                              )
                              .join(', ');
                        })
                        .join(', ');

              Uint8List? imageBytes;
              if (data['imageBase64'] != null)
                imageBytes = base64Decode(data['imageBase64']);

              return DataRow(
                cells: [
                  DataCell(
                    imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              imageBytes,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.local_offer,
                            color: Color(0xFF13452E),
                          ),
                  ),
                  DataCell(Text(safeSubstring(data['name']?.toString(), 20))),
                  DataCell(Text(data['price']?.toString() ?? '0')),
                  DataCell(Text(itemsRaw.length.toString())),
                  DataCell(Text(safeSubstring(inventoryText, 30))),
                  DataCell(
                    Text(data['isAvailable'] == true ? 'Available' : 'Hidden'),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => openPanel(doc.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteDeal(doc.id),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // --- ADD DEAL PANEL ---
  Widget buildAddDealPanel(BuildContext context) {
    return SlideTransition(
      position: panelOffset!,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: panelWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colorStart, colorEnd]),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
            ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDealId != null ? 'Edit Deal' : 'Add Deal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: closePanel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: dealNameController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Deal Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: inputDecoration('Description'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dealPriceController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Price'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: prepTimeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Preparation Time'),
                    ),
                    const SizedBox(height: 20),
                    Text('Deal Items', style: labelStyle),
                    const SizedBox(height: 8),
                    ...buildDealItems(),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: addDealItem,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorStart,
                      ),
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white),
                        ),
                        child: imageBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  base64Decode(imageBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: saveDeal,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Deal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colorStart,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> buildDealItems() {
    return dealItems.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      List<Map<String, dynamic>> selectedInventories =
          List<Map<String, dynamic>>.from(item['selectedInventories'] ?? []);
      List<Map<String, dynamic>> availableInventoryItems =
          List<Map<String, dynamic>>.from(
            item['availableInventoryItems'] ?? [],
          );
      String? selectedCategoryId = item['selectedCategoryId']?.toString();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SELECT MENU ITEM
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: (item['itemId'] ?? '').toString().isNotEmpty
                        ? item['itemId'].toString()
                        : null,
                    items: availableMenuItems.map((menuItem) {
                      return DropdownMenuItem<String>(
                        value: menuItem['id'].toString(),
                        child: Text(
                          menuItem['name'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selected = availableMenuItems.firstWhere(
                        (i) => i['id'] == val,
                        orElse: () => {},
                      );
                      setState(() {
                        dealItems[idx] = {
                          ...dealItems[idx],
                          'itemId': val,
                          'itemName': selected['name'],
                          'quantity': dealItems[idx]['quantity'] ?? '',
                          'selectedCategoryId': null,
                          'selectedCategoryName': null,
                          'availableInventoryItems': <Map<String, dynamic>>[],
                          'selectedInventories': <Map<String, dynamic>>[],
                        };
                      });
                    },
                    decoration: inputDecoration('Select Item'),
                    dropdownColor: colorStart,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: item['quantity']?.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('Qty'),
                    onChanged: (val) => dealItems[idx]['quantity'] = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => removeDealItem(idx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // SELECT CATEGORY
            DropdownButtonFormField<String>(
              value: selectedCategoryId,
              hint: const Text(
                'Select Inventory Category',
                style: TextStyle(color: Colors.white70),
              ),
              items: availableCategories
                  .map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat['id'].toString(), // <-- CAST TO STRING
                      child: Text(
                        cat['name'].toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),

              onChanged: (val) => onCategorySelected(idx, val),
              decoration: inputDecoration('Category'),
              dropdownColor: colorStart,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (isLoadingInventory)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              ...selectedInventories.asMap().entries.map((invEntry) {
                final invIdx = invEntry.key;
                final inv = invEntry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: inv['inventoryId']?.toString(),
                          items: availableInventoryItems
                              .map(
                                (invItem) => DropdownMenuItem<String>(
                                  value: invItem['id']
                                      .toString(), // cast to String
                                  child: Text(
                                    '${invItem['name']} ${invItem['quantity']} ${invItem['unit']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),

                          onChanged: (val) {
                            final selectedInv = availableInventoryItems
                                .firstWhere(
                                  (x) => x['id'] == val,
                                  orElse: () => {},
                                );
                            setState(() {
                              dealItems[idx]['selectedInventories'][invIdx] = {
                                ...inv,
                                'inventoryId': val,
                                'inventoryName': selectedInv['name'],
                                'inventoryUnit': selectedInv['unit'] ?? 'kg',
                              };
                            });
                          },
                          decoration: inputDecoration('Inventory Item'),
                          dropdownColor: colorStart,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: inv['inventoryQty']?.toString() ?? '0',
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Qty'),
                          onChanged: (val) =>
                              dealItems[idx]['selectedInventories'][invIdx]['inventoryQty'] =
                                  val,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: units.contains(inv['inventoryUnit'])
                              ? inv['inventoryUnit']
                              : units.first,
                          items: units
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    unit,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(
                            () =>
                                dealItems[idx]['selectedInventories'][invIdx]['inventoryUnit'] =
                                    val ?? 'kg',
                          ),
                          decoration: inputDecoration('Unit'),
                          dropdownColor: colorStart,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => removeInventoryFromItem(idx, invIdx),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ElevatedButton.icon(
              onPressed: () => addInventoryToItem(idx),
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF13452E),
              ),
              label: const Text('Add Inventory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                foregroundColor: colorStart,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
