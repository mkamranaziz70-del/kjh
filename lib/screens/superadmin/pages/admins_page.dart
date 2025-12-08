import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final CollectionReference adminsCollection = FirebaseFirestore.instance
      .collection('admins');

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String? editingDocId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Admins Management",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),

          // 🔹 Add / Edit Admin Form
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (editingDocId != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF25C4D),
                          ),
                          onPressed: updateAdmin,
                          child: const Text("Update Admin"),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF25C4D),
                          ),
                          onPressed: addAdmin,
                          child: const Text("Add Admin"),
                        ),
                      const SizedBox(width: 10),
                      if (editingDocId != null)
                        TextButton(
                          onPressed: cancelEditing,
                          child: const Text("Cancel"),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Admins List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminsCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading admins"));
                }

                final admins = snapshot.data!.docs;

                if (admins.isEmpty) {
                  return const Center(child: Text("No admins found"));
                }

                return ListView.builder(
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final doc = admins[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(data['name'] ?? "No Name"),
                        subtitle: Text(data['email'] ?? "No Email"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => startEditing(doc.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteAdmin(doc.id),
                            ),
                          ],
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

  // 🔹 CRUD FUNCTIONS

  void addAdmin() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty) return;

    await adminsCollection.add({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    nameController.clear();
    emailController.clear();
  }

  void startEditing(String docId, Map<String, dynamic> data) {
    setState(() {
      editingDocId = docId;
      nameController.text = data['name'] ?? "";
      emailController.text = data['email'] ?? "";
    });
  }

  void updateAdmin() async {
    if (editingDocId == null) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty) return;

    await adminsCollection.doc(editingDocId).update({
      'name': name,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    cancelEditing();
  }

  void deleteAdmin(String docId) async {
    await adminsCollection.doc(docId).delete();
  }

  void cancelEditing() {
    setState(() {
      editingDocId = null;
      nameController.clear();
      emailController.clear();
    });
  }
}
