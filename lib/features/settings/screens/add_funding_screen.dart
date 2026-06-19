import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../services/currency_formatter.dart';
import '../../../services/user_country_service.dart';

class AddFundingScreen extends StatefulWidget {
  const AddFundingScreen({super.key});

  @override
  State<AddFundingScreen> createState() => _AddFundingScreenState();
}

class _AddFundingScreenState extends State<AddFundingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _targetRunwayController = TextEditingController();

  bool _isLoading = false;
  bool _updateTargetRunway = false;
  String _selectedSource = 'self_funded';
  String _userCountryCode = '+1';

  // Current funding & target runway from Firestore
  double _currentFunding = 0.0;
  double _inputAmount = 0.0;
  String _currentTargetRunway = '';

  // Re-introduced elegant, premium colors and icons for the selectable chips
  final Map<String, Map<String, dynamic>> _fundingSources = {
    'self_funded': {
      'label': 'Self Funded',
      'icon': Icons.person_outline,
      'color': const Color(0xFF30D158), // Green
    },
    'bank_loan': {
      'label': 'Bank Loan',
      'icon': Icons.account_balance_outlined,
      'color': const Color(0xFF0A84FF), // iOS Blue
    },
    'angel_investor': {
      'label': 'Angel Investor',
      'icon': Icons.favorite_outline,
      'color': const Color(0xFFFF375F), // Rose Pink
    },
    'vc_funding': {
      'label': 'VC Funding',
      'icon': Icons.rocket_launch_outlined,
      'color': const Color(0xFFFF9F0A), // Sunset Orange
    },
    'grant': {
      'label': 'Grant',
      'icon': Icons.workspace_premium_outlined,
      'color': const Color(0xFF32ADE6), // Cyan
    },
    'revenue': {
      'label': 'Revenue',
      'icon': Icons.trending_up,
      'color': const Color(0xFF00BFA5), // Teal
    },
    'other': {
      'label': 'Other',
      'icon': Icons.more_horiz,
      'color': const Color(0xFF8E8E93), // Slate Gray
    },
  };

  @override
  void initState() {
    super.initState();
    _userCountryCode = UserCountryService.getUserCountryCodeSync();
    _loadCurrentData();

    // Listen to amount changes for real-time projection
    _amountController.addListener(() {
      setState(() {
        _inputAmount = double.tryParse(
              _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0.0;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _targetRunwayController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _currentFunding = _toDouble(
            data['Funding'] ?? data['funding'] ?? 0,
          );
          _currentTargetRunway = data['Target Runway']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading current data: $e');
    }
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), '')) ?? fallback;
    }
    return fallback;
  }

  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFFF453A) : const Color(0xFF30D158),
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

  Future<void> _saveFunding() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final amount = _inputAmount;
      final sourceData = _fundingSources[_selectedSource]!;
      final sourceLabel = sourceData['label'] as String;
      final newTotalFunding = _currentFunding + amount;
      final now = DateTime.now();

      // 1. Save the funding transaction to funding_transactions collection
      await FirebaseFirestore.instance.collection('funding_transactions').add({
        'uid': user.uid,
        'amount': amount,
        'source': sourceLabel,
        'sourceKey': _selectedSource,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'previousFunding': _currentFunding,
        'newTotalFunding': newTotalFunding,
      });

      // 2. Create an expense transaction so it shows in expenses history
      final expenseId = const Uuid().v4();
      await FirebaseFirestore.instance.collection('expenses').doc(expenseId).set({
        'uid': user.uid,
        'Amount': amount,
        'Title': 'Funding: $sourceLabel',
        'Description': _notesController.text.trim(),
        'Date': Timestamp.fromDate(now),
        'Category': 'funding',
        'Type': 'one_time',
        'BankAccount': null,
        'AttachmentFileId': '',
        'ExpenseType': 'funding',
        'isFunding': true,
        'fundingSource': sourceLabel,
        'fundingSourceKey': _selectedSource,
        'Time': FieldValue.serverTimestamp(),
      });

      // 3. Update the total Funding in companies collection
      final Map<String, dynamic> updateData = {
        'Funding': newTotalFunding,
      };

      if (_updateTargetRunway && _targetRunwayController.text.trim().isNotEmpty) {
        updateData['Target Runway'] = _targetRunwayController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (mounted) {
        _showMinimalToast("Funding added successfully!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast(
          "Error adding funding: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyFormatter.getCurrencySymbol(_userCountryCode);

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
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),

                          // Current & Projected Funding
                          Row(
                            children: [
                              Expanded(
                                child: _buildReadOnlyMetric(
                                  "CURRENT FUNDING",
                                  CurrencyFormatter.formatByCountry(
                                    _currentFunding,
                                    _userCountryCode,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildReadOnlyMetric(
                                  "NEW TOTAL",
                                  CurrencyFormatter.formatByCountry(
                                    _currentFunding + _inputAmount,
                                    _userCountryCode,
                                  ),
                                  highlight: _inputAmount > 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Amount input
                          _buildSectionLabel("ADD FUNDING AMOUNT"),
                          _buildAmountInput(currencySymbol),
                          const SizedBox(height: 40),

                          // Source selector
                          _buildSectionLabel("FUNDING SOURCE"),
                          _buildSourceSelector(),
                          const SizedBox(height: 40),

                          // Notes
                          _buildSectionLabel("NOTES (OPTIONAL)"),
                          _buildInputGroup(
                            "e.g., Seed round from XYZ Ventures",
                            _notesController,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 40),

                          // Target Runway toggle
                          _buildSectionLabel("PLANNING"),
                          _buildTargetRunwaySection(),

                          const SizedBox(height: 100),
                        ],
                      ),
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
            "Add Funding",
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
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildReadOnlyMetric(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: highlight ? const Color(0xFF30D158) : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight 
                ? const Color(0xFF30D158).withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.04)
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: highlight ? const Color(0xFF30D158) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput(String currencySymbol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currencySymbol,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onTapOutside: (event) => FocusScope.of(context).unfocus(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "0",
                hintStyle: GoogleFonts.inter(
                  color: Colors.white12,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                errorStyle: GoogleFonts.inter(
                  color: const Color(0xFFFF453A),
                  fontSize: 11,
                  height: 0.8,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Amount required';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _fundingSources.entries.map((entry) {
        final key = entry.key;
        final data = entry.value;
        final isSelected = _selectedSource == key;
        final color = data['color'] as Color;

        return GestureDetector(
          onTap: () => setState(() => _selectedSource = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Elegant Tinted Glass Effect
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data['icon'] as IconData,
                  color: isSelected ? color : Colors.white24,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  data['label'] as String,
                  style: GoogleFonts.inter(
                    color: isSelected ? color : Colors.white54,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputGroup(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Container(
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
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTargetRunwaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _updateTargetRunway = !_updateTargetRunway),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Update Target Runway",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Current Target: ${_currentTargetRunway.isNotEmpty ? '$_currentTargetRunway months' : 'Not set'}",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: _updateTargetRunway
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: _updateTargetRunway
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _updateTargetRunway ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Target Runway Input (animated)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetRunwayController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: Colors.white,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: "Enter months (e.g., 18)",
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Text(
                    "months",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: _updateTargetRunway
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
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
          onPressed: _isLoading ? null : _saveFunding,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  "Add Funding",
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