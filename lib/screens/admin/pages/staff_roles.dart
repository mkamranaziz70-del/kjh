// lib/pages/staff_page.dart
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffPage extends StatefulWidget {
  final String shopId;
  const StaffPage({super.key, required this.shopId});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String selectedRole = "chef";
  String selectedStaffType = "kitchen";

  String? selectedKitchenId;
  String? selectedKitchenName;

  final ValueNotifier<String> searchNotifier = ValueNotifier('');

  bool showAddPanel = false;

  late AnimationController panelController;
  late Animation<Offset> slideAnimation;

  final CollectionReference staffCollection =
      FirebaseFirestore.instance.collection('staff');

  final Color darkGreen = const Color(0xFF13452E);
  final Color softWhite = const Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();

    panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: panelController, curve: Curves.fastOutSlowIn),
    );

    searchController.addListener(() {
      searchNotifier.value = searchController.text.toLowerCase();
    });
  }

  /// ✅ FETCH KITCHEN / BAR DISPLAYS
  Stream<QuerySnapshot> _kitchensStream() {
    return FirebaseFirestore.instance
        .collection('displays')
        .where('shopId', isEqualTo: widget.shopId)
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    addressController.dispose();
    panelController.dispose();
    searchNotifier.dispose();
    super.dispose();
  }

  void openPanel() {
    setState(() => showAddPanel = true);
    panelController.forward();
  }

  void closePanel() {
    panelController.reverse().then((_) {
      setState(() {
        showAddPanel = false;
        nameController.clear();
        emailController.clear();
        passwordController.clear();
        phoneController.clear();
        addressController.clear();

        selectedRole = "chef";
        selectedStaffType = "kitchen";
        selectedKitchenId = null;
        selectedKitchenName = null;
      });
    });
  }

  /// ✅ ADD STAFF WITH FULL VALIDATION & ROUTING
  Future<void> addStaff() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (selectedRole == "chef" && selectedKitchenId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select kitchen display")),
      );
      return;
    }

    try {
      await staffCollection.add({
        'shopId': widget.shopId,
        'name': nameController.text.trim(),
        'role': selectedRole,
        'staffType': selectedRole == "chef" ? "kitchen" : selectedStaffType,
        'displayId': selectedKitchenId,
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Staff added successfully")),
      );

      closePanel();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding staff: $e")),
      );
    }
  }

  Future<void> editStaff(String id, Map<String, dynamic> data) async {
    try {
      await staffCollection.doc(id).update(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Staff updated")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await staffCollection.doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Staff deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(width < 600 ? 12 : 18),
            child: Column(
              children: [
                /// ✅ SEARCH + ADD
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
                            hintText: "Search staff...",
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
                        "Add Staff",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// ✅ STAFF TABLE
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: staffCollection
                        .where('shopId', isEqualTo: widget.shopId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final data = snap.data!.docs;

                      return ValueListenableBuilder(
                        valueListenable: searchNotifier,
                        builder: (_, search, __) {
                          final filtered = data.where((d) {
                            final name =
                                d['name'].toString().toLowerCase();
                            final role =
                                d['role'].toString().toLowerCase();
                            final email =
                                d['email'].toString().toLowerCase();
                            return name.contains(search) ||
                                role.contains(search) ||
                                email.contains(search);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text("No staff found"),
                            );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor:
                                  WidgetStatePropertyAll(darkGreen),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              columns: const [
                                DataColumn(label: Text("Name")),
                                DataColumn(label: Text("Role")),
                                DataColumn(label: Text("Type")),
                                DataColumn(label: Text("Email")),
                                DataColumn(label: Text("Phone")),
                                DataColumn(label: Text("Address")),
                                DataColumn(label: Text("Action")),
                              ],
                              rows: filtered.map((doc) {
                                return DataRow(cells: [
                                  DataCell(Text(doc['name'])),
                                  DataCell(Text(doc['role'])),
                                  DataCell(Text(doc['staffType'] ?? '')),
                                  DataCell(Text(doc['email'])),
                                  DataCell(Text(doc['phone'])),
                                  DataCell(Text(doc['address'])),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          deleteStaff(doc.id),
                                    ),
                                  ),
                                ]);
                              }).toList(),
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

          /// ✅ ADD STAFF SIDE PANEL
          if (showAddPanel)
            SlideTransition(
              position: slideAnimation,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 360,
                  height: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: softWhite,
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: closePanel,
                          icon: const Icon(Icons.close),
                        ),

                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: "Name",
                          ),
                        ),

                        const SizedBox(height: 12),

                        /// ✅ ROLE DROPDOWN
                        DropdownButtonFormField(
                          value: selectedRole,
                          items: const [
                            DropdownMenuItem(
                              value: "chef",
                              child: Text("Chef"),
                            ),
                            DropdownMenuItem(
                              value: "waiter",
                              child: Text("Waiter"),
                            ),
                            DropdownMenuItem(
                              value: "manager",
                              child: Text("Manager"),
                            ),
                            DropdownMenuItem(
                              value: "delivery man",
                              child: Text("Delivery Man"),
                            ),
                             DropdownMenuItem(
                              value: "cashier",
                              child: Text("cashier"),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              selectedRole = v.toString();

                              if (selectedRole != "chef") {
                                selectedKitchenId = null;
                                selectedStaffType = "hall";
                              } else {
                                selectedStaffType = "kitchen";
                              }
                            });
                          },
                          decoration: const InputDecoration(labelText: "Role"),
                        ),

                        const SizedBox(height: 12),

                        /// ✅ KITCHEN DROPDOWN (ONLY FOR CHEF)
                        if (selectedRole == "chef")
                          StreamBuilder<QuerySnapshot>(
                            stream: _kitchensStream(),
                            builder: (context, snap) {
                              if (!snap.hasData)
                                return const CircularProgressIndicator();

                              final docs = snap.data!.docs;

                              return DropdownButtonFormField(
                                value: selectedKitchenId,
                                items: docs
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text(d['name']),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => selectedKitchenId = v),
                                decoration: const InputDecoration(
                                  labelText: "Kitchen Display",
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: emailController,
                          decoration:
                              const InputDecoration(labelText: "Email"),
                        ),
                        TextField(
                          controller: passwordController,
                          decoration:
                              const InputDecoration(labelText: "Password"),
                        ),
                        TextField(
                          controller: phoneController,
                          decoration:
                              const InputDecoration(labelText: "Phone"),
                        ),
                        TextField(
                          controller: addressController,
                          decoration:
                              const InputDecoration(labelText: "Address"),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: addStaff,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                          ),
                          child: const Text(
                            "Save Staff",
                            style: TextStyle(color: Colors.white),
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
