import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../services/bank_account_service.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';

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

class _ProcessPaymentScreenState extends State<ProcessPaymentScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;

  bool _isLoading = false;
  String _userCountryCode = '+1'; // Default

  Map<String, String> _bankAccounts = {};
  String? _selectedBankAccount;
  String? _selectedPaymentMethod = 'cash'; // Default to cash for instant load

  @override
  void initState() {
    super.initState();

    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);

    _amountController = TextEditingController(
      text: widget.defaultAmount.toStringAsFixed(2),
    );
    _reasonController = TextEditingController();

    // Load bank accounts silently in background
    _fetchBankAccounts();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

  // Fix #3: Use BankAccountService so companyId fallback logic is respected
  Future<void> _fetchBankAccounts() async {
    try {
      final accounts = await BankAccountService.getBankAccounts();
      final Map<String, String> loadedBanks = {};

      for (final acc in accounts) {
        final String name = acc['name'] as String? ?? 'Unknown Bank';
        final String last4 = acc['last4'] as String? ?? '';
        final String key = "$name-$last4";
        final String label =
            last4.isNotEmpty && last4 != '****'
                ? "$name (****$last4)"
                : name;
        loadedBanks[key] = label;
      }

      if (mounted) {
        setState(() {
          _bankAccounts = loadedBanks;
          if (_bankAccounts.isNotEmpty) {
            _selectedBankAccount = _bankAccounts.keys.first;
            _selectedPaymentMethod = 'bank';
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load bank accounts: $e");
    }
  }

  Future<void> _processPayment() async {
    FocusScope.of(context).unfocus();

    final double? amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showErrorSnackBar("Please enter a valid amount.");
      return;
    }

    if (widget.isAdvance && _reasonController.text.trim().isEmpty) {
      _showErrorSnackBar("Please provide a reason for the advance.");
      return;
    }

    if (_selectedPaymentMethod == 'bank' && _selectedBankAccount == null) {
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

      final String expenseDesc = widget.isAdvance
          ? "Advance reason: ${_reasonController.text.trim()}"
          : "Regular monthly salary payout for ${widget.memberName}";

      // 1. Log Expense
      await FirebaseFirestore.instance.collection('expenses').doc(id).set({
        "uid": user.uid,
        "Amount": amount,
        "Title": expenseTitle,
        "Description": expenseDesc,
        "TeamName": widget.teamName,
        "Date": DateTime.now(),
        "Category": "salary",
        "Type": "recurring",
        // Store the bank account key (BankName-last4) for later lookup,
        // or 'Cash-' for cash payments
        "BankAccount": _selectedPaymentMethod == 'bank'
            ? (_selectedBankAccount ?? 'Cash-')
            : 'Cash-',
        "bankAccount": _selectedPaymentMethod == 'bank'
            ? (_selectedBankAccount ?? 'Cash-')
            : 'Cash-',
        "PaymentMethod": _selectedPaymentMethod,
        "memberId": widget.memberId,
        "Time": FieldValue.serverTimestamp(),
      });

      // 2. Update Company Total Expenses + Member Total Expenses (Fix #2)
      final batch = FirebaseFirestore.instance.batch();

      // 2a. Look up companyId from user document, fallback to user.uid
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final companyId = userDoc.data()?['companyId'] ?? user.uid;

      // Update company's totalExpenses
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (companyDoc.exists && companyDoc.data() != null) {
        final data = companyDoc.data()!;
        final currentTotalExpenses =
            double.tryParse(data["totalExpenses"]?.toString() ?? "0") ?? 0.0;
        final newTotalExpenses = currentTotalExpenses + amount;

        final companyRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId);
        batch.update(companyRef, {"totalExpenses": newTotalExpenses});
      }

      // 2b. Increment member's totalExpenses so MemberDetailScreen stays accurate
      final memberRef = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId);
      batch.update(memberRef, {
        "totalExpenses": FieldValue.increment(amount),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
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
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFFFF453A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // --- HERO AMOUNT ---
                        Center(
                          child: Column(
                            children: [
                              _buildSectionLabel("AMOUNT"),
                              const SizedBox(height: 8),
                              _buildAmountInput(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- PAYMENT METHOD ---
                        _buildPaymentMethodSelector(),

                        const SizedBox(height: 16),

                        // --- BANK ACCOUNT SELECTOR ---
                        if (_selectedPaymentMethod == 'bank' &&
                            _bankAccounts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildSelectField(
                            label: "Pay From Bank Account",
                            currentValue: _selectedBankAccount ?? "",
                            items: _bankAccounts,
                            icon: Icons.account_balance,
                            onChanged: (val) {
                              FocusScope.of(context).unfocus();
                              setState(() => _selectedBankAccount = val!);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // --- REASON FIELD (ADVANCE ONLY) ---
                        if (widget.isAdvance) ...[
                          const SizedBox(height: 8),
                          _buildTextArea("Reason for Advance"),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
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
                color: Colors.white.withValues(alpha: 0.05), // Glassy white
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
          const SizedBox(width: 44), // Balances the header
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  // Fix #4: Amount is editable for both salary and advance payments.
  // Salaries can vary month-to-month (deductions, partial months).
  Widget _buildAmountInput() {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _amountController,
        readOnly: false, // Always editable — salary can differ month-to-month
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 56,
          fontWeight: FontWeight.w600,
          letterSpacing: -2,
        ),
        cursorColor: widget.isAdvance
            ? const Color(0xFF5E5CE6)
            : Colors.white54,
        decoration: InputDecoration(
          prefixText:
              "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ",
          prefixStyle: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 56,
            fontWeight: FontWeight.w500,
            letterSpacing: -2,
          ),
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

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("PAYMENT METHOD"),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildPaymentOption(
                value: 'bank',
                title: 'Bank Transfer',
                subtitle: 'Pay from registered bank account',
                icon: Icons.account_balance,
                isAvailable: _bankAccounts.isNotEmpty,
              ),
              if (_bankAccounts.isNotEmpty) const SizedBox(height: 4),
              _buildPaymentOption(
                value: 'cash',
                title: 'Cash / Manual',
                subtitle: 'Pay with cash or manual transfer',
                icon: Icons.money,
                isAvailable: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isAvailable,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: isAvailable
          ? () {
              FocusScope.of(context).unfocus();
              setState(() => _selectedPaymentMethod = value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isAvailable
                    ? (isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.1))
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isAvailable
                    ? (isSelected ? Colors.black : Colors.white)
                    : Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isAvailable
                          ? (isSelected ? Colors.white : Colors.white70)
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: isAvailable
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 14),
              ),
          ],
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
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.done,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            maxLines: 3,
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
                ? const Color(0xFF5E5CE6) // Purple for Advance
                : Colors.white, // Solid White for Salary
            foregroundColor: widget.isAdvance ? Colors.white : Colors.black,
            disabledBackgroundColor:
                (widget.isAdvance ? const Color(0xFF5E5CE6) : Colors.white)
                    .withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.isAdvance ? Colors.white : Colors.black,
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