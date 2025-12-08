// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../admin/dashboard_screen.dart';

class ShopsPage extends StatefulWidget {
  const ShopsPage({super.key});

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  final CollectionReference shopsCollection = FirebaseFirestore.instance
      .collection('shops');
  String? selectedShopId; // Selected shop for detail view
  Map<String, dynamic>? selectedShopData;

  // Controllers for simple edit form
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ownerController = TextEditingController();

  // Controllers for full add shop form
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerEmailController = TextEditingController();
  final TextEditingController ownerPasswordController = TextEditingController();
  final TextEditingController ownerCnicController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController shopAddressController = TextEditingController();

  String shopStatus = "active";
  String? editingId;
  bool showAddForm = false; // NEW: Toggle for inline form
  bool showDetailCard = false; // Toggle for shop detail view

  // Full form state
  PhoneNumber initialPhone = PhoneNumber(isoCode: 'PK', dialCode: '+92');
  String phoneE164 = '';
  bool isPhoneValid = false;
  String ownerCountry = 'Pakistan';
  String shopCountry = 'Pakistan';
  String fullShopStatus = 'active';
  bool isSubmitting = false;
  double passwordStrength = 0.0;
  String passwordStrengthLabel = '';

  // Validation errors
  String ownerNameError = '';
  String ownerEmailError = '';
  String ownerPasswordError = '';
  String ownerPhoneError = '';
  String ownerCnicError = '';
  String shopNameError = '';
  String shopCountryError = '';
  String shopAddressError = '';
  int currentStep = 1;

  // Custom colors
  final Color darkGreen = const Color(0xFF13452E);
  final Color lightGray = const Color(0xFFCDD3D0);
  final Color pitchBlack = const Color(0xFF010703);
  final Color softWhite = const Color(0xFFF7F7F7);
  final Color accentRed = const Color(0xFFF25C4D);

