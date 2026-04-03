import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/bank_account_service.dart';

class AddExpenseScreen extends StatefulWidget {
  // ✅ Accept prefill data from scan screen
  final Map<String, String>? prefillData;
  // ✅ Accept image path from scan screen
  final String? imagePath;

  const AddExpenseScreen({super.key, this.prefillData, this.imagePath});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final ScrollController _scrollController;

  bool _isLoading = false;
  bool _isLoadingBanks = true;
  String _userCountryCode = '+1'; // Default to USD
  bool _isLoadingCountry = true;

  // ✅ Attachment file ID from Telegram
  String? _attachmentFileId;

  // ✅ File picker state
  String? _fileName;
  String? _filePath;
  bool _isUploading = false;

  final categories = {
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office Rent',
    'software': 'Software',
    'hardware': 'Hardware',
    'transport': 'Transport',
    'design': 'Design',
    'others': 'Others',
    'travel': 'Travel',
    'meals': 'Meals',
    'contractors': 'Contractors',
    'legal': 'Legal',
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
    _loadUserCountryCode();
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _scrollController = ScrollController();

    final p = widget.prefillData;

    // ✅ Pre-fill amount and title from scan
    _amountController = TextEditingController(text: p?['amount'] ?? '');
    _titleController = TextEditingController(text: p?['merchant'] ?? '');
    _descriptionController = TextEditingController(
      text: p?['description'] ?? '',
    );

    // ✅ Parse and apply date from scan (DD/MM/YYYY)
    if (p?['date'] != null && p!['date']!.isNotEmpty) {
      try {
        final parts = p['date']!.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            final parsed = DateTime(year, month, day);
            // Only accept dates not in the future
            if (!parsed.isAfter(DateTime.now())) {
              _selectedDate = parsed;
            }
          }
        }
      } catch (_) {
        // Silently fall back to today
      }
    }

    _dateController = TextEditingController(
      text: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
    );

    // ✅ Apply category if valid
    if (p?['category'] != null && categories.containsKey(p!['category'])) {
      _selectedCategory = p['category']!;
    }

    _fetchBankAccounts();

    // ✅ Auto-upload image and scroll to attachment section if image path provided
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoUploadAndScroll();
      });
    }
  }

  void _loadUserCountryCode() {
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    setState(() => _isLoadingCountry = false);
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- UNIFIED MINIMAL TOAST ---
  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF30D158),
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

  Future<void> _fetchBankAccounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists && doc.data()!.containsKey('Bank Accounts')) {
        final accounts = doc.data()!['Bank Accounts'] as List<dynamic>;
        Map<String, String> loadedBanks = {};

        for (var acc in accounts) {
          final String name = acc['name'] ?? acc['bankName'] ?? 'Unknown Bank';
          final String rawLast4 =
              acc['last4']?.toString() ?? acc['number']?.toString() ?? '';
          final String last4 = rawLast4.isNotEmpty
              ? BankAccountService.extractLast4(rawLast4)
              : '';
          final String key = "$name-$last4";
          final String label = last4.isNotEmpty ? "$name (****$last4)" : name;
          loadedBanks[key] = label;
        }

        setState(() {
          _bankAccounts = loadedBanks;
          // Add "Cash" option at the beginning
          _bankAccounts["Cash-"] = "Cash";
          if (_bankAccounts.isNotEmpty) {
            _selectedBankAccount = _bankAccounts.keys.first;
          }
        });
      } else {
        // No bank accounts found, still provide Cash option
        setState(() {
          _bankAccounts = {"Cash-": "Cash"};
          _selectedBankAccount = "Cash-";
        });
      }
    } catch (e) {
      debugPrint("Failed to load bank accounts: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  Future<void> _uploadExpense() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    if (_amountController.text.trim().isEmpty) {
      _showMinimalToast("Please enter an amount.", isError: true);
      return;
    }
    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMinimalToast(
        "Please enter a valid amount greater than 0.",
        isError: true,
      );
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showMinimalToast("Please enter a title.", isError: true);
      return;
    }
    if (_titleController.text.trim().length < 3) {
      _showMinimalToast(
        "Title must be at least 3 characters long.",
        isError: true,
      );
      return;
    }
    if (_titleController.text.trim().length > 50) {
      _showMinimalToast("Title must not exceed 50 characters.", isError: true);
      return;
    }
    if (_descriptionController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().length > 500) {
      _showMinimalToast(
        "Description must not exceed 500 characters.",
        isError: true,
      );
      return;
    }
    if (_selectedDate.isAfter(DateTime.now())) {
      _showMinimalToast("Date cannot be in the future.", isError: true);
      return;
    }
    if (_selectedBankAccount == null) {
      _showMinimalToast("Please select a bank account or cash.", isError: true);
      return;
    }

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
        "BankAccount": _selectedBankAccount,
        "AttachmentFileId": _attachmentFileId ?? '',
        "Time": FieldValue.serverTimestamp(),
      });

      await _updateFundsAfterExpense(amount);

      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMinimalToast(
          e.message ?? 'Failed to upload expense',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFundsAfterExpense(double expenseAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) return;

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (companyDoc.exists && companyDoc.data() != null) {
        final data = companyDoc.data()!;

        final currentTotalExpenses =
            double.tryParse(data["totalExpenses"]?.toString() ?? "0") ?? 0.0;

        final newTotalExpenses = currentTotalExpenses + expenseAmount;

        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId) // Fixed: update companyId doc, not user.uid doc
            .update({"totalExpenses": newTotalExpenses});
      }
    } catch (e) {
      debugPrint("Error updating totalExpenses: $e");
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
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ✅ Show "Pre-filled from scan" banner if data came from scan
                        if (widget.prefillData != null &&
                            widget.prefillData!.isNotEmpty)
                          _buildPrefillBanner(),

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

                        _buildSectionLabel("EXPENSE DETAILS"),
                        const SizedBox(height: 8),
                        _buildTextInput(
                          "Expense Title",
                          "e.g. Client Lunch / AWS Bill",
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectField(
                                label: "Category",
                                currentValue: _selectedCategory,
                                items: categories,
                                icon: Icons.pie_chart_outline,
                                onChanged: (val) {
                                  FocusScope.of(context).unfocus();
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
                                  FocusScope.of(context).unfocus();
                                  setState(() => _selectedType = val!);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        if (!_isLoadingBanks && _bankAccounts.isNotEmpty) ...[
                          _buildSelectField(
                            label: "Payment Method",
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

                        _buildDateSelector(),
                        const SizedBox(height: 24),
                        _buildTextArea("Description / Notes"),
                        const SizedBox(height: 32),
                        _buildSectionLabel("LINK MEMBER (OPTIONAL)"),
                        const SizedBox(height: 16),
                        _buildTeamSelector(),
                        const SizedBox(height: 32),
                        _buildSectionLabel("ATTACHMENT"),
                        const SizedBox(height: 16),
                        _buildAttachmentZone(),
                        const SizedBox(height: 40),
                      ],
                    ),
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

  // ✅ Banner shown when data is pre-filled from scan
  Widget _buildPrefillBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0A84FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF0A84FF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Fields pre-filled from scanned receipt. Review and edit if needed.",
              style: GoogleFonts.inter(
                color: const Color(0xFF0A84FF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

  Widget _buildAmountInput() {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.next,
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
          prefixText: _isLoadingCountry
              ? '₹'
              : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ",
          prefixStyle: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 32,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(String label, String placeholder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: _titleController,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          hintText: placeholder,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        _buildSectionLabel("DATE"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            readOnly: true,
            controller: _dateController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            onTap: () {
              FocusScope.of(context).unfocus();
              _showShadCalendar();
            },
            decoration: InputDecoration(
              icon: const Icon(
                Icons.calendar_today,
                color: Colors.white38,
                size: 20,
              ),
              hintText: "Select date",
              hintStyle: GoogleFonts.inter(color: Colors.white12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              suffixIcon: const Icon(
                Icons.calendar_month,
                color: Colors.white38,
              ),
            ),
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
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
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.done,
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
    return GestureDetector(
      onTap: _isUploading ? null : _pickFile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isUploading
                ? const Color(0xFF0A84FF).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            if (_isUploading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: const Color(0xFF0A84FF),
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                _fileName != null
                    ? _getFileIcon(_fileName!)
                    : Icons.attach_file,
                color: Colors.white38,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isUploading
                    ? "Uploading to Telegram..."
                    : _fileName ?? "Upload attachment (any file)",
                style: TextStyle(
                  color: _isUploading
                      ? const Color(0xFF0A84FF)
                      : Colors.white70,
                  fontSize: _isUploading ? 12 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_fileName != null && !_isUploading)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _fileName = null;
                    _filePath = null;
                    _attachmentFileId = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // ✅ Mobile file picking using image_picker and file_picker
  Future<void> _pickFile() async {
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF141416),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Attachment",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  "Take Photo",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );
                  if (image != null) {
                    await _uploadFile(image.path, image.name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: Text(
                  "Choose Photo / Video",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? media = await picker.pickMedia();
                  if (media != null) {
                    await _uploadFile(media.path, media.name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.white,
                ),
                title: Text(
                  "Choose PDF / Document",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                subtitle: Text(
                  "PDF, Word, Excel, and more",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: [
                      'pdf',
                      'doc',
                      'docx',
                      'xls',
                      'xlsx',
                      'txt',
                      'csv',
                    ],
                    allowMultiple: false,
                  );
                  if (result != null && result.files.single.path != null) {
                    await _uploadFile(
                      result.files.single.path!,
                      result.files.single.name,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.white),
                title: Text(
                  "Any File",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                subtitle: Text(
                  "Browse all file types",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                    allowMultiple: false,
                  );
                  if (result != null && result.files.single.path != null) {
                    await _uploadFile(
                      result.files.single.path!,
                      result.files.single.name,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("File pick error: $e");
      if (mounted) {
        _showMinimalToast("Could not open file picker.", isError: true);
      }
    }
  }

  // ✅ Get file icon based on file type
  IconData _getFileIcon(String name) {
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description;
    }
    if (name.endsWith('.xls') || name.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif')) {
      return Icons.image;
    }
    if (name.endsWith('.mp4') || name.endsWith('.avi') || name.endsWith('.mov')) {
      return Icons.video_file;
    }
    if (name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.flac')) {
      return Icons.audio_file;
    }
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.tar')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }

  // ✅ Upload file to Telegram
  Future<String?> uploadToTelegram(String filePath) async {
    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];

      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      // Check if it's an image or document
      final isImage =
          filePath.toLowerCase().endsWith('.jpg') ||
          filePath.toLowerCase().endsWith('.jpeg') ||
          filePath.toLowerCase().endsWith('.png') ||
          filePath.toLowerCase().endsWith('.gif');

      final uri = Uri.parse(
        "https://api.telegram.org/bot$botToken/${isImage ? 'sendPhoto' : 'sendDocument'}",
      );

      var request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = '-1003885930746';

      if (isImage) {
        request.files.add(await http.MultipartFile.fromPath('photo', filePath));
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('document', filePath),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);

        if (isImage) {
          // 🔥 IMPORTANT: take highest quality image
          return data['result']['photo'].last['file_id'];
        } else {
          return data['result']['document']['file_id'];
        }
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error uploading to Telegram: $e');
      return null;
    }
  }

  // ✅ Upload file and update state
  Future<void> _uploadFile(String filePath, String fileName) async {
    try {
      setState(() {
        _isUploading = true;
        _fileName = fileName;
        _filePath = filePath;
      });

      final fileId = await uploadToTelegram(filePath);

      if (fileId == null) {
        throw Exception('Failed to upload file to Telegram');
      }

      setState(() {
        _isUploading = false;
        _attachmentFileId = fileId;
      });

      _showMinimalToast("File uploaded successfully!");
    } catch (e) {
      debugPrint('Error uploading file: $e');
      setState(() {
        _isUploading = false;
        _fileName = null;
        _filePath = null;
      });

      if (mounted) {
        _showMinimalToast("Failed to upload file: $e", isError: true);
      }
    }
  }

  // ✅ Auto-upload image from scan and scroll to attachment section
  Future<void> _autoUploadAndScroll() async {
    if (widget.imagePath == null) return;

    // Wait a moment for the widget to be fully built
    await Future.delayed(const Duration(milliseconds: 500));

    // Scroll to attachment section
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
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
