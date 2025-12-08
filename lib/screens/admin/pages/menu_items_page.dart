// ignore_for_file: unnecessary_cast, deprecated_member_use, empty_catches, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MenuItemsPage extends StatefulWidget {
  final String shopId;
  const MenuItemsPage({super.key, required this.shopId});

  @override
  State<MenuItemsPage> createState() => MenuItemsPageState();
}

class MenuItemsPageState extends State<MenuItemsPage>
    with SingleTickerProviderStateMixin {
  late final CollectionReference categoriesCollection;
  late final CollectionReference itemsCollection;
  late final CollectionReference inventoryCollection;
  final TextEditingController searchController = TextEditingController();
  bool panelOpen = false;
  double panelWidth = 650;
  AnimationController? panelAnim;
  Animation<Offset>? panelOffset;
  final formKey = GlobalKey<FormState>();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController singlePriceController = TextEditingController();
  final TextEditingController prepTimeController = TextEditingController();

  // Multiple inventories for variations and base items
  List<Map<String, dynamic>> variations = [];
  List<Map<String, dynamic>> baseItemInventories = [];
  String? selectedCategoryId;
  String? selectedCategoryName;
  bool isAvailable = true;
  Uint8List? pickedImageBytes;
  String? imageBase64;
  final ImagePicker picker = ImagePicker();
  String? selectedItemId;
  List<Map<String, dynamic>> availableInventoryItems = [];
  bool isLoadingInventory = false;
  String? selectedDisplayId;
  String? selectedDisplayName;

  late final CollectionReference displaysCollection;

  final Color colorStart = const Color(0xFF13452E);
  final Color colorEnd = const Color(0xFF4CAF50);
  final Color bgLight = const Color(0xFFF8FBF5);

  static const List<String> units = [
    'units',
    'pieces',
    'kg',
    'grams',
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
    'cartons',
    'pounds',
    'oz',
    'gallons',
    'quarts',
    'pints',
    'slices',
    'sticks',
    'bars',
    'tubes',
    'rolls',
    'sheets',
    'packs',
  ];

  @override
  void initState() {
    super.initState();
    categoriesCollection = FirebaseFirestore.instance.collection('categories');
    itemsCollection = FirebaseFirestore.instance.collection('items');
    inventoryCollection = FirebaseFirestore.instance.collection('inventory');
    panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    panelOffset = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: panelAnim!, curve: Curves.easeOutCubic));
    displaysCollection = FirebaseFirestore.instance.collection('displays');
  }

  @override
  void dispose() {
    searchController.dispose();
    itemNameController.dispose();
    descController.dispose();
    singlePriceController.dispose();
    prepTimeController.dispose();
    panelAnim?.dispose();
    super.dispose();
  }

  T? safeCast<T>(dynamic value) {
    if (value == null) return null;
    if (value is T) return value;
    return null;
  }

  String safeSubstring(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  Future<void> loadCategoryInventory(String categoryName) async {
    setState(() => isLoadingInventory = true);
    try {
      final snapshot = await inventoryCollection
          .where('shopId', isEqualTo: widget.shopId)
          .where('category', isEqualTo: categoryName)
          .get();
      availableInventoryItems.clear();
      for (var doc in snapshot.docs) {
        final data = safeCast<Map<String, dynamic>>(doc.data());
        if (data == null) continue;
        final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        if (qty > 0) {
          availableInventoryItems.add({
            'id': doc.id,
            'name': data['name']?.toString() ?? 'Unknown',
            'quantity': qty,
            'unit': data['unit']?.toString() ?? 'kg',
          });
        }
      }
    } catch (e) {
      debugPrint('Inventory error: $e');
    } finally {
      if (mounted) setState(() => isLoadingInventory = false);
    }
  }

  void openPanel(String? itemId) async {
    variations.clear();
    baseItemInventories.clear();
    if (itemId != null) {
      try {
        final doc = await itemsCollection.doc(itemId).get();
        if (!doc.exists) return;
        final data = safeCast<Map<String, dynamic>>(doc.data());
        if (data == null) return;
        itemNameController.text = data['name']?.toString() ?? '';
        descController.text = data['description']?.toString() ?? '';
        singlePriceController.text = data['price']?.toString() ?? '';
        prepTimeController.text = (data['prepTime'] is int)
            ? data['prepTime'].toString()
            : '';
        selectedCategoryId = data['categoryId']?.toString();
        selectedCategoryName = data['categoryName']?.toString();
        isAvailable = data['isAvailable'] ?? true;

        final baseInvRaw = data['inventoryRequirements'];
        if (baseInvRaw is List) {
          baseItemInventories = List<Map<String, dynamic>>.from(
            baseInvRaw,
          ).where((v) => v.isNotEmpty).toList();
        }

        final varsRaw = data['variations'];
        if (varsRaw is List) {
          variations = (varsRaw as List)
              .map((v) {
                final vMap = safeCast<Map<String, dynamic>>(v);
                if (vMap == null) return <String, dynamic>{};
                final invReqs =
                    (vMap['inventoryRequirements'] as List?)
                        ?.map((inv) => Map<String, dynamic>.from(inv))
                        .toList() ??
                    [];
                return {
                  'name': vMap['name']?.toString() ?? '',
                  'price': vMap['price']?.toString() ?? '',
                  'inventoryRequirements': invReqs,
                };
              })
              .where((v) => v.isNotEmpty)
              .toList();
        }

        final imgData = data['imageBase64']?.toString();
        if (imgData != null && imgData.isNotEmpty) {
          try {
            imageBase64 = imgData;
            pickedImageBytes = base64Decode(imgData);
          } catch (e) {}
        }
      } catch (e) {
        debugPrint('Error loading item $itemId: $e');
      }
    }

    if (selectedCategoryName != null) {
      await loadCategoryInventory(selectedCategoryName!);
    }

    if (mounted) {
      setState(() => selectedItemId = itemId);
      panelOpen = true;
      panelAnim?.forward();
    }
  }

  void closePanel() {
    panelAnim?.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          panelOpen = false;
          clearForm();
          selectedItemId = null;
        });
      }
    });
  }

  void clearForm() {
    itemNameController.clear();
    descController.clear();
    singlePriceController.clear();
    prepTimeController.clear();
    variations.clear();
    baseItemInventories.clear();
    pickedImageBytes = null;
    imageBase64 = null;
    selectedCategoryId = null;
    selectedCategoryName = null;
    isAvailable = true;
    selectedDisplayId = null;
    selectedDisplayName = null;
  }

  void addVariation() {
    if (mounted) {
      setState(() {
        variations.add({'name': '', 'price': '', 'inventoryRequirements': []});
      });
    }
  }

  void addBaseInventory() {
    if (mounted) {
      setState(() {
        baseItemInventories.add({
          'inventoryId': '',
          'inventoryName': '',
          'inventoryQty': '',
          'inventoryUnit': 'kg',
        });
      });
    }
  }

  void addVariationInventory(int varIndex) {
    if (mounted) {
      setState(() {
        variations[varIndex]['inventoryRequirements'].add({
          'inventoryId': '',
          'inventoryName': '',
          'inventoryQty': '',
          'inventoryUnit': 'kg',
        });
      });
    }
  }

  void removeVariation(int index) {
    if (mounted && index >= 0 && index < variations.length) {
      setState(() {
        variations.removeAt(index);
      });
    }
  }

  void removeBaseInventory(int index) {
    if (mounted && index >= 0 && index < baseItemInventories.length) {
      setState(() {
        baseItemInventories.removeAt(index);
      });
    }
  }

  void removeVariationInventory(int varIndex, int invIndex) {
    if (mounted &&
        varIndex >= 0 &&
        varIndex < variations.length &&
        invIndex >= 0 &&
        invIndex <
            (variations[varIndex]['inventoryRequirements']?.length ?? 0)) {
      setState(() {
        variations[varIndex]['inventoryRequirements'].removeAt(invIndex);
      });
    }
  }

  Future<void> pickImage() async {
    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          pickedImageBytes = bytes;
          imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> saveItem() async {
    if (!formKey.currentState!.validate()) return;

    // ✅ CATEGORY VALIDATION
    if (selectedCategoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
      }
      return;
    }

    // ✅ DISPLAY VALIDATION (FIXED POSITION)
    if (selectedDisplayId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a display')),
        );
      }
      return;
    }

    // ✅ IMAGE VALIDATION
    if (imageBase64 == null || imageBase64!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      }
      return;
    }

    // ✅ MAP BASE INVENTORIES
    List<Map<String, dynamic>> baseInvData = baseItemInventories
        .where((inv) => (inv['inventoryId']?.toString() ?? '').isNotEmpty)
        .map(
          (inv) => {
            'inventoryId': inv['inventoryId'].toString(),
            'inventoryName': inv['inventoryName']?.toString() ?? '',
            'inventoryQty':
                double.tryParse(inv['inventoryQty'].toString()) ?? 0.0,
            'inventoryUnit': inv['inventoryUnit']?.toString() ?? 'kg',
          },
        )
        .toList();

    // ✅ MAP VARIATIONS + INVENTORIES
    List<Map<String, dynamic>> variationsData = variations
        .where(
          (v) =>
              (v['name']?.toString().trim() ?? '').isNotEmpty &&
              (v['price']?.toString().trim() ?? '').isNotEmpty,
        )
        .map(
          (v) => {
            'name': v['name'].toString(),
            'price': double.tryParse(v['price'].toString()) ?? 0.0,
            'inventoryRequirements': (v['inventoryRequirements'] as List)
                .where(
                  (inv) => (inv['inventoryId']?.toString() ?? '').isNotEmpty,
                )
                .map(
                  (inv) => {
                    'inventoryId': inv['inventoryId'].toString(),
                    'inventoryName': inv['inventoryName']?.toString() ?? '',
                    'inventoryQty':
                        double.tryParse(inv['inventoryQty'].toString()) ?? 0.0,
                    'inventoryUnit': inv['inventoryUnit']?.toString() ?? 'kg',
                  },
                )
                .toList(),
          },
        )
        .toList();

    // ✅ FINAL FIRESTORE DATA
    final docData = {
      'shopId': widget.shopId,
      'categoryId': selectedCategoryId,
      'categoryName': selectedCategoryName ?? 'Unknown',

      // ✅ DISPLAY ROUTING (FIXED & REQUIRED)
      'displayId': selectedDisplayId,
      'displayName': selectedDisplayName,

      'name': itemNameController.text.trim(),
      'description': descController.text.trim(),
      'price': double.tryParse(singlePriceController.text) ?? 0.0,
      'variations': variationsData,
      'inventoryRequirements': baseInvData,
      'prepTime': int.tryParse(prepTimeController.text.trim()) ?? 0,
      'isAvailable': isAvailable,
      'imageBase64': imageBase64,
      if (selectedItemId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      // ✅ UPDATE EXISTING ITEM
      if (selectedItemId != null) {
        await itemsCollection
            .doc(selectedItemId!)
            .set(docData, SetOptions(merge: true));
      }
      // ✅ ADD NEW ITEM
      else {
        await itemsCollection.add(docData);
      }

      // ✅ SUCCESS MESSAGE
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedItemId == null ? 'Item added!' : 'Item updated!',
            ),
          ),
        );
        closePanel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'Menu Items',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorStart,
        elevation: 0,
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
                          hintText: 'Search items...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF13452E),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => openPanel(null),
                      icon: const Icon(Icons.add, color: Color(0xFF13452E)),
                      label: const Text(
                        'Add Item',
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
                Expanded(child: buildItemsTable()),
              ],
            ),
          ),
          if (panelOpen) buildAddItemPanel(context),
        ],
      ),
    );
  }

  Widget buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: itemsCollection
            .where('shopId', isEqualTo: widget.shopId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No items yet. Add your first item!',
                  style: TextStyle(fontSize: 18, color: Color(0xFF13452E)),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(colorStart),
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              dataRowColor: MaterialStateProperty.all(Colors.white),
              border: TableBorder.all(color: Colors.grey.shade200, width: 1),
              columnSpacing: 16,
              horizontalMargin: 20,
              columns: const [
                DataColumn(
                  label: Text('Image', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Item', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Price', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Vars', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text(
                    'Base Inv',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Category',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DataColumn(
                  label: Text('Status', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Actions', style: TextStyle(color: Colors.white)),
                ),
              ],
              rows: docs.map((doc) {
                final data = safeCast<Map<String, dynamic>>(doc.data());
                if (data == null) {
                  return const DataRow(
                    cells: [
                      DataCell(Text('Error')),
                      DataCell(Text('Data error')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(SizedBox()),
                    ],
                  );
                }
                final varsCount = (data['variations'] as List?)?.length ?? 0;
                final baseInvRaw = data['inventoryRequirements'];
                String baseInvText = 'None';
                if (baseInvRaw is List && (baseInvRaw as List).isNotEmpty) {
                  baseInvText = '${(baseInvRaw as List).length} items';
                }

                Uint8List? imageBytes;
                final imgData = data['imageBase64']?.toString();
                if (imgData != null && imgData.isNotEmpty) {
                  try {
                    imageBytes = base64Decode(imgData);
                  } catch (e) {}
                }

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
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFF13452E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_menu,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data['name']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            safeSubstring(data['description']?.toString(), 30),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text('Rs ${data['price']?.toStringAsFixed(0) ?? '-'}'),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: varsCount == 0
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          varsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        baseInvText,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                    DataCell(
                      Text(data['categoryName']?.toString() ?? 'Uncategorized'),
                    ),
                    DataCell(
                      Icon(
                        data['isAvailable'] == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: data['isAvailable'] == true
                            ? const Color(0xFF4CAF50)
                            : Colors.red,
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => openPanel(doc.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteItem(doc.id),
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
      ),
    );
  }

  void deleteItem(String itemId) {
    itemsCollection.doc(itemId).delete();
  }

  Widget buildAddItemPanel(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    panelWidth = screenWidth > 1000 ? 900 : screenWidth * 0.9;

    return SlideTransition(
      position: panelOffset!,
      child: Container(
        width: panelWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorStart, colorEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(-20, 0),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            bottomLeft: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedItemId == null ? 'Add New Item' : 'Edit Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: closePanel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Basic Information
                  buildSectionTitle('Basic Information'),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: itemNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: inputDecoration('Item Name'),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: inputDecoration('Description'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: singlePriceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Base Price (Rs)'),
                          validator: (v) =>
                              v?.trim().isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: prepTimeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Prep Time (min)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Category Selection
                  buildSectionTitle('Category'),
                  const SizedBox(height: 20),
                  FutureBuilder<QuerySnapshot>(
                    future: categoriesCollection
                        .where('shopId', isEqualTo: widget.shopId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        items: docs
                            .map((doc) {
                              final data = safeCast<Map<String, dynamic>>(
                                doc.data(),
                              );
                              if (data == null) return null;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  data['name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            })
                            .whereType<DropdownMenuItem<String>>()
                            .toList(),
                        onChanged: (val) async {
                          if (val != null && mounted) {
                            setState(() => selectedCategoryId = val);
                            final doc = docs.firstWhere(
                              (d) => d.id == val,
                              orElse: () =>
                                  throw Exception('Category not found'),
                            );
                            final data = safeCast<Map<String, dynamic>>(
                              doc.data(),
                            );
                            if (data != null && mounted) {
                              selectedCategoryName = data['name']?.toString();
                              if (selectedCategoryName != null) {
                                await loadCategoryInventory(
                                  selectedCategoryName!,
                                );
                              }
                            }
                          }
                        },
                        decoration: inputDecoration('Select Category'),
                        dropdownColor: colorStart,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) => v == null ? 'Required' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // =====================
                  // ✅ DISPLAY SELECTION
                  // =====================
                  buildSectionTitle('Display'),
                  const SizedBox(height: 16),

                  FutureBuilder<QuerySnapshot>(
                    future: displaysCollection
                        .where('shopId', isEqualTo: widget.shopId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedDisplayId,
                        items: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selectedDoc = docs.firstWhere(
                            (d) => d.id == val,
                          );
                          final displayData =
                              selectedDoc.data() as Map<String, dynamic>;

                          setState(() {
                            selectedDisplayId = selectedDoc.id;
                            selectedDisplayName = displayData['name'];
                          });
                        },
                        decoration: inputDecoration('Select Display'),
                        dropdownColor: colorStart,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) => v == null ? 'Required' : null,
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Inventory Section
                  if (isLoadingInventory)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (availableInventoryItems.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionTitle(
                          'Base Item Inventories (${baseItemInventories.length})',
                        ),
                        const SizedBox(height: 16),
                        ...baseItemInventories.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: buildInventoryCard(
                              'Base Inventory ${entry.key + 1}',
                              entry.value,
                              false,
                              entry.key,
                              false,
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: availableInventoryItems.isNotEmpty
                                ? addBaseInventory
                                : null,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF13452E),
                            ),
                            label: const Text(
                              'Add Base Inventory',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (selectedCategoryId != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'No inventory available for this category. Add inventory items first.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Variations Section
                  buildSectionTitle('Variations (${variations.length})'),
                  const SizedBox(height: 16),
                  ...variations.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: buildInventoryCard(
                        'Variation ${entry.key + 1}',
                        entry.value,
                        true,
                        entry.key,
                        true,
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (variations.length < 5)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: addVariation,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF13452E),
                        ),
                        label: const Text(
                          'Add Variation',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),

                  // Item Image
                  buildSectionTitle('Item Image'),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: pickedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                pickedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 50,
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 10,
                      ),
                      child: Text(
                        selectedItemId == null ? 'Create Item' : 'Update Item',
                        style: TextStyle(
                          color: colorStart,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  // FIXED: Inventory card supports both base and variations properly
  Widget buildInventoryCard(
    String title,
    Map<String, dynamic> data,
    bool isVariation,
    int index,
    bool showPrice,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 28,
                ),
                onPressed: () => isVariation
                    ? removeVariation(index)
                    : removeBaseInventory(index),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Variation Name & Price
          if (showPrice)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: data['name']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('Variation Name'),
                    onChanged: (val) {
                      if (isVariation) variations[index]['name'] = val;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: data['price']?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('Price (Rs)'),
                    onChanged: (val) {
                      if (isVariation) variations[index]['price'] = val;
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // For Variations: Show multiple inventory items
          if (isVariation)
            Column(
              children: [
                ...((data['inventoryRequirements'] as List).asMap().entries.map((
                  entry,
                ) {
                  int invIndex = entry.key;
                  Map<String, dynamic> invData = Map<String, dynamic>.from(
                    entry.value,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        // Inventory Dropdown
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value:
                                (invData['inventoryId']?.toString() ?? '')
                                    .isNotEmpty
                                ? invData['inventoryId'].toString()
                                : null,
                            items: availableInventoryItems.map((inv) {
                              return DropdownMenuItem<String>(
                                value: inv['id'] as String,
                                child: Text(
                                  '${inv['name']} (${inv['quantity']} ${inv['unit']})',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final selectedInv = availableInventoryItems
                                  .firstWhere(
                                    (inv) => inv['id'] == val,
                                    orElse: () => <String, dynamic>{},
                                  );
                              variations[index]['inventoryRequirements'][invIndex] =
                                  {
                                    ...invData,
                                    'inventoryId': val,
                                    'inventoryName': selectedInv['name'] ?? '',
                                    'inventoryUnit':
                                        selectedInv['unit'] ?? 'kg',
                                    'inventoryQty':
                                        invData['inventoryQty'] ?? '0',
                                  };
                              if (mounted) setState(() {});
                            },
                            decoration: inputDecoration('Inventory Item'),
                            dropdownColor: colorStart,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Qty
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue:
                                invData['inventoryQty']?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecoration('Qty'),
                            onChanged: (val) {
                              variations[index]['inventoryRequirements'][invIndex]['inventoryQty'] =
                                  val;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unit
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value:
                                units.contains(
                                  invData['inventoryUnit']?.toString(),
                                )
                                ? invData['inventoryUnit'].toString()
                                : null,
                            items: units.map((unit) {
                              return DropdownMenuItem<String>(
                                value: unit,
                                child: Text(
                                  unit,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              variations[index]['inventoryRequirements'][invIndex]['inventoryUnit'] =
                                  val ?? 'kg';
                              if (mounted) setState(() {});
                            },
                            decoration: inputDecoration('Unit'),
                            dropdownColor: colorStart,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              removeVariationInventory(index, invIndex),
                        ),
                      ],
                    ),
                  );
                })),
                // Button to add more inventory to this variation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => addVariationInventory(index),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF13452E),
                    ),
                    label: const Text('Add Inventory Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                // Base item inventory dropdown handled separately
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: (data['inventoryId']?.toString() ?? '').isNotEmpty
                        ? data['inventoryId'].toString()
                        : null,
                    items: availableInventoryItems.map((inv) {
                      return DropdownMenuItem<String>(
                        value: inv['id'] as String,
                        child: Text(
                          '${inv['name']} (${inv['quantity']} ${inv['unit']})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selectedInv = availableInventoryItems.firstWhere(
                        (inv) => inv['id'] == val,
                        orElse: () => <String, dynamic>{},
                      );
                      baseItemInventories[index] = {
                        ...data,
                        'inventoryId': val,
                        'inventoryName': selectedInv['name'] ?? '',
                        'inventoryUnit': selectedInv['unit'] ?? 'kg',
                        'inventoryQty': data['inventoryQty'] ?? '0',
                      };
                      if (mounted) setState(() {});
                    },
                    decoration: inputDecoration('Inventory Item'),
                    dropdownColor: colorStart,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: data['inventoryQty']?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('Qty'),
                    onChanged: (val) {
                      baseItemInventories[index]['inventoryQty'] = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: units.contains(data['inventoryUnit']?.toString())
                        ? data['inventoryUnit'].toString()
                        : null,
                    items: units.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(
                          unit,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      baseItemInventories[index]['inventoryUnit'] = val ?? 'kg';
                      if (mounted) setState(() {});
                    },
                    decoration: inputDecoration('Unit'),
                    dropdownColor: colorStart,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
