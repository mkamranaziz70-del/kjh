// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class AddShopFullFormScreen extends StatefulWidget {
  const AddShopFullFormScreen({super.key});

  @override
  State<AddShopFullFormScreen> createState() => _AddShopFullFormScreenState();
}

class _AddShopFullFormScreenState extends State<AddShopFullFormScreen> {
  // Theme color
  final Color primaryColor = const Color(0xFFF25C4D);

  // Controllers - Owner
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerEmailController = TextEditingController();
  final TextEditingController ownerPasswordController = TextEditingController();
  final TextEditingController ownerCnicController = TextEditingController();

  // Controllers - Shop
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController shopAddressController = TextEditingController();

  // Phone (intl)
  PhoneNumber initialPhone = PhoneNumber(isoCode: 'PK', dialCode: '+92');
  String phoneE164 = '';
  bool isPhoneValid = false;

  // Country dropdown (shop country & owner country)
  String ownerCountry = 'Pakistan';
  String shopCountry = 'Pakistan';

  // Status
  String shopStatus = 'active';

  // Validation error strings (empty == no error)
  String ownerNameError = '';
  String ownerEmailError = '';
  String ownerPasswordError = '';
  String ownerPhoneError = '';
  String ownerCnicError = '';
  String shopNameError = '';
  String shopCountryError = '';
  String shopAddressError = '';

  bool isSubmitting = false;

  // Password strength (0.0..1.0)
  double passwordStrength = 0.0;
  String passwordStrengthLabel = '';

  final _formKey = GlobalKey<FormState>();

  // Password regex parts
  final RegExp upperExp = RegExp(r'[A-Z]');
  final RegExp lowerExp = RegExp(r'[a-z]');
  final RegExp digitExp = RegExp(r'\d');
  final RegExp specialExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  @override
  void dispose() {
    ownerNameController.dispose();
    ownerEmailController.dispose();
    ownerPasswordController.dispose();
    ownerCnicController.dispose();
    shopNameController.dispose();
    shopAddressController.dispose();
    super.dispose();
  }

