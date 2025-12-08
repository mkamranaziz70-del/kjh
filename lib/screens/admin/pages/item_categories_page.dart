import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ItemCategoriesPage extends StatefulWidget {
  final String shopId;
  const ItemCategoriesPage({super.key, required this.shopId});

  @override
  State<ItemCategoriesPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<ItemCategoriesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  late AnimationController panelController;
  late Animation<Offset> slideAnimation;

  final Color darkGreen = const Color(0xFF13452E);
  final Color softWhite = const Color(0xFFF7F7F7);

  bool showAddPanel = false;

  late final CollectionReference categoriesCollection;
  late final CollectionReference itemsCollection;

  ValueNotifier<String> searchNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();

    categoriesCollection = FirebaseFirestore.instance.collection('categories');
    itemsCollection = FirebaseFirestore.instance.collection('items');

    searchController.addListener(() {
      searchNotifier.value = searchController.text.toLowerCase();
    });

    panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: panelController, curve: Curves.fastOutSlowIn),
        );
  }

  @override
  void dispose() {
    searchController.dispose();
    categoryController.dispose();
    panelController.dispose();
    searchNotifier.dispose();
    super.dispose();
  }

  // 📌 Fetch item stats (count + quantity)
  Future<Map<String, dynamic>> getItemStats(String categoryId) async {
    final snapshot = await itemsCollection
        .where("categoryId", isEqualTo: categoryId)
        .where("shopId", isEqualTo: widget.shopId)
        .get();

    int itemCount = snapshot.size;
    int totalQuantity = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final q = data["quantity"];

      if (q is int) {
        totalQuantity += q;
      } else if (q is double) {
        totalQuantity += q.toInt();
      } else if (q is String) {
        final parsed = num.tryParse(q);
        if (parsed != null) totalQuantity += parsed.toInt();
      } else if (q is num) {
        totalQuantity += q.toInt();
      }
    }

    return {"count": itemCount, "quantity": totalQuantity};
  }

  // ⭐ Add Category
  Future<void> addCategory() async {
    final name = categoryController.text.trim();
    if (name.isEmpty) return;

    await categoriesCollection.add({
      'shopId': widget.shopId,
      'name': name,
      'createdAt': Timestamp.now(),
    });

    categoryController.clear();
    closePanel();
  }

  // ⭐ Edit Category
  Future<void> editCategory(String id, String name) async {
    await categoriesCollection.doc(id).update({'name': name.trim()});
  }

  // ⭐ Delete Category
  Future<void> deleteCategory(String id) async {
    await categoriesCollection.doc(id).delete();
  }

  // 🎬 Slide-in panel open
  void openPanel() {
    setState(() => showAddPanel = true);
    panelController.forward();
  }

  // 🎬 Slide-in panel close
  void closePanel() {
    panelController.reverse().then((_) {
      setState(() => showAddPanel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          // MAIN BODY
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Search + Add Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            hintText: "Search categories...",
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: openPanel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "Add Category",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // TABLE VIEW
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: categoriesCollection
                        .where('shopId', isEqualTo: widget.shopId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snap.data!.docs;

                      return ValueListenableBuilder(
                        valueListenable: searchNotifier,
                        builder: (_, search, __) {
                          final filtered = data.where((d) {
                            final name = d['name']
                                .toString()
                                .toLowerCase()
                                .trim();
                            return name.contains(search);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text("No categories found"),
                            );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateColor.resolveWith(
                                  (states) => darkGreen,
                                ),
                                headingTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                columns: const [
                                  DataColumn(label: Text("Category Name")),
                                  DataColumn(label: Text("Items Count")),
                                  DataColumn(label: Text("Action")),
                                ],
                                rows: filtered.map((category) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(category['name'] ?? '-')),
                                      DataCell(
                                        SizedBox(
                                          width: 50,
                                          child: FutureBuilder<Map<String, dynamic>>(
                                            future: getItemStats(category.id),
                                            builder: (ctx, statsSnap) {
                                              if (!statsSnap.hasData ||
                                                  statsSnap.connectionState !=
                                                      ConnectionState.done) {
                                                return const Text("0");
                                              }
                                              return Text(
                                                "${statsSnap.data!["count"] ?? 0}",
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () {
                                                final controller =
                                                    TextEditingController(
                                                      text: category['name'],
                                                    );
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Edit Category",
                                                    ),
                                                    content: TextField(
                                                      controller: controller,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                          "Cancel",
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  darkGreen,
                                                            ),
                                                        onPressed: () {
                                                          editCategory(
                                                            category.id,
                                                            controller.text,
                                                          );
                                                          Navigator.pop(ctx);
                                                        },
                                                        child: const Text(
                                                          "Save",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Delete Category?",
                                                    ),
                                                    content: const Text(
                                                      "Are you sure you want to delete this category? Items will remain but category will be removed.",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                          "Cancel",
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                        onPressed: () {
                                                          deleteCategory(
                                                            category.id,
                                                          );
                                                          Navigator.pop(ctx);
                                                        },
                                                        child: const Text(
                                                          "Delete",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

          // ⭐ RIGHT SIDE SLIDING PANEL
          if (showAddPanel)
            AnimatedBuilder(
              animation: panelController,
              builder: (_, __) => SlideTransition(
                position: slideAnimation,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 350,
                    height: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 15,
                          offset: Offset(-4, 0),
                          color: Colors.black26,
                        ),
                      ],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        bottomLeft: Radius.circular(26),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, size: 28),
                              onPressed: closePanel,
                            ),
                          ],
                        ),
                        const Text(
                          "Add New Category",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),
                        TextField(
                          controller: categoryController,
                          decoration: InputDecoration(
                            labelText: "Category Name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: addCategory,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Save Category",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
