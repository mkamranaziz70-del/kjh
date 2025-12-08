// lib/pages/table_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TablePage extends StatefulWidget {
  final String shopId;
  const TablePage({super.key, required this.shopId});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController tableCountController = TextEditingController();

  String selectedArea = '';

  // Show Add Table Dialog
  Future<void> _showAddTableDialog() async {
    areaController.clear();
    tableCountController.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Table"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: areaController,
              decoration: const InputDecoration(labelText: "Area Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tableCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of Tables"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _addTable();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13452E),
            ),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Add Tables to Firestore
  Future<void> _addTable() async {
    final area = areaController.text.trim();
    final count = int.tryParse(tableCountController.text.trim()) ?? 0;
    if (area.isEmpty || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid area and number of tables"),
        ),
      );
      return;
    }

    final tablesCollection = FirebaseFirestore.instance.collection('tables');

    // Get max tableNumber in this area
    final snapshot = await tablesCollection
        .where('shopId', isEqualTo: widget.shopId)
        .where('area', isEqualTo: area)
        .orderBy('tableNumber')
        .limit(1)
        .get();

    int startNumber = 1;
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      startNumber = (data['tableNumber'] as int) + 1;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < count; i++) {
      final docRef = tablesCollection.doc();
      batch.set(docRef, {
        'shopId': widget.shopId,
        'area': area,
        'tableNumber': startNumber + i,
        'status': 'free',
      });
    }

    await batch.commit();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Table(s) added successfully")),
    );
  }

  // Toggle table status
  Future<void> _toggleTableStatus(String docId, String currentStatus) async {
    final newStatus = currentStatus == 'free' ? 'reserved' : 'free';
    await FirebaseFirestore.instance.collection('tables').doc(docId).update({
      'status': newStatus,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Table status updated to $newStatus")),
    );
  }

  // Delete area
  Future<void> _deleteArea(String areaName) async {
    final tablesCollection = FirebaseFirestore.instance.collection('tables');
    final snapshot = await tablesCollection
        .where('shopId', isEqualTo: widget.shopId)
        .where('area', isEqualTo: areaName)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    if (selectedArea == areaName) selectedArea = '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Area '$areaName' deleted successfully")),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    areaController.dispose();
    tableCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search + Add Area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Search by area...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _showAddTableDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13452E),
                  ),
                  child: const Text("Add Area"),
                ),
              ],
            ),
          ),

          // Areas List - Full width cards
          Expanded(
            flex: 0,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tables')
                  .where('shopId', isEqualTo: widget.shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final docs = snapshot.data!.docs;
                final areas = <String>{};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  areas.add(data['area'] ?? 'Unnamed');
                }
                final filteredAreas = areas
                    .where(
                      (a) => a.toLowerCase().contains(
                        searchController.text.trim().toLowerCase(),
                      ),
                    )
                    .toList();
                if (filteredAreas.isEmpty) return const SizedBox();

                return Column(
                  children: filteredAreas.map((areaName) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: selectedArea == areaName
                            ? const Color(0xFF13452E)
                            : Colors.grey[300],
                        child: ListTile(
                          title: Text(
                            areaName,
                            style: TextStyle(
                              color: selectedArea == areaName
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteArea(areaName),
                          ),
                          onTap: () => setState(() => selectedArea = areaName),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Tables Grid
          Expanded(
            child: selectedArea.isEmpty
                ? const Center(child: Text("Select an area to view tables"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('tables')
                        .where('shopId', isEqualTo: widget.shopId)
                        .where('area', isEqualTo: selectedArea)
                        .orderBy('tableNumber')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final tables = snapshot.data!.docs;
                      if (tables.isEmpty) {
                        return const Center(
                          child: Text("No tables in this area"),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                        itemCount: tables.length,
                        itemBuilder: (context, index) {
                          final data =
                              tables[index].data() as Map<String, dynamic>;
                          final status = data['status'] ?? 'free';
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            child: InkWell(
                              onTap: () =>
                                  _toggleTableStatus(tables[index].id, status),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Table ${data['tableNumber']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      status.toString().toUpperCase(),
                                      style: TextStyle(
                                        color: status == 'free'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        status == 'free'
                                            ? "Tap to Reserve"
                                            : "Tap to Unreserve",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
}
