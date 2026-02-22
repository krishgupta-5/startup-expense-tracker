import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

class ProcessPaymentScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String teamName;
  final double defaultAmount;
  final bool isAdvance;

  const ProcessPaymentScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.teamName,
    required this.defaultAmount,
    required this.isAdvance,
  });

  @override
  State<ProcessPaymentScreen> createState() => _ProcessPaymentScreenState();
}

class _ProcessPaymentScreenState extends State<ProcessPaymentScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;

  bool _isLoading = false;
  bool _isLoadingBanks = true;

  Map<String, String> _bankAccounts = {};
  String? _selectedBankAccount;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.defaultAmount.toStringAsFixed(2),
    );
    _reasonController = TextEditingController();
    _fetchBankAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('Bank Accounts')) {
        final accounts = doc.data()!['Bank Accounts'] as List<dynamic>;

        Map<String, String> loadedBanks = {};
        for (var acc in accounts) {
          final String name = acc['name'] ?? 'Unknown Bank';
          final String number = acc['number'] ?? '';

          final String key = "$name-$number";
          final String displayLabel =
              "$name (****${number.length > 4 ? number.substring(number.length - 4) : number})";
          loadedBanks[key] = displayLabel;
        }

        setState(() {
          _bankAccounts = loadedBanks;
          if (_bankAccounts.isNotEmpty) {
            _selectedBankAccount = _bankAccounts.keys.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load bank accounts: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  Future<void> _processPayment() async {
    final double? amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showErrorSnackBar("Please enter a valid amount.");
      return;
    }

    if (widget.isAdvance && _reasonController.text.trim().isEmpty) {
      _showErrorSnackBar("Please provide a reason for the advance.");
      return;
    }

    if (_selectedBankAccount == null) {
      _showErrorSnackBar("Please select a bank account to pay from.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User is not logged in.");

      final id = const Uuid().v4();
      final String expenseTitle = widget.isAdvance
          ? "Advance Salary - ${widget.memberName}"
          : "Salary - ${widget.memberName}";

      // Removed Team name from description
      final String expenseDesc = widget.isAdvance
          ? "Advance reason: ${_reasonController.text.trim()}"
          : "Regular monthly salary payout for ${widget.memberName}";

      // 1. Log Expense
      await FirebaseFirestore.instance.collection('expenses').doc(id).set({
        "uid": user.uid,
        "Amount": amount,
        "Title": expenseTitle,
        "Description": expenseDesc,
        "TeamName": widget.teamName, // <-- ADDED AS A NEW SEPARATE FIELD HERE
        "Date": DateTime.now(),
        "Category": "salary",
        "Type": "recurring",
        "BankAccount": _selectedBankAccount,
        "Time": FieldValue.serverTimestamp(),
      });

      // 2. Update Total Expenses
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists && companyDoc.data() != null) {
        final data = companyDoc.data()!;
        final currentTotalExpenses =
            double.tryParse(data["totalExpenses"]?.toString() ?? "0") ?? 0.0;
        final newTotalExpenses = currentTotalExpenses + amount;

        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.uid)
            .update({"totalExpenses": newTotalExpenses.toString()});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              widget.isAdvance
                  ? "Advance recorded!"
                  : "Salary payment recorded!",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        Navigator.pop(context); // Go back to member detail
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Payment failed: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

                      // Hero Amount
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "AMOUNT",
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildAmountInput(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Bank Selector
                      if (_isLoadingBanks)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white38,
                          ),
                        )
                      else if (_bankAccounts.isEmpty)
                        Text(
                          "No bank accounts found. Please add a bank account in your company profile first.",
                          style: GoogleFonts.inter(color: Colors.redAccent),
                        )
                      else
                        _buildSelectField(
                          label: "Pay From Bank Account",
                          currentValue: _selectedBankAccount ?? "",
                          items: _bankAccounts,
                          icon: Icons.account_balance,
                          onChanged: (val) {
                            setState(() => _selectedBankAccount = val!);
                          },
                        ),

                      const SizedBox(height: 24),

                      // Reason Field (ONLY FOR ADVANCE)
                      if (widget.isAdvance)
                        _buildTextArea("Reason for Advance"),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

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
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          Text(
            widget.isAdvance ? "Advance Pay" : "Process Salary",
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

  Widget _buildAmountInput() {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _amountController,
        readOnly: !widget.isAdvance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: widget.isAdvance ? Colors.white : Colors.white70,
          fontSize: 56,
          fontWeight: FontWeight.w600,
          letterSpacing: -2,
        ),
        cursorColor: const Color(0xFF0A84FF),
        decoration: InputDecoration(
          hintText: "0.00",
          hintStyle: GoogleFonts.inter(
            color: Colors.white12,
            fontSize: 56,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSelectField({
    required String label,
    required String currentValue,
    required Map<String, String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: ShadSelect<String>(
            placeholder: Text(
              'Select $label',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
            ),
            initialValue: currentValue.isNotEmpty ? currentValue : null,
            options: [
              ...items.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, value) => Text(
              items[value] ?? "Select",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            controller: _reasonController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: "Enter reason for advance payout...",
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSubmitButton() {
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
          onPressed: _isLoading ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isAdvance
                ? const Color(0xFF5E5CE6)
                : const Color(0xFF0A84FF),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                (widget.isAdvance
                        ? const Color(0xFF5E5CE6)
                        : const Color(0xFF0A84FF))
                    .withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.isAdvance ? "PROCESS ADVANCE" : "CONFIRM & PAY SALARY",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ),
    );
  }
}
