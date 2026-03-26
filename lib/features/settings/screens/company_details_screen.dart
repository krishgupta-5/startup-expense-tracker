import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer';
import 'package:shadcn_ui/shadcn_ui.dart';

class CompanyDetailsScreen extends StatefulWidget {
  const CompanyDetailsScreen({super.key});

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _fundingController = TextEditingController();
  final TextEditingController _runwayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCompanyData();
  }

  final companyTypes = {
    'sole_proprietorship': 'Sole Proprietorship',
    'partnership': 'Partnership',
    'llp': 'LLP',
    'pvt_ltd': 'Pvt Ltd',
  };

  String _selectedType = "sole_proprietorship";

  final List<Map<String, TextEditingController>> _bankAccounts = [];

  void _addBankAccount([String name = "", String number = ""]) {
    setState(() {
      _bankAccounts.add({
        "name": TextEditingController(text: name),
        "number": TextEditingController(text: number),
      });
    });
  }

  void _removeBankAccount(int index) {
    setState(() {
      _bankAccounts.removeAt(index);
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _fundingController.dispose();
    _runwayController.dispose();

    for (var account in _bankAccounts) {
      account["name"]?.dispose();
      account["number"]?.dispose();
    }
    super.dispose();
  }

  Future<void> loadCompanyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First try fetching directly by uid as doc ID (matches how updateCompanyData saves)
      final directDoc = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (directDoc.exists) {
        doc = directDoc;
      } else {
        // Fallback: query by uid field for legacy docs
        final snapshot = await FirebaseFirestore.instance
            .collection("companies")
            .where("uid", isEqualTo: user.uid)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          doc = snapshot.docs.first;
        }
      }

      if (doc != null && doc.exists) {
        final data = doc.data()!;
        if (!mounted) return;
        setState(() {
          _companyNameController.text = data["Company Name"] ?? "";
          _ownerNameController.text = data["Owner Name"] ?? "";
          _emailController.text = data["Email"] ?? "";
          _addressController.text = data["Company Address"] ?? "";
          _descController.text = data["Company Work"] ?? "";
          _fundingController.text = data["Funding"]?.toString() ?? "";
          _runwayController.text = data["Runway"]?.toString() ?? "";
          _selectedType = data["Company Type"] ?? "sole_proprietorship";

          final bankAccountsData =
              data["Bank Accounts"] as List<dynamic>? ?? [];
          _bankAccounts.clear();
          for (var account in bankAccountsData) {
            _addBankAccount(
              account["name"]?.toString() ?? "",
              account["number"]?.toString() ?? "",
            );
          }
        });
      }
    } catch (e) {
      log('Company details fetch error: $e');
    }
  }

  Future<void> updateCompanyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .set({
            "uid": user.uid,
            "Company Name": _companyNameController.text.trim(),
            "Owner Name": _ownerNameController.text.trim(),
            "Email": _emailController.text.trim(),
            "Company Address": _addressController.text.trim(),
            "Company Work": _descController.text.trim(),
            "Funding": _fundingController.text.trim(),
            "Runway": _runwayController.text.trim(),
            "Company Type": _selectedType,
            "Bank Accounts": _bankAccounts.map((account) {
              return {
                "name": account["name"]!.text,
                "number": account["number"]!.text,
              };
            }).toList(),
          }, SetOptions(merge: true));

      await _syncOwnerNameToUsers();
    } catch (e) {
      log('Company data update error: $e');
    }
  }

  Future<void> _syncOwnerNameToUsers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Make sure the Auth Display Name stays perfectly in sync
      await user.updateDisplayName(_ownerNameController.text.trim());

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "name": _ownerNameController.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('Owner name sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildSectionLabel("IDENTITY"),
                      _buildInputGroup("COMPANY NAME", _companyNameController),
                      const SizedBox(height: 24),
                      _buildInputGroup("OWNER NAME", _ownerNameController),
                      const SizedBox(height: 24),
                      _buildInputGroup("OFFICIAL EMAIL", _emailController),
                      const SizedBox(height: 40),
                      _buildSectionLabel("LEGAL & LOCATION"),
                      _buildDropdownGroup(
                        "COMPANY TYPE",
                        companyTypes[_selectedType] ?? "Not Set",
                      ),
                      const SizedBox(height: 24),
                      _buildInputGroup(
                        "DESCRIPTION",
                        _descController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _buildInputGroup(
                        "REGISTERED ADDRESS",
                        _addressController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 40),
                      _buildSectionLabel("FINANCIAL OVERVIEW"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup(
                              "FUNDS LEFT (₹)",
                              _fundingController,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputGroup(
                              "RUNWAY (MO)",
                              _runwayController,
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      _buildBankSection(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            "Company Details",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputGroup(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownGroup(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: ShadSelect<String>(
            // Add this Key to force rebuild when Firestore data loads
            key: ValueKey(_selectedType),
            // Add this to set the default option!
            initialValue: _selectedType,
            placeholder: Text(
              'Select $label',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
            ),
            options: [
              ...companyTypes.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, selectedValue) => Text(
              companyTypes[selectedValue]!,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedType = val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBankSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "LINKED BANK ACCOUNTS",
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            GestureDetector(
              onTap: () => _addBankAccount(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_bankAccounts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No accounts added",
                style: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
              ),
            ),
          ),
        ...List.generate(_bankAccounts.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white38,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _bankAccounts[index]["name"],
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "Bank Name",
                            hintStyle: GoogleFonts.inter(color: Colors.white24),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 16,
                        ),
                        TextField(
                          controller: _bankAccounts[index]["number"],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: "Account Number",
                            hintStyle: GoogleFonts.inter(color: Colors.white24),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _removeBankAccount(index),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFFF453A),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () async {
            await updateCompanyData();
            if (mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            "Save Changes",
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
