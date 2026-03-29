import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../services/currency_formatter.dart';
import '../../../services/user_country_service.dart';
import '../../../services/bank_account_service.dart';
import '../../home/screens/add_bank_account_screen.dart';

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

  String _userCountryCode = '+1'; // Default to USD
  bool _isLoading = false;
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _allExpenses = [];

  @override
  void initState() {
    super.initState();
    _userCountryCode = UserCountryService.getUserCountryCodeSync();
    _loadAllData();
  }

  final companyTypes = {
    'sole_proprietorship': 'Sole Proprietorship',
    'partnership': 'Partnership',
    'llp': 'LLP',
    'pvt_ltd': 'Pvt Ltd',
  };

  String _selectedType = "sole_proprietorship";

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        loadCompanyData(),
        _fetchExpenses(),
        _fetchBankAccounts(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchExpenses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .orderBy('Date', descending: true)
          .get();

      _allExpenses = expensesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': (data['Amount'] as num).toDouble(),
          'bankAccount':
              data['BankAccount'] ??
              data['Bank Account'] ??
              data['bankAccount'] ??
              'N/A',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ DEBUG: Error fetching expenses: $e');
      _allExpenses = [];
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      debugPrint('🔍 DEBUG: Fetching bank accounts using BankAccountService');

      // Use BankAccountService to get bank accounts with spending data
      final accountsWithSpending =
          await BankAccountService.getBankAccountsWithSpending(_allExpenses);

      if (mounted) {
        setState(() {
          _bankAccounts = accountsWithSpending;
        });
      }

      debugPrint(
        '🔍 DEBUG: Fetched ${_bankAccounts.length} bank accounts with spending data',
      );

      // Debug: Print each account to see the structure
      for (var account in _bankAccounts) {
        debugPrint('🔍 DEBUG: Account structure: $account');
        debugPrint('🔍 DEBUG: Account name: "${account['name']}"');
        debugPrint('🔍 DEBUG: Account bankName: "${account['bankName']}"');
        debugPrint('🔍 DEBUG: Available fields: ${account.keys.toList()}');
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error fetching bank accounts: $e');
      if (mounted) {
        setState(() {
          _bankAccounts = [];
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF30D158),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'Delete Bank Account',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${account['name']?.toString() ?? account['bankName']?.toString() ?? account['bank_name']?.toString() ?? 'Unknown Bank'}"? This action cannot be undone.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteBankAccount(account);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF453A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBankAccount(Map<String, dynamic> account) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final accountId = account['id'] as String?;
      if (accountId == null) {
        _showErrorMessage('Cannot delete account: Missing account ID');
        return;
      }

      debugPrint(
        '🔍 DEBUG: Attempting to delete bank account with ID: $accountId',
      );

      // Try to delete from subcollection first (new model)
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.uid)
            .collection('bankAccounts')
            .doc(accountId)
            .delete();

        debugPrint('🔍 DEBUG: Successfully deleted from subcollection');
        _showSuccessMessage('Bank account deleted successfully');
        await _loadAllData();
        return;
      } catch (e) {
        debugPrint('🔍 DEBUG: Failed to delete from subcollection: $e');

        // Fallback: try to remove from company array (old model)
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(user.uid)
              .get();

          if (companyDoc.exists && companyDoc.data() != null) {
            final data = companyDoc.data()!;
            final bankAccounts = data["Bank Accounts"] as List<dynamic>? ?? [];

            // Find and remove the account by matching name and last4
            final updatedAccounts = bankAccounts.where((accountData) {
              if (accountData is Map<String, dynamic>) {
                final bankName =
                    accountData['name']?.toString() ??
                    accountData['bankName']?.toString() ??
                    accountData['bank_name']?.toString() ??
                    '';
                final last4 =
                    accountData['last4']?.toString() ??
                    accountData['number']?.toString() ??
                    '';

                final currentBankName =
                    account['name']?.toString() ??
                    account['bankName']?.toString() ??
                    account['bank_name']?.toString() ??
                    '';
                final currentLast4 =
                    account['last4']?.toString() ??
                    account['number']?.toString() ??
                    '';

                return !((bankName == currentBankName) &&
                    (last4 == currentLast4));
              }
              return true;
            }).toList();

            await FirebaseFirestore.instance
                .collection('companies')
                .doc(user.uid)
                .update({'Bank Accounts': updatedAccounts});

            debugPrint('🔍 DEBUG: Successfully deleted from company array');
            _showSuccessMessage('Bank account deleted successfully');
            await _loadAllData();
          }
        } catch (fallbackError) {
          debugPrint(
            '❌ DEBUG: Failed to delete from company array: $fallbackError',
          );
          _showErrorMessage('Failed to delete bank account');
        }
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error deleting bank account: $e');
      _showErrorMessage('Failed to delete bank account');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
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
          // Use Firebase Auth email since company setup doesn't save email to companies
          _emailController.text = user.email ?? "";
          _addressController.text = data["Company Address"] ?? "";
          _descController.text = data["Company Work"] ?? "";
          _fundingController.text = data["Funding"]?.toString() ?? "";
          _runwayController.text = data["Runway"]?.toString() ?? "";
          _selectedType = data["Company Type"] ?? "sole_proprietorship";
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
        "email": _emailController.text.trim(), // Also sync email
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
                              "FUNDS LEFT (${CurrencyFormatter.getCurrencySymbol(_userCountryCode)})",
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
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddBankAccountScreen(),
                  ),
                );
                if (result != null) {
                  // Bank account was added successfully, reload data
                  await _loadAllData();
                  _showSuccessMessage('Bank account added successfully');
                }
              },
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
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                color: Colors.white38,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_bankAccounts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No accounts added",
                style: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
              ),
            ),
          )
        else
          ...List.generate(_bankAccounts.length, (index) {
            final account = _bankAccounts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF30D158).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Color(0xFF30D158),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle multiple possible field names for bank name
                          Text(
                            (() {
                              final bankName =
                                  account['name']?.toString() ??
                                  account['bankName']?.toString() ??
                                  account['bank_name']?.toString() ??
                                  'Unknown Bank';
                              return bankName;
                            })(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (() {
                              final maskedNumber =
                                  account['maskedNumber']?.toString() ??
                                  (account['last4']?.toString().isNotEmpty ==
                                          true
                                      ? '****${account['last4']}'
                                      : '****');
                              return maskedNumber;
                            })(),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (account['totalSpent'] != null &&
                              (account['totalSpent'] as num) > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Spent: ${CurrencyFormatter.formatByCountry((account['totalSpent'] as num).toDouble(), _userCountryCode)}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFF453A),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (account['id'] != null)
                      GestureDetector(
                        onTap: () => _showDeleteAccountDialog(account),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF453A,
                            ).withValues(alpha: 0.1),
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