  // Validate email simple
  bool _isValidEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    ).hasMatch(email);
  }

  // Strong password (Option A)
  String? validateStrongPassword(String value) {
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!upperExp.hasMatch(value)) {
      return 'Include at least 1 uppercase letter';
    }
    if (!lowerExp.hasMatch(value)) {
      return 'Include at least 1 lowercase letter';
    }
    if (!digitExp.hasMatch(value)) {
      return 'Include at least 1 digit';
    }
    if (!specialExp.hasMatch(value)) {
      return 'Include at least 1 special character';
    }
    return null;
  }

  void computePasswordStrength(String pw) {
    double score = 0;
    if (pw.length >= 8) score += 0.3;
    if (upperExp.hasMatch(pw)) score += 0.2;
    if (lowerExp.hasMatch(pw)) score += 0.2;
    if (digitExp.hasMatch(pw)) score += 0.15;
    if (specialExp.hasMatch(pw)) score += 0.15;
    if (score > 1.0) score = 1.0;
    setState(() {
      passwordStrength = score;
      if (score < 0.4) {
        passwordStrengthLabel = 'Weak';
      } else if (score < 0.75) {
        passwordStrengthLabel = 'Medium';
      } else {
        passwordStrengthLabel = 'Strong';
      }
    });
  }

  // CNIC simple validation: Pakistan CNIC format 13 digits (without dashes)
  bool validateCnic(String cnic) {
    final cleaned = cnic.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length == 13;
  }

  // Field validation that sets error strings
  bool runValidations() {
    bool ok = true;

    setState(() {
      ownerNameError = '';
      ownerEmailError = '';
      ownerPasswordError = '';
      ownerPhoneError = '';
      ownerCnicError = '';
      shopNameError = '';
      shopCountryError = '';
      shopAddressError = '';
    });

    if (ownerNameController.text.trim().isEmpty) {
      ownerNameError = 'Owner name is required';
      ok = false;
    }

    final email = ownerEmailController.text.trim();
    if (email.isEmpty) {
      ownerEmailError = 'Email is required';
      ok = false;
    } else if (!_isValidEmail(email)) {
      ownerEmailError = 'Enter a valid email';
      ok = false;
    }

    final pw = ownerPasswordController.text;
    final pwErr = validateStrongPassword(pw);
    if (pwErr != null) {
      ownerPasswordError = pwErr;
      ok = false;
    }

    if (!isPhoneValid || phoneE164.isEmpty) {
      ownerPhoneError = 'Enter a valid phone number';
      ok = false;
    }

    if (ownerCnicController.text.trim().isEmpty) {
      ownerCnicError = 'CNIC is required';
      ok = false;
    } else if (!validateCnic(ownerCnicController.text.trim())) {
      ownerCnicError = 'CNIC must be 13 digits';
      ok = false;
    }

    if (shopNameController.text.trim().isEmpty) {
      shopNameError = 'Shop name is required';
      ok = false;
    }

    if (shopCountry.trim().isEmpty) {
      shopCountryError = 'Select shop country';
      ok = false;
    }

    if (shopAddressController.text.trim().isEmpty) {
      shopAddressError = 'Shop address is required';
      ok = false;
    }

    setState(() {}); // refresh error texts
    return ok;
  }

  Future<void> submitForm() async {
    // Run front-end validations first
    if (!runValidations()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // 1) Create Firebase Auth user (owner credentials)
      final auth = FirebaseAuth.instance;

      // If email already exists -> FirebaseAuthException
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: ownerEmailController.text.trim(),
        password: ownerPasswordController.text,
      );

      final ownerUid = userCredential.user?.uid;
      if (ownerUid == null) throw Exception('Failed to create user');

      // 2) Save owner profile to Firestore
      final ownerDoc = FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(ownerUid);
      await ownerDoc.set({
        'uid': ownerUid,
        'name': ownerNameController.text.trim(),
        'email': ownerEmailController.text.trim(),
        'phone': phoneE164,
        'country': ownerCountry,
        'cnic': ownerCnicController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) Save shop data to 'shops' collection
      final shopRef = await FirebaseFirestore.instance.collection('shops').add({
        'ownerId': ownerUid,
        'ownerEmail': ownerEmailController.text.trim(),

        'name': shopNameController.text.trim(),
        'address': shopAddressController.text.trim(),
        'country': shopCountry,
        'status': shopStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) If active, add to active_shops with same doc id
      if (shopStatus == 'active') {
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

      // Success - clear form and show small success inline (we'll show a dialog)
      setState(() {
        isSubmitting = false;
      });

      // Show a small success dialog (not snackbar)
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: primaryColor),
              const SizedBox(width: 8),
              const Text('Shop Created'),
            ],
          ),
          content: const Text('Shop and owner created successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Optionally go back or clear
      Navigator.of(
        context,
      ).pop(); // close the form screen (you can remove if you prefer)
    } on FirebaseAuthException catch (e) {
      setState(() {
        isSubmitting = false;
      });
      // Map firebase auth errors to field errors
      if (e.code == 'email-already-in-use') {
        setState(() {
          ownerEmailError = 'Email already in use';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          ownerEmailError = 'Invalid email';
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          ownerPasswordError = 'Weak password';
        });
      } else {
        // Generic
        await showErrorDialog('Authentication error: ${e.message ?? e.code}');
      }
    } catch (ex) {
      setState(() {
        isSubmitting = false;
      });
      await showErrorDialog('Error: ${ex.toString()}');
    }
  }

  Future<void> showErrorDialog(String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: primaryColor),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Widget builders below
  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // big two-column style on wide screens; single column on small screens
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Shop'),
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storefront, color: primaryColor),
                      const SizedBox(width: 12),
                      const Text(
                        'Create new shop & owner account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Layout: two sections side-by-side on wide screens
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Owner Info
                          Expanded(child: ownerInfoCard()),
                          const SizedBox(width: 20),
                          // Shop Info
                          Expanded(child: shopInfoCard()),
                        ],
                      )
                    : Column(
                        children: [
                          ownerInfoCard(),
                          const SizedBox(height: 16),
                          shopInfoCard(),
                        ],
                      ),

                const SizedBox(height: 20),

                // Status and Submit button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Shop Status'),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: shopStatus == 'active',
                            onSelected: (v) {
                              setState(() {
                                shopStatus = 'active';
                              });
                            },
                            selectedColor: primaryColor,
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Closed'),
                            selected: shopStatus == 'closed',
                            onSelected: (v) {
                              setState(() {
                                shopStatus = 'closed';
                              });
                            },
                            selectedColor: primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Submit
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                      ),
                      onPressed: isSubmitting ? null : submitForm,
                      child: isSubmitting
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Saving...'),
                              ],
                            )
                          : const Text('Create Shop & Owner'),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget ownerInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Owner — Personal Information'),
            // Name
            TextFormField(
              controller: ownerNameController,
              decoration: _inputDecoration('Owner full name'),
              onChanged: (_) => setState(() {
                if (ownerNameError.isNotEmpty) ownerNameError = '';
              }),
            ),
            if (ownerNameError.isNotEmpty) errorText(ownerNameError),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: ownerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('Email'),
              onChanged: (_) => setState(() {
                if (ownerEmailError.isNotEmpty) ownerEmailError = '';
              }),
            ),
            if (ownerEmailError.isNotEmpty) errorText(ownerEmailError),
            const SizedBox(height: 12),

            // Password + strength
            TextFormField(
              controller: ownerPasswordController,
              obscureText: true,
              decoration: _inputDecoration('Password'),
              onChanged: (v) {
                computePasswordStrength(v);
                setState(() {
                  if (ownerPasswordError.isNotEmpty) ownerPasswordError = '';
                });
              },
            ),
            const SizedBox(height: 6),
            // strength bar
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: passwordStrength,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  passwordStrengthLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (ownerPasswordError.isNotEmpty) errorText(ownerPasswordError),
            const SizedBox(height: 12),

            // Phone (intl_phone_number_input)
            InternationalPhoneNumberInput(
              onInputChanged: (PhoneNumber number) {
                phoneE164 = number.phoneNumber ?? '';
              },
              onInputValidated: (bool value) {
                isPhoneValid = value;
                if (!value) {
                  ownerPhoneError = 'Invalid phone';
                } else {
                  ownerPhoneError = '';
                }
                setState(() {});
              },
              selectorConfig: const SelectorConfig(
                selectorType: PhoneInputSelectorType.DROPDOWN,
                showFlags: true,
              ),
              initialValue: initialPhone,
              countries: const [], // show all
              textFieldController: TextEditingController(),
              inputDecoration: _inputDecoration('Phone (with country code)'),
              autoValidateMode: AutovalidateMode.disabled,
            ),
            if (ownerPhoneError.isNotEmpty) errorText(ownerPhoneError),
            const SizedBox(height: 12),

            // CNIC
            TextFormField(
              controller: ownerCnicController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('CNIC (13 digits)'),
              onChanged: (_) => setState(() {
                if (ownerCnicError.isNotEmpty) ownerCnicError = '';
              }),
            ),
            if (ownerCnicError.isNotEmpty) errorText(ownerCnicError),
            const SizedBox(height: 12),

            // Country for owner
            // Simple dropdown using localized country names (you can replace list as needed)
            DropdownButtonFormField<String>(
              value: ownerCountry,
              items: countryList
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    ownerCountry = v;
                  });
                }
              },
              decoration: _inputDecoration('Owner country'),
            ),
          ],
        ),
      ),
    );
  }

  Widget shopInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Shop — Details'),
            TextFormField(
              controller: shopNameController,
              decoration: _inputDecoration('Shop name'),
              onChanged: (_) => setState(() {
                if (shopNameError.isNotEmpty) shopNameError = '';
              }),
            ),
            if (shopNameError.isNotEmpty) errorText(shopNameError),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: shopCountry,
              items: countryList
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    shopCountry = v;
                    if (shopCountryError.isNotEmpty) shopCountryError = '';
                  });
                }
              },
              decoration: _inputDecoration('Shop country'),
            ),
            if (shopCountryError.isNotEmpty) errorText(shopCountryError),
            const SizedBox(height: 12),

            TextFormField(
              controller: shopAddressController,
              minLines: 3,
              maxLines: 5,
              decoration: _inputDecoration('Full address'),
              onChanged: (_) => setState(() {
                if (shopAddressError.isNotEmpty) shopAddressError = '';
              }),
            ),
            if (shopAddressError.isNotEmpty) errorText(shopAddressError),
          ],
        ),
      ),
    );
  }

  Widget errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  // A short list of countries; replace/expand as you wish or use a package
  List<String> get countryList => const [
    'Pakistan',
    'United States',
    'United Kingdom',
    'India',
    'Canada',
    'Australia',
    'United Arab Emirates',
    'Saudi Arabia',
    'Malaysia',
    'Singapore',
    'Germany',
    'France',
    'Other',
  ];
}
