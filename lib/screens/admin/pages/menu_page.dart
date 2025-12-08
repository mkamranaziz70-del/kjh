// lib/pages/menu_items_page.dart
// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MenuPage extends StatefulWidget {
  final String shopId;
  const MenuPage({super.key, required this.shopId});

  @override
  State<MenuPage> createState() => _MenuItemsPageState();
}

class _MenuItemsPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  // Collections
  late final CollectionReference categoriesCollection;
  late final CollectionReference itemsCollection;

  // Controllers
  final TextEditingController searchController = TextEditingController();

  // ----- Panel -----
  bool panelOpen = false;
  double panelWidth = 520;
  AnimationController? _panelAnim;
  Animation<Offset>? _panelOffset;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController prepController = TextEditingController();
  final TextEditingController singlePriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  String? selectedCategoryId;
  String selectedItemType = 'normal';
  bool isAvailable = true;
  bool hasVariants = false;

  List<Map<String, TextEditingController>> variantControllers = [];
  XFile? pickedImage;
  String? imageBase64;
  final ImagePicker _picker = ImagePicker();

  String? selectedItemId; // for edit
  String? selectedCategoryName;
  ValueNotifier<String> searchNotifier = ValueNotifier('');

  final Color darkGreen = const Color(0xFF13452E);
  final Color softGrey = const Color(0xFFCDD3D0);
  final Color blackish = const Color(0xFF010703);
  final Color softWhite = const Color(0xFFF7F7F7);

  final List<String> itemTypes = [
    'normal',
    'spicy',
    'sweet',
    'drink',
    'veg',
    'non-veg',
    'beverage',
    'combo',
    'fried',
    'grill',
    'dessert',
    'cold',
    'hot',
  ];

  @override
  void initState() {
    super.initState();
    categoriesCollection = FirebaseFirestore.instance.collection(
      'itemCategories',
    );
    itemsCollection = FirebaseFirestore.instance.collection('items');

    searchController.addListener(() {
      searchNotifier.value = searchController.text.toLowerCase();
    });

    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelOffset = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelAnim!, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    searchController.dispose();
    itemNameController.dispose();
    descController.dispose();
    prepController.dispose();
    singlePriceController.dispose();
    quantityController.dispose();
    _panelAnim?.dispose();
    searchNotifier.dispose();
    for (var v in variantControllers) {
      v['name']?.dispose();
      v['price']?.dispose();
    }
    super.dispose();
  }

  void openPanel({String? itemId, String? categoryId}) {
    setState(() {
      panelOpen = true;
      selectedItemId = itemId;
      selectedCategoryId = categoryId;
    });
    _panelAnim?.forward();
  }

  void closePanel() {
    _panelAnim?.reverse().whenComplete(() {
      setState(() {
        panelOpen = false;
        _clearForm();
        selectedItemId = null;
      });
    });
  }

  void _clearForm() {
    itemNameController.clear();
    descController.clear();
    prepController.clear();
    singlePriceController.clear();
    quantityController.clear();
    selectedCategoryId = null;
    selectedItemType = 'normal';
    isAvailable = true;
    hasVariants = false;
    pickedImage = null;
    imageBase64 = null;
    for (var m in variantControllers) {
      m['name']?.dispose();
      m['price']?.dispose();
    }
    variantControllers = [];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (image == null) return;
      setState(() {
        pickedImage = image;
      });
      final bytes = await image.readAsBytes();
      imageBase64 = base64Encode(bytes);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  void addVariantRow() {
    setState(() {
      variantControllers.add({
        'name': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void removeVariantRow(int idx) {
    setState(() {
      variantControllers[idx]['name']?.dispose();
      variantControllers[idx]['price']?.dispose();
      variantControllers.removeAt(idx);
    });
  }

  Future<void> saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select category')));
      return;
    }

    double? singlePrice;
    List<Map<String, dynamic>> variants = [];

    if (hasVariants) {
      if (variantControllers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one variant')),
        );
        return;
      }
      for (var v in variantControllers) {
        final name = v['name']!.text.trim();
        final priceStr = v['price']!.text.trim();
        if (name.isEmpty || priceStr.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All variant name & price required')),
          );
          return;
        }
        final p = double.tryParse(priceStr.replaceAll(',', ''));
        if (p == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid variant price')),
          );
          return;
        }
        variants.add({'name': name, 'price': p});
      }
    } else {
      final pr = singlePriceController.text.trim();
      if (pr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter price or enable variants')),
        );
        return;
      }
      singlePrice = double.tryParse(pr.replaceAll(',', ''));
      if (singlePrice == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid price')));
        return;
      }
    }

    if (imageBase64 == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an image')));
      return;
    }

    try {
      final doc = {
        'shopId': widget.shopId,
        'categoryId': selectedCategoryId,
        'name': itemNameController.text.trim(),
        'description': descController.text.trim(),
        'type': selectedItemType,
        'preparationMinutes': int.tryParse(prepController.text.trim()) ?? 0,
        'isAvailable': isAvailable,
        'imageBase64': imageBase64,
        'hasVariants': hasVariants,
        'variants': variants,
        'price': hasVariants ? null : singlePrice,
        'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
        'createdAt': Timestamp.now(),
      };

      if (selectedItemId != null) {
        await itemsCollection.doc(selectedItemId).update(doc);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item updated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await itemsCollection.add(doc);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added'),
            backgroundColor: Colors.green,
          ),
        );
      }

      closePanel();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _itemsListForCategory(String categoryId) {
    return StreamBuilder<QuerySnapshot>(
      stream: itemsCollection
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No items in this category'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final d = docs[idx].data() as Map<String, dynamic>;
            final priceText = (d['hasVariants'] == true)
                ? (d['variants'] as List<dynamic>? ?? [])
                      .map((v) => '${v['name']}:${v['price']}')
                      .join(' | ')
                : (d['price'] != null ? 'Rs ${d['price']}' : '-');

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: d['imageBase64'] != null
                    ? CircleAvatar(
                        backgroundImage: MemoryImage(
                          base64Decode(d['imageBase64']),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.fastfood)),
                title: Text(d['name'] ?? '-'),
                subtitle: Text(
                  '${d['description'] ?? ''}\n$priceText • Qty: ${d['quantity'] ?? 0}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.black87),
                      onPressed: () {
                        // populate form for edit
                        setState(() {
                          selectedItemId = docs[idx].id;
                          itemNameController.text = d['name'] ?? '';
                          descController.text = d['description'] ?? '';
                          prepController.text = (d['preparationMinutes'] ?? 0)
                              .toString();
                          singlePriceController.text = (d['price'] ?? '')
                              .toString();
                          quantityController.text = (d['quantity'] ?? 0)
                              .toString();
                          selectedItemType = d['type'] ?? 'normal';
                          isAvailable = d['isAvailable'] ?? true;
                          hasVariants = d['hasVariants'] ?? false;
                          selectedCategoryId = d['categoryId'];
                          imageBase64 = d['imageBase64'];
                          variantControllers = [];
                          if (hasVariants && d['variants'] != null) {
                            for (var v in d['variants']) {
                              variantControllers.add({
                                'name': TextEditingController(text: v['name']),
                                'price': TextEditingController(
                                  text: v['price'].toString(),
                                ),
                              });
                            }
                          }
                        });
                        openPanel(
                          itemId: docs[idx].id,
                          categoryId: d['categoryId'],
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: const Text(
                              'Are you sure you want to delete this item?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await itemsCollection.doc(docs[idx].id).delete();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddItemPanel(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    panelWidth = width > 1100 ? 520 : (width * 0.9);

    return SlideTransition(
      position: _panelOffset!,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: panelWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 40),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [darkGreen, blackish]),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_box, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedItemId == null ? 'Add Item' : 'Edit Item',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: closePanel,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name
                          TextFormField(
                            controller: itemNameController,
                            decoration: InputDecoration(
                              labelText: 'Item name',
                              border: OutlineInputBorder(),
                              fillColor: softGrey,
                              filled: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          // Description
                          TextFormField(
                            controller: descController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                              fillColor: softGrey,
                              filled: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Description required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          // Category
                          FutureBuilder<QuerySnapshot>(
                            future: categoriesCollection
                                .where('shopId', isEqualTo: widget.shopId)
                                .get(),
                            builder: (c, snap) {
                              final docs = snap.data?.docs ?? [];
                              return DropdownButtonFormField<String>(
                                value: selectedCategoryId,
                                items: docs.map((d) {
                                  final m = d.data() as Map<String, dynamic>;
                                  return DropdownMenuItem<String>(
                                    value: d.id,
                                    child: Text(m['name'] ?? 'Unnamed'),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => selectedCategoryId = v),
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  fillColor: softGrey,
                                  filled: true,
                                ),
                                validator: (v) =>
                                    v == null ? 'Select category' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Item type + prep + qty
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedItemType,
                                  items: itemTypes
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t.capitalize()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => selectedItemType = v ?? 'normal',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Type',
                                    border: OutlineInputBorder(),
                                    fillColor: softGrey,
                                    filled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: prepController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Prep min',
                                    border: OutlineInputBorder(),
                                    fillColor: softGrey,
                                    filled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(),
                                    fillColor: softGrey,
                                    filled: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Image picker
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.image),
                                label: const Text('Select Image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (pickedImage != null)
                                SizedBox(
                                  height: 80,
                                  width: 80,
                                  child: Image.file(
                                    File(pickedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if (imageBase64 != null)
                                SizedBox(
                                  height: 80,
                                  width: 80,
                                  child: Image.memory(
                                    base64Decode(imageBase64!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                const Text(
                                  'No image selected',
                                  style: TextStyle(color: Colors.grey),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Has Variants
                          Row(
                            children: [
                              Checkbox(
                                value: hasVariants,
                                onChanged: (v) =>
                                    setState(() => hasVariants = v ?? false),
                              ),
                              const Text('Has Variants'),
                            ],
                          ),
                          if (!hasVariants)
                            TextFormField(
                              controller: singlePriceController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Price (Rs)',
                                border: OutlineInputBorder(),
                                fillColor: softGrey,
                                filled: true,
                              ),
                            )
                          else
                            Column(
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: variantControllers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, idx) {
                                    final v = variantControllers[idx];
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: v['name'],
                                            decoration: const InputDecoration(
                                              labelText: 'Variant Name',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            controller: v['price'],
                                            keyboardType:
                                                TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              labelText: 'Price',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              removeVariantRow(idx),
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  onPressed: addVariantRow,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Variant'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saveItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                selectedItemId == null
                                    ? 'Add Item'
                                    : 'Update Item',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softWhite,
      appBar: AppBar(
        title: const Text('Items Management'),
        backgroundColor: darkGreen,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search items...',
                    border: OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    fillColor: softGrey,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Categories + Items
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: categoriesCollection
                        .where('shopId', isEqualTo: widget.shopId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final cats = snap.data!.docs;
                      return ListView.separated(
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) {
                          final c = cats[idx].data() as Map<String, dynamic>;
                          final categoryId = cats[idx].id;
                          final categoryName = c['name'] ?? 'Unnamed';
                          if (searchNotifier.value.isNotEmpty &&
                              !categoryName.toLowerCase().contains(
                                searchNotifier.value,
                              )) {
                            return const SizedBox.shrink();
                          }
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              backgroundColor: softWhite,
                              title: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: [
                                SizedBox(
                                  height: 300,
                                  child: _itemsListForCategory(categoryId),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        openPanel(categoryId: categoryId),
                                    icon: const Icon(Icons.add_box),
                                    label: const Text('Add Item'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (panelOpen) _buildAddItemPanel(context),
        ],
      ),
    );
  }
}

extension CapExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
