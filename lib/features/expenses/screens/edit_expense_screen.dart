import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/data_helpers.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/currency_formatter.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const EditExpenseScreen({
    super.key,
    required this.expenseId,
    required this.expenseData,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  // 1. CONTROLLERS & STATE
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  String _userCountryCode = '+1'; // Default to USD
  bool _isLoadingCountry = true;

  // Data Lists
  final categories = {
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office',
    'software': 'Software',
    'transport': 'Transport',
    'design': 'Design',
    'others': 'Others',
  };
  final types = {
    'one_time': 'One-time',
    'recurring': 'Recurring',
    'subscription': 'Subscription',
  };

  late String _selectedCategory;
  late String _selectedType;
  late DateTime _selectedDate;

  void _loadUserCountryCode() {
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    setState(() => _isLoadingCountry = false);
  }

  @override
  void initState() {
    super.initState();
    _loadUserCountryCode();

    // 2. PRE-FILL DATA FROM FIREBASE
    _amountController = TextEditingController(
      text: widget.expenseData['Amount']?.toString() ?? "",
    );
    _titleController = TextEditingController(
      text: widget.expenseData['Title'] ?? "",
    );
    _notesController = TextEditingController(
      text: widget.expenseData['Description'] ?? "",
    );

    // Safely assign Category (fallback to marketing if not found)
    String fetchedCategory =
        widget.expenseData['Category']?.toString().toLowerCase() ?? 'marketing';
    _selectedCategory = categories.containsKey(fetchedCategory)
        ? fetchedCategory
        : 'marketing';

    // Safely assign Type (fallback to one_time if not found)
    String fetchedType =
        widget.expenseData['Type']?.toString().toLowerCase() ?? 'one_time';
    _selectedType = types.containsKey(fetchedType) ? fetchedType : 'one_time';

    // Parse Date
    if (widget.expenseData['Date'] is Timestamp) {
      _selectedDate = (widget.expenseData['Date'] as Timestamp).toDate();
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
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

  // 3. FIREBASE UPDATE LOGIC
  Future<void> _updateExpense() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

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

    if (_notesController.text.trim().isNotEmpty &&
        _notesController.text.trim().length > 500) {
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

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) throw Exception('Company not found');

      final double newAmount = double.tryParse(_amountController.text.trim())!;
      final double oldAmount = DataHelpers.safeParseDouble(
        widget.expenseData['Amount'],
      );
      final double diff = newAmount - oldAmount;

      final batch = FirebaseFirestore.instance.batch();

      // Update expense document
      final expenseRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId);
      batch.update(expenseRef, {
        "Amount": newAmount,
        "Title": _titleController.text.trim(),
        "Description": _notesController.text.trim(),
        "Date": _selectedDate,
        "Category": _selectedCategory,
        "Type": _selectedType,
        "Time": FieldValue.serverTimestamp(),
      });

      // Update totalExpenses if amount changed
      if (diff != 0) {
        final companyRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId);
        batch.update(companyRef, {"totalExpenses": FieldValue.increment(diff)});
      }

      // Commit batch atomically
      await batch.commit();

      if (mounted) {
        _showMinimalToast("Expense updated successfully");
        // Small delay to ensure Firestore update propagates before popping
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMinimalToast(
          e.message ?? 'Failed to update expense',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
              // 1. Premium Header
              _buildHeader(context),

              // 2. Scrollable Form
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
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
                              _buildSectionLabel("AMOUNT"),
                              const SizedBox(height: 8),
                              _buildAmountInput(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- EXPENSE TITLE ---
                        _buildSectionLabel("EXPENSE DETAILS"),
                        const SizedBox(height: 8),
                        _buildTextInput(
                          "Expense Title",
                          "e.g. Client Lunch",
                          _titleController,
                        ),

                        const SizedBox(height: 24),

                        // --- CATEGORY & TYPE SELECTORS ---
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

                        // --- DATE SELECTOR ---
                        _buildDateSelector(),

                        const SizedBox(height: 24),

                        // --- DESCRIPTION ---
                        _buildTextArea("Description / Notes", _notesController),

                        const SizedBox(height: 32),

                        // --- TEAM MEMBER ---
                        _buildSectionLabel("LINKED MEMBER (OPTIONAL)"),
                        const SizedBox(height: 16),
                        _buildTeamSelector(),

                        const SizedBox(height: 32),

                        // --- EXISTING ATTACHMENT ---
                        _buildSectionLabel("ATTACHMENT"),
                        const SizedBox(height: 16),
                        _buildExistingAttachment(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Update Button
              _buildUpdateButton(),
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
            "Edit Expense",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Clean Layout spacer
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
    return Center(
      // The IntrinsicWidth forces the TextField to hug the text exactly, keeping the prefix and text perfectly centered together.
      child: IntrinsicWidth(
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
            height: 1.0,
            letterSpacing: -2,
          ),
          cursorColor: const Color(0xFF30D158),
          decoration: InputDecoration(
            hintText: "0.00",
            hintStyle: GoogleFonts.inter(
              color: Colors.white12,
              fontSize: 56,
              fontWeight: FontWeight.w600,
              height: 1.0,
              letterSpacing: -2,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            prefixText: _isLoadingCountry
                ? '₹ '
                : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ",
            prefixStyle: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 56, // Match text size so they sit perfectly together
              fontWeight: FontWeight.w500,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(
    String label,
    String placeholder,
    TextEditingController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: controller,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.done,
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
            controller: TextEditingController(
              text:
                  "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
            ),
            onTap: () {
              FocusScope.of(context).unfocus();
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
                      fromMonth: DateTime(_selectedDate.year - 1, 1),
                      toMonth: DateTime(_selectedDate.year + 1, 12),
                      onChanged: (DateTime? date) {
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
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

  Widget _buildTextArea(String label, TextEditingController controller) {
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
            controller: controller,
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

  Widget _buildExistingAttachment() {
    final attachmentFileId = widget.expenseData['AttachmentFileId'] as String?;

    if (attachmentFileId == null || attachmentFileId.isEmpty) {
      // No attachment
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No receipt attached",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "0 KB",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () {
                // Future: Open picker logic here
              },
            ),
          ],
        ),
      );
    }

    // Has attachment - show placeholder for now
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF30D158).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt,
                  color: Color(0xFF30D158),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Receipt attached",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF30D158),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Stored in Telegram",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                onPressed: () {
                  // TODO: Remove attachment functionality
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Placeholder for image preview
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                "Receipt preview",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
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
          onPressed: _isLoading ? null : _updateExpense,
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
                  "Update Expense",
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
