import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/error_popup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';

class EditTeamScreen extends StatefulWidget {
  final String teamId;
  final Map<String, dynamic> teamData;

  const EditTeamScreen({
    super.key,
    required this.teamId,
    required this.teamData,
  });

  @override
  State<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends State<EditTeamScreen>
    with SingleTickerProviderStateMixin {
  // 1. CONTROLLERS & STATE
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  late TextEditingController _descController;

  bool _isLoading = false;
  bool _isDeleting = false;

  late String _selectedColor;
  String _userCountryCode = '+1'; // Default

  // Data Options
  final List<Map<String, dynamic>> _colors = [
    {"name": "Blue", "color": const Color(0xFF0A84FF)},
    {"name": "Orange", "color": const Color(0xFFFF9F0A)},
    {"name": "Purple", "color": const Color(0xFFA259FF)},
    {"name": "Green", "color": const Color(0xFF30D158)},
    {"name": "Red", "color": const Color(0xFFFF453A)},
  ];

  @override
  void initState() {
    super.initState();

    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);

    // Pre-fill controllers with data from Firebase
    _nameController = TextEditingController(
      text: widget.teamData['teamName'] ?? "",
    );

    // Initialize budget controller with proper formatting
    final budget = widget.teamData['monthlyBudget']?.toDouble() ?? 0.0;
    _budgetController = TextEditingController(text: budget.toStringAsFixed(2));

    _descController = TextEditingController(
      text: widget.teamData['description'] ?? "",
    );

    _selectedColor = widget.teamData['color'] ?? "Blue";
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _nameController.dispose();
    _budgetController.dispose();
    _descController.dispose();
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

  // --- FIREBASE LOGIC ---

  Future<void> _updateTeam() async {
    if (_nameController.text.trim().isEmpty) {
      ErrorPopup.showValidation(
        context: context,
        message: "Please enter a team name.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double budget =
          double.tryParse(_budgetController.text.trim()) ?? 0.0;

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({
            "teamName": _nameController.text.trim(),
            "description": _descController.text.trim(),
            "monthlyBudget": budget,
            "color": _selectedColor,
          });

      if (mounted) {
        Navigator.pop(context);
        ErrorPopup.showSuccess(
          context: context,
          message: "Team updated successfully!",
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ErrorPopup.showError(
          context: context,
          title: 'Server Error',
          message: e.message ?? 'Failed to update team',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTeam() async {
    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get companyId — fall back to user.uid if not set (matches BankAccountService)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final companyId = userDoc.data()?['companyId'] ?? user.uid;

      // Get all members in the team
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('teamId', isEqualTo: widget.teamId)
          .get();

      // T-02: Track ACTUAL paid-out amounts (not budgeted monthlyCost)
      double totalActualPayouts = 0;

      final batch = FirebaseFirestore.instance.batch();
      final archiveCollection = FirebaseFirestore.instance.collection(
        'archived_payments',
      );

      for (var memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        final memberName = memberData['fullName'] ?? 'Unknown';
        final memberId = memberDoc.id;

        // T-01: Salary payments are in 'expenses', not 'payments'
        final expensesSnapshot = await FirebaseFirestore.instance
            .collection('expenses')
            .where('uid', isEqualTo: user.uid)
            .where('memberId', isEqualTo: memberId)
            .where('Category', isEqualTo: 'salary')
            .get();

        for (var expenseDoc in expensesSnapshot.docs) {
          final expenseData = Map<String, dynamic>.from(expenseDoc.data());

          // T-02: Accumulate what was ACTUALLY paid out
          final paidAmount =
              (expenseData['Amount'] as num?)?.toDouble() ?? 0.0;
          totalActualPayouts += paidAmount;

          expenseData['originalMemberId'] = memberId;
          expenseData['originalMemberName'] = memberName;
          expenseData['originalTeamId'] = widget.teamId;
          expenseData['archivedAt'] = FieldValue.serverTimestamp();
          expenseData['archiveReason'] = 'team_deleted';

          batch.set(archiveCollection.doc(), expenseData);
          batch.delete(expenseDoc.reference);
        }

        batch.delete(memberDoc.reference);
      }

      // Delete the team document
      batch.delete(
        FirebaseFirestore.instance.collection('teams').doc(widget.teamId),
      );

      // T-02: Only adjust by money that was actually paid out, not budgeted salary
      if (totalActualPayouts > 0) {
        final companyRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId);
        batch.update(companyRef, {
          "totalExpenses": FieldValue.increment(-totalActualPayouts),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ErrorPopup.showSuccess(
          context: context,
          message: "Team and all members removed. Payment history archived.",
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ErrorPopup.showError(
          context: context,
          title: 'Delete Error',
          message: e.message ?? 'Failed to delete team',
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }


  // --- GORGEOUS CUSTOM DELETE DIALOG ---
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8), // Darken backdrop
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416), // Match theme
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF453A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Delete Team?",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Warning Text
                Text(
                  "This action cannot be undone. The team and all associated members will be permanently removed from your organization.",
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close dialog
                          _deleteTeam(); // Execute delete
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF453A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Delete",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              // 1. Header
              _buildHeader(context),

              // 2. Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // --- HERO TEAM NAME INPUT ---
                      _buildSectionLabel("TEAM NAME"),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        onTapOutside: (event) =>
                            FocusScope.of(context).unfocus(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                        ),
                        cursorColor: const Color(0xFF0A84FF),
                        decoration: InputDecoration(
                          hintText: "Team Name",
                          hintStyle: GoogleFonts.inter(
                            color: Colors.white24, // Upgraded hint visibility
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      // ---------------------------
                      const SizedBox(height: 40),

                      // --- BUDGET SETTINGS ---
                      _buildSectionLabel("MONTHLY BUDGET"),
                      const SizedBox(height: 8),
                      _buildBudgetInput(),

                      const SizedBox(height: 32),

                      // --- DESCRIPTION ---
                      _buildTextArea("DESCRIPTION", _descController),

                      const SizedBox(height: 32),

                      // --- VISUAL IDENTITY ---
                      _buildSectionLabel("VISUAL IDENTITY"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _colors
                              .map((c) => _buildColorOption(c))
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // --- DANGER ZONE ---
                      _buildDangerZone(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // 3. Save Button
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
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          Text(
            "Edit Team",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Spacer for balance
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBudgetInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: _budgetController,
        textInputAction: TextInputAction.next,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        cursorColor: Colors.white,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: "0.00",
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  CurrencyFormatter.getCurrencySymbol(_userCountryCode),
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 0,
          ),
        ),
        onChanged: (value) {
          // Optional: Add real-time formatting or validation here
        },
      ),
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
            textInputAction: TextInputAction.done,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            cursorColor: Colors.white,
            maxLines: 3,
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

  Widget _buildColorOption(Map<String, dynamic> colorData) {
    final bool isSelected = _selectedColor == colorData['name'];
    final Color color = colorData['color'];

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Dismiss keyboard when picking color
        setState(() => _selectedColor = colorData['name']);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.3 : 0.1),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("DANGER ZONE"),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF453A).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF453A).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF453A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delete Team",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Permanently remove team and all members",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A).withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _isDeleting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF453A),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus(); // Dismiss keyboard
                        _showDeleteConfirmation();
                      },
                      child: Text(
                        "DELETE",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF453A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white54, // Upgraded contrast
        fontSize: 11, // Upgraded size
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2, // Tuned spacing
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
          onPressed: _isLoading || _isDeleting ? null : _updateTeam,
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
                  "Save Changes",
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