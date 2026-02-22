import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // Controllers
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;

  // Loading State
  bool _isLoading = false;
  bool _isLoadingBanks = true;

  // 2. DATA LISTS
  final categories = {
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office',
    'software': 'Software',
    'transport': 'Transport',
    'design': 'Design',
  };

  final types = {
    'one_time': 'One-time',
    'recurring': 'Recurring',
    'subscription': 'Subscription',
  };

  Map<String, String> _bankAccounts = {};

  String _selectedCategory = "marketing";
  String _selectedType = "one_time";
  String? _selectedBankAccount;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _dateController = TextEditingController(
      text: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
    );
    _fetchBankAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
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
          
          // Format option key and value
          final String key = "$name-$number";
          final String displayLabel = "$name (****${number.length > 4 ? number.substring(number.length - 4) : number})";
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

  Future<void> _uploadExpense() async {
    // Validation
    if (_amountController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter an amount.");
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showErrorSnackBar("Please enter a valid amount greater than 0.");
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter a title.");
      return;
    }

    if (_titleController.text.trim().length < 3) {
      _showErrorSnackBar("Title must be at least 3 characters long.");
      return;
    }

    if (_titleController.text.trim().length > 50) {
      _showErrorSnackBar("Title must not exceed 50 characters.");
      return;
    }

    if (_descriptionController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().length > 500) {
      _showErrorSnackBar("Description must not exceed 500 characters.");
      return;
    }

    if (_selectedDate.isAfter(DateTime.now())) {
      _showErrorSnackBar("Date cannot be in the future.");
      return;
    }

    if (_selectedBankAccount == null) {
      _showErrorSnackBar("Please select a bank account.");
      return;
    }

    // Set Loading State
    setState(() => _isLoading = true);

    try {
      final id = const Uuid().v4();

      await FirebaseFirestore.instance.collection('expenses').doc(id).set({
        "uid": FirebaseAuth.instance.currentUser!.uid,
        "Amount": amount,
        "Title": _titleController.text.trim(),
        "Description": _descriptionController.text.trim(),
        "Date": _selectedDate,
        "Category": _selectedCategory,
        "Type": _selectedType,
        "BankAccount": _selectedBankAccount, // <-- Added to record
        "Time": FieldValue.serverTimestamp(),
      });

      // Subtract expense amount from available funds
      await _updateFundsAfterExpense(amount);

      // Navigate back after successful save
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      // Error Handling
      if (mounted) {
        _showErrorSnackBar(e.message ?? 'Failed to upload expense');
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateFundsAfterExpense(double expenseAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current company data
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists && companyDoc.data() != null) {
        final data = companyDoc.data()!;
        final currentTotalExpenses =
            double.tryParse(data["totalExpenses"]?.toString() ?? "0") ?? 0.0;

        // Calculate new total expenses
        final newTotalExpenses = currentTotalExpenses + expenseAmount;

        // Update the totalExpenses field instead of reducing funding
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.uid)
            .update({"totalExpenses": newTotalExpenses.toString()});
      }
    } catch (e) {
      print("DEBUG: Error updating totalExpenses: $e");
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
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // --- HERO AMOUNT INPUT ---
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

                      // Expense Title
                      _buildTextInput(
                        "Expense Title",
                        "e.g. Client Lunch / AWS Bill",
                      ),

                      const SizedBox(height: 24),

                      // --- IMPROVED SELECTS ROW ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelectField(
                              label: "Category",
                              currentValue: _selectedCategory,
                              items: categories,
                              icon: Icons.pie_chart_outline,
                              onChanged: (val) {
                                setState(() => _selectedCategory = val!);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSelectField(
                              label: "Type",
                              currentValue: _selectedType,
                              items: types,
                              icon: Icons.repeat,
                              onChanged: (val) {
                                setState(() => _selectedType = val!);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      
                      // --- BANK ACCOUNT SELECTOR ---
                      if (!_isLoadingBanks && _bankAccounts.isNotEmpty) ...[
                        _buildSelectField(
                          label: "Bank Account",
                          currentValue: _selectedBankAccount ?? "",
                          items: _bankAccounts,
                          icon: Icons.account_balance,
                          onChanged: (val) {
                            setState(() => _selectedBankAccount = val!);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Date
                      _buildDateSelector(),

                      const SizedBox(height: 24),

                      // Description
                      _buildTextArea("Description / Notes"),

                      const SizedBox(height: 32),

                      // Team Member
                      _buildSectionLabel("LINK MEMBER (OPTIONAL)"),
                      const SizedBox(height: 16),
                      _buildTeamSelector(),

                      const SizedBox(height: 32),

                      // Attachment
                      _buildSectionLabel("ATTACHMENT"),
                      const SizedBox(height: 16),
                      _buildAttachmentZone(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- COMPONENT BUILDERS ---

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
            "Add Expense",
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 56,
          fontWeight: FontWeight.w600,
          letterSpacing: -2,
        ),
        cursorColor: const Color(0xFF30D158),
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

  Widget _buildTextInput(String label, String placeholder) {
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
            controller: _titleController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
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

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            readOnly: true,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              icon: const Icon(
                Icons.calendar_today,
                color: Colors.white38,
                size: 20,
              ),
              hintText: "Select date",
              labelText: "Date",
              labelStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
              hintStyle: GoogleFonts.inter(color: Colors.white12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              suffixIcon: const Icon(
                Icons.calendar_month,
                color: Colors.white38,
              ),
            ),
            controller: _dateController,
            onTap: () {
              _showShadCalendar();
            },
          ),
        ),
      ],
    );
  }

  void _showShadCalendar() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF09090B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Date",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ShadCalendar(
                  selected: _selectedDate,
                  fromMonth: DateTime(_selectedDate.year - 1),
                  toMonth: DateTime(_selectedDate.year + 1, 12),
                  onChanged: (DateTime? date) {
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _dateController.text =
                            "${date.day}/${date.month}/${date.year}";
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Done",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            controller: _descriptionController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: "Enter details...",
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSelector() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildAvatar("https://i.pravatar.cc/150?img=68", isSelected: true),
          const SizedBox(width: 12),
          _buildAvatar("https://i.pravatar.cc/150?img=47"),
          const SizedBox(width: 12),
          _buildAvatar("https://i.pravatar.cc/150?img=12"),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, {bool isSelected = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: Colors.white, width: 2)
            : Border.all(color: Colors.transparent),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: isSelected
          ? Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            )
          : null,
    );
  }

  Widget _buildAttachmentZone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Colors.white38,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            "Tap to upload receipt",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
          onPressed: _isLoading ? null : _uploadExpense,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white54,
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
                    color: Colors.black,
                  ),
                )
              : Text(
                  "Save Expense",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}