  final RegExp upperExp = RegExp(r'[A-Z]');
  final RegExp lowerExp = RegExp(r'[a-z]');
  final RegExp digitExp = RegExp(r'\d');
  final RegExp specialExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  @override
  void initState() {
    super.initState();
    print('ShopsPage initialized'); // Debug log
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    ownerController.dispose();
    ownerNameController.dispose();
    ownerEmailController.dispose();
    ownerPasswordController.dispose();
    ownerCnicController.dispose();
    shopNameController.dispose();
    shopAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building ShopsPage - showAddForm: $showAddForm'); // Debug log

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          // MAIN CONTENT (always visible)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                //---------------- TITLE + ADD BUTTON ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Shops Management",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: pitchBlack,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: darkGreen,
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "Add Shop",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        print('Add Shop button pressed!'); // Debug log
                        resetFullForm();
                        setState(() {
                          currentStep = 1; // <-- This FIXES your problem

                          showAddForm = true;
                        });
                        print('showAddForm set to true'); // Debug log
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                //---------------- SHOP LIST ----------------
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: shopsCollection
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            "No shops found",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: pitchBlack,
                            ),
                          ),
                        );
                      }

                      final shops = snapshot.data!.docs;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            color: softWhite,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: DataTable(
                            columnSpacing: 70,
                            headingRowHeight: 50,
                            headingRowColor: MaterialStateProperty.all(
                              darkGreen,
                            ),
                            dataRowColor: MaterialStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(MaterialState.selected)) {
                                return lightGray.withOpacity(0.3);
                              }
                              return Colors.transparent;
                            }),
                            columns: [
                              DataColumn(
                                label: Text(
                                  "ID",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Name",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Email",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Status",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Created At",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Action",
                                  style: TextStyle(color: softWhite),
                                ),
                              ),
                            ],
                            rows: shops.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final createdAt = data["createdAt"] != null
                                  ? data["createdAt"]
                                        .toDate()
                                        .toString()
                                        .substring(0, 16)
                                  : "-";

                              return DataRow(
                                cells: [
                                  DataCell(Text(doc.id)),
                                  // Clickable shop name
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedShopId = doc.id;
                                          selectedShopData = data;
                                          showDetailCard = true;
                                        });
                                      },
                                      child: Text(
                                        data["name"] ?? "-",
                                        style: TextStyle(
                                          color: darkGreen,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(data["ownerEmail"] ?? "-")),
                                  DataCell(
                                    DropdownButton<String>(
                                      value: data["status"],
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: "active",
                                          child: Text("Active"),
                                        ),
                                        DropdownMenuItem(
                                          value: "closed",
                                          child: Text("Closed"),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          updateStatus(doc.id, val);
                                        }
                                      },
                                    ),
                                  ),
                                  DataCell(Text(createdAt)),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            color: darkGreen,
                                          ),
                                          onPressed: () => openFormDialog(
                                            data: data,
                                            id: doc.id,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red.shade700,
                                          ),
                                          onPressed: () => deleteShop(doc.id),
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
                  ),
                ),
              ],
            ),
          ),

          //---------------- INLINE ADD FORM CARD ----------------
          if (showAddForm)
            GestureDetector(
              onTap: () {}, // Prevent closing when tapping overlay
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width > 600
                          ? 600
                          : double.infinity,
                      constraints: const BoxConstraints(maxHeight: 700),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with close button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: darkGreen.withOpacity(0.08),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront,
                                  color: darkGreen,
                                  size: 26,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Add New Shop & Owner',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF010703),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 28),
                                  onPressed: () {
                                    print('Close button pressed'); // Debug log
                                    resetFullForm();
                                    setState(() {
                                      showAddForm = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Form content - Fixed height with scroll
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildFullForm(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showDetailCard && selectedShopData != null)
            GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width > 500
                          ? 500
                          : double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softWhite,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront,
                                color: darkGreen,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedShopData!['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 28),
                                onPressed: () {
                                  setState(() {
                                    showDetailCard = false;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Owner Email: ${selectedShopData!['ownerEmail'] ?? '-'}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Status: ${selectedShopData!['status'] ?? '-'}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Address: ${selectedShopData!['address'] ?? '-'}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminDashboard(shopId: selectedShopId!),
                                ),
                              );
                            },
                            child: const Text(
                              "View / Manage Shop",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // SIMPLIFIED FORM - No country dropdowns to avoid errors
  Widget _buildFullForm() {
    // ignore: prefer_typing_uninitialized_variables
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: darkGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: darkGreen.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: darkGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentStep == 1
                      ? 'Enter owner details'
                      : 'Enter shop details',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),

        // ---------------- STEP 1 ----------------
        if (currentStep == 1)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    ownerNameController,
                    'Owner full name',
                    () => ownerNameError = '',
                  ),
                  if (ownerNameError.isNotEmpty) _errorText(ownerNameError),
                  const SizedBox(height: 16),

                  _buildTextField(
                    ownerEmailController,
                    'Email address',
                    () => ownerEmailError = '',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (ownerEmailError.isNotEmpty) _errorText(ownerEmailError),
                  const SizedBox(height: 16),

                  _buildPasswordField(),
                  if (ownerPasswordError.isNotEmpty)
                    _errorText(ownerPasswordError),
                  const SizedBox(height: 16),

                  _buildPhoneField(),
                  if (ownerPhoneError.isNotEmpty) _errorText(ownerPhoneError),
                  const SizedBox(height: 16),

                  _buildTextField(
                    ownerCnicController,
                    'CNIC (13 digits)',
                    () => ownerCnicError = '',
                    keyboardType: TextInputType.number,
                  ),
                  if (ownerCnicError.isNotEmpty) _errorText(ownerCnicError),
                ],
              ),
            ),
          ),

        // ---------------- STEP 2 ----------------
        if (currentStep == 2)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    shopNameController,
                    'Shop name',
                    () => shopNameError = '',
                  ),
                  if (shopNameError.isNotEmpty) _errorText(shopNameError),
                  const SizedBox(height: 16),

                  _buildTextField(
                    shopAddressController,
                    'Full address',
                    () => shopAddressError = '',
                    minLines: 3,
                    maxLines: 4,
                  ),
                  if (shopAddressError.isNotEmpty) _errorText(shopAddressError),
                ],
              ),
            ),
          ),

        const SizedBox(height: 30),

        // ---------------- BUTTONS ----------------
        Row(
          children: [
            // Back button (only on step 2)
            if (currentStep == 2)
              OutlinedButton(
                onPressed: () => setState(() => currentStep = 1),
                child: const Text('Back'),
              ),

            const SizedBox(width: 16),

            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                // Next → Step 2
                onPressed: () {
                  if (currentStep == 1) {
                    // Only validate owner info
                    if (_validateOwnerInfo()) {
                      setState(() => currentStep = 2);
                    }
                  } else {
                    // Last step → Create shop
                    if (!isSubmitting) _submitFullForm();
                  }
                },

                child: Text(
                  currentStep == 1
                      ? 'Next'
                      : (isSubmitting ? 'Creating...' : 'Create Shop'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    VoidCallback clearError, {
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (_) => clearError(),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: ownerPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (v) {
            _computePasswordStrength(v);
            if (ownerPasswordError.isNotEmpty) ownerPasswordError = '';
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: passwordStrength,
          minHeight: 4,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            passwordStrength < 0.4
                ? Colors.red
                : passwordStrength < 0.75
                ? Colors.orange
                : Colors.green,
          ),
        ),
      ],
    );
  }

  bool _validateOwnerInfo() {
    ownerNameError = ownerNameController.text.trim().isEmpty
        ? 'Name required'
        : '';

    ownerEmailError = !_isValidEmail(ownerEmailController.text.trim())
        ? 'Valid email required'
        : '';

    ownerPasswordError = ownerPasswordController.text.length < 8
        ? 'Password too short'
        : '';

    ownerPhoneError = !isPhoneValid ? 'Valid phone required' : '';

    ownerCnicError = ownerCnicController.text.trim().length != 13
        ? 'CNIC must be 13 digits'
        : '';

    setState(() {});
    return ownerNameError.isEmpty &&
        ownerEmailError.isEmpty &&
        ownerPasswordError.isEmpty &&
        ownerPhoneError.isEmpty &&
        ownerCnicError.isEmpty;
  }

  Widget _buildPhoneField() {
    return InternationalPhoneNumberInput(
      onInputChanged: (PhoneNumber number) {
        phoneE164 = number.phoneNumber ?? '';
      },
      onInputValidated: (bool value) {
        isPhoneValid = value;
        ownerPhoneError = value ? '' : 'Invalid phone number';
        setState(() {});
      },

      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
        showFlags: true,
        leadingPadding: 0,
        trailingSpace: false,
      ),

      spaceBetweenSelectorAndTextField: 0,
      selectorTextStyle: const TextStyle(fontSize: 14),

      initialValue: initialPhone,
      textStyle: const TextStyle(fontSize: 15),

      inputDecoration: InputDecoration(
        labelText: 'Phone number',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12),
      child: Text(text, style: TextStyle(color: Colors.red[600], fontSize: 13)),
    );
  }

  void resetFullForm() {
    ownerNameController.clear();
    ownerEmailController.clear();
    ownerPasswordController.clear();
    ownerCnicController.clear();
    shopNameController.clear();
    shopAddressController.clear();
    phoneE164 = '';
    isPhoneValid = false;
    fullShopStatus = 'active';
    passwordStrength = 0.0;
    ownerNameError = ownerEmailError = ownerPasswordError = ownerPhoneError =
        ownerCnicError = shopNameError = shopAddressError = '';
  }

  void _computePasswordStrength(String pw) {
    double score = 0;
    if (pw.length >= 8) score += 0.3;
    if (upperExp.hasMatch(pw)) score += 0.2;
    if (lowerExp.hasMatch(pw)) score += 0.2;
    if (digitExp.hasMatch(pw)) score += 0.15;
    if (specialExp.hasMatch(pw)) score += 0.15;
    passwordStrength = score.clamp(0.0, 1.0);
  }

  bool _runValidations() {
    bool isValid = true;

    ownerNameError = ownerEmailController.text.trim().isEmpty
        ? 'Name required'
        : '';
    ownerEmailError =
        ownerEmailController.text.trim().isEmpty ||
            !_isValidEmail(ownerEmailController.text.trim())
        ? 'Valid email required'
        : '';
    ownerPasswordError = ownerPasswordController.text.length < 8
        ? 'Password too short'
        : '';
    ownerPhoneError = !isPhoneValid || phoneE164.isEmpty
        ? 'Valid phone required'
        : '';
    ownerCnicError = ownerCnicController.text.trim().length != 13
        ? 'CNIC must be 13 digits'
        : '';
    shopNameError = shopNameController.text.trim().isEmpty
        ? 'Shop name required'
        : '';
    shopAddressError = shopAddressController.text.trim().isEmpty
        ? 'Address required'
        : '';

    isValid =
        ownerNameError.isEmpty &&
        ownerEmailError.isEmpty &&
        ownerPasswordError.isEmpty &&
        ownerPhoneError.isEmpty &&
        ownerCnicError.isEmpty &&
        shopNameError.isEmpty &&
        shopAddressError.isEmpty;

    setState(() {});
    return isValid;
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    ).hasMatch(email);
  }

  Future<void> _submitFullForm() async {
    if (!_runValidations()) return;
    setState(() => isSubmitting = true);

    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: ownerEmailController.text.trim(),
        password: ownerPasswordController.text,
      );

      final ownerUid = userCredential.user?.uid;
      if (ownerUid == null) throw Exception('Failed to create user');

      await FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(ownerUid)
          .set({
            'uid': ownerUid,
            'name': ownerNameController.text.trim(),
            'email': ownerEmailController.text.trim(),
            'phone': phoneE164,
            'cnic': ownerCnicController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      final shopRef = await FirebaseFirestore.instance.collection('shops').add({
        'ownerId': ownerUid,
        'ownerEmail': ownerEmailController.text.trim(),
        'name': shopNameController.text.trim(),
        'address': shopAddressController.text.trim(),
        'status': fullShopStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (fullShopStatus == 'active') {
        await FirebaseFirestore.instance
            .collection('active_shops')
            .doc(shopRef.id)
            .set({
              'shopId': shopRef.id,
              'ownerId': ownerUid,
              'name': shopNameController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      resetFullForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop & Owner created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => showAddForm = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // Keep all your existing methods unchanged
  void openFormDialog({Map<String, dynamic>? data, String? id}) {
    if (data != null) {
      editingId = id;
      nameController.text = data["name"] ?? "";
      emailController.text = data["ownerEmail"] ?? "";
      ownerController.text = data["owner"] ?? "";
      shopStatus = data["status"] ?? "active";
    } else {
      editingId = null;
      nameController.clear();
      emailController.clear();
      ownerController.clear();
      shopStatus = "active";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(editingId == null ? "Add Shop" : "Edit Shop"),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Shop Name",
                  filled: true,
                  fillColor: softWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ownerController,
                decoration: InputDecoration(
                  labelText: "Owner Name",
                  filled: true,
                  fillColor: softWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  filled: true,
                  fillColor: softWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: shopStatus,
                items: const [
                  DropdownMenuItem(value: "active", child: Text("Active")),
                  DropdownMenuItem(value: "closed", child: Text("Closed")),
                ],
                onChanged: (value) => setState(() => shopStatus = value!),
                decoration: InputDecoration(
                  labelText: "Status",
                  filled: true,
                  fillColor: softWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed),
            onPressed: () {
              editingId == null ? addShop() : updateShop(editingId!);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future addShop() async {
    final doc = await shopsCollection.add({
      "name": nameController.text.trim(),
      "owner": ownerController.text.trim(),
      "email": emailController.text.trim(),
      "status": shopStatus,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (shopStatus == "active") {
      await FirebaseFirestore.instance
          .collection("active_shops")
          .doc(doc.id)
          .set({
            "name": nameController.text.trim(),
            "email": emailController.text.trim(),
            "createdAt": FieldValue.serverTimestamp(),
          });
    }
  }

  Future updateShop(String id) async {
    await shopsCollection.doc(id).update({
      "name": nameController.text.trim(),
      "owner": ownerController.text.trim(),
      "email": emailController.text.trim(),
      "status": shopStatus,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (shopStatus == "active") {
      await FirebaseFirestore.instance.collection("active_shops").doc(id).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance
          .collection("active_shops")
          .doc(id)
          .delete();
    }
  }

  Future updateStatus(String id, String newStatus) async {
    await shopsCollection.doc(id).update({"status": newStatus});

    if (newStatus == "active") {
      await FirebaseFirestore.instance.collection("active_shops").doc(id).set({
        "status": "active",
      });
    } else {
      await FirebaseFirestore.instance
          .collection("active_shops")
          .doc(id)
          .delete();
    }
  }

  Future deleteShop(String id) async {
    await shopsCollection.doc(id).delete();
    await FirebaseFirestore.instance
        .collection("active_shops")
        .doc(id)
        .delete();
  }
}